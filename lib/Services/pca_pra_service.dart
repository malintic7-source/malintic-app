import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:gestion_formations/Services/local_storage.dart';

/// Statut de santé d'un nœud de l'infrastructure
class NodeHealth {
  final String name;
  final String type; // 'docker', 'supabase', 'vercel', 'ngrok'
  final bool isOnline;
  final int? latencyMs;
  final String details;
  final DateTime lastChecked;

  const NodeHealth({
    required this.name,
    required this.type,
    required this.isOnline,
    this.latencyMs,
    required this.details,
    required this.lastChecked,
  });
}

/// Instantané PRA (Point de reprise d'activité)
class PraSnapshotInfo {
  final String filename;
  final int sizeBytes;
  final DateTime createdAt;
  final String label;
  final String reason;
  final Map<String, int> counts;

  const PraSnapshotInfo({
    required this.filename,
    required this.sizeBytes,
    required this.createdAt,
    required this.label,
    required this.reason,
    required this.counts,
  });

  factory PraSnapshotInfo.fromMap(Map<String, dynamic> map) {
    final countsMap = <String, int>{};
    if (map['counts'] is Map) {
      (map['counts'] as Map).forEach((k, v) {
        countsMap[k.toString()] = int.tryParse(v.toString()) ?? 0;
      });
    }
    return PraSnapshotInfo(
      filename: map['filename']?.toString() ?? '',
      sizeBytes: int.tryParse(map['sizeBytes']?.toString() ?? '') ?? 0,
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
      label: map['label']?.toString() ?? 'Auto',
      reason: map['reason']?.toString() ?? '',
      counts: countsMap,
    );
  }
}

/// État global PCA / PRA
class PcaPraReport {
  final NodeHealth dockerNode;
  final NodeHealth postgresNode;
  final NodeHealth vercelNode;
  final NodeHealth ngrokNode;
  final int totalLocalDocuments;
  final int pendingSyncQueue;
  final List<PraSnapshotInfo> snapshots;
  final DateTime timestamp;

  const PcaPraReport({
    required this.dockerNode,
    required this.postgresNode,
    required this.vercelNode,
    required this.ngrokNode,
    required this.totalLocalDocuments,
    required this.pendingSyncQueue,
    required this.snapshots,
    required this.timestamp,
  });
}

/// Service de gestion PCA (Continuité) et PRA (Reprise d'Activité)
class PcaPraService {
  static final PcaPraService _instance = PcaPraService._internal();
  factory PcaPraService() => _instance;
  PcaPraService._internal();

  final _reportController = StreamController<PcaPraReport>.broadcast();
  Stream<PcaPraReport> get reportStream => _reportController.stream;
  final LocalStorage _localStorage = LocalStorage();

  PcaPraReport? _lastReport;
  PcaPraReport? get lastReport => _lastReport;

  Timer? _periodicCheckTimer;

  void startMonitoring({Duration interval = const Duration(seconds: 15)}) {
    _periodicCheckTimer?.cancel();
    checkHealth();
    _periodicCheckTimer = Timer.periodic(interval, (_) => checkHealth());
  }

  void stopMonitoring() {
    _periodicCheckTimer?.cancel();
    _periodicCheckTimer = null;
  }

  Uri _apiUri(String path) => Uri.base.resolve('/api/$path');

  bool get _hasLocalApi =>
      (Uri.base.scheme == 'http' || Uri.base.scheme == 'https') &&
      Uri.base.hasAuthority;

  Map<String, String> _apiHeaders({bool jsonBody = false}) {
    final headers = <String, String>{
      'ngrok-skip-browser-warning': 'true',
      'Accept': 'application/json',
    };
    if (jsonBody) headers['Content-Type'] = 'application/json';
    final token = _localStorage.getSessionItem('auth_token');
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
      headers['x-session-token'] = token;
    }
    return headers;
  }

  /// Vérifie la santé de tous les nœuds et produit un rapport complet
  Future<PcaPraReport> checkHealth() async {
    final now = DateTime.now();

    // 1. Docker LAN API Check
    bool dockerOnline = false;
    int? dockerLatency;
    String dockerDetails = 'Non joignable ou hors-ligne';
    Map<String, dynamic>? pcaData;

    if (_hasLocalApi) {
      final sw = Stopwatch()..start();
      try {
        final res = await http.get(
          _apiUri('pca/status'),
          headers: _apiHeaders(),
        ).timeout(const Duration(seconds: 4));
        sw.stop();
        if (res.statusCode == 200) {
          dockerOnline = true;
          dockerLatency = sw.elapsedMilliseconds;
          pcaData = jsonDecode(res.body) as Map<String, dynamic>;
          final uptime = pcaData['uptimeSeconds'] ?? 0;
          final mem = pcaData['memoryUsageMb'] ?? 0;
          dockerDetails = 'Opérationnel (Uptime: ${uptime}s, RAM: ${mem}MB)';
        }
      } catch (e) {
        dockerDetails = 'Injoignable: ${e.toString()}';
      }
    }

    // 2. Frontend node
    final isWebHosted = kIsWeb && Uri.base.host.isNotEmpty;
    final vercelOnline = isWebHosted;
    final vercelDetails = isWebHosted
        ? 'SPA active sur ${Uri.base.host}'
        : 'Exécution locale / mobile';

    // 3. Ngrok Tunnel Check
    bool ngrokDetected = false;
    String ngrokDetails = 'Aucun tunnel actif';
    if (Uri.base.host.contains('ngrok') || Uri.base.host.contains('ngrok-free.app')) {
      ngrokDetected = true;
      ngrokDetails = 'Accès via tunnel: ${Uri.base.host}';
    }

    // Extraire les snapshots PRA si retournés par Docker
    final snapshots = <PraSnapshotInfo>[];
    if (pcaData != null && pcaData['pra'] is Map && pcaData['pra']['latestSnapshot'] != null) {
      try {
        final snapListRes = await http.get(
          _apiUri('pra/snapshots'),
          headers: _apiHeaders(),
        ).timeout(const Duration(seconds: 4));
        if (snapListRes.statusCode == 200) {
          final body = jsonDecode(snapListRes.body) as Map<String, dynamic>;
          final list = body['snapshots'] as List<dynamic>? ?? [];
          for (final item in list) {
            if (item is Map) snapshots.add(PraSnapshotInfo.fromMap(Map<String, dynamic>.from(item)));
          }
        }
      } catch (_) {}
    }

    // Compteurs de documents
    int totalDocs = 0;
    if (pcaData != null && pcaData['counts'] is Map) {
      for (final v in (pcaData['counts'] as Map).values) {
        totalDocs += (int.tryParse(v.toString()) ?? 0);
      }
    }

    final report = PcaPraReport(
      dockerNode: NodeHealth(
        name: 'Serveur Docker (LAN)',
        type: 'docker',
        isOnline: dockerOnline,
        latencyMs: dockerLatency,
        details: dockerDetails,
        lastChecked: now,
      ),
      postgresNode: NodeHealth(
        name: 'PostgreSQL local',
        type: 'postgres',
        isOnline: dockerOnline,
        latencyMs: dockerLatency,
        details: dockerOnline ? 'Disponible via l’API locale' : 'API locale indisponible',
        lastChecked: now,
      ),
      vercelNode: NodeHealth(
        name: 'Vercel CDN (Frontend Web)',
        type: 'vercel',
        isOnline: vercelOnline,
        latencyMs: null,
        details: vercelDetails,
        lastChecked: now,
      ),
      ngrokNode: NodeHealth(
        name: 'Tunnel Sécurisé (Ngrok / WAN)',
        type: 'ngrok',
        isOnline: ngrokDetected,
        latencyMs: null,
        details: ngrokDetails,
        lastChecked: now,
      ),
      totalLocalDocuments: totalDocs,
      pendingSyncQueue: (pcaData?['supabase']?['pendingSyncCount'] as int?) ?? 0,
      snapshots: snapshots,
      timestamp: now,
    );

    _lastReport = report;
    _reportController.add(report);
    return report;
  }

  /// Créer un instantané PRA manuel
  Future<bool> createSnapshot({String label = 'manuel', String reason = 'Déclenché par Admin'}) async {
    if (!_hasLocalApi) return false;
    try {
      final res = await http.post(
        _apiUri('pra/snapshot'),
        headers: _apiHeaders(jsonBody: true),
        body: jsonEncode({'label': label, 'reason': reason}),
      ).timeout(const Duration(seconds: 8));
      await checkHealth();
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Déclencher une réconciliation bidirectionnelle forcée
  Future<bool> forceReconcile() async {
    if (!_hasLocalApi) return false;
    try {
      final res = await http.post(
        _apiUri('pra/reconcile'),
        headers: _apiHeaders(jsonBody: true),
      ).timeout(const Duration(seconds: 15));
      await checkHealth();
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Restaurer depuis un snapshot PRA
  Future<bool> restoreSnapshot(String filename) async {
    if (!_hasLocalApi) return false;
    try {
      final res = await http.post(
        _apiUri('pra/restore'),
        headers: _apiHeaders(jsonBody: true),
        body: jsonEncode({'filename': filename}),
      ).timeout(const Duration(seconds: 15));
      await checkHealth();
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

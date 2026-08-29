import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:gestion_formations/Models/user.dart';
import 'package:gestion_formations/Models/formation.dart';
import 'package:gestion_formations/Models/inscription.dart';
import 'package:gestion_formations/Models/payment.dart';
import 'package:gestion_formations/Models/notification.dart';
import 'package:gestion_formations/Models/audit_log.dart';
import 'package:gestion_formations/Models/seance.dart';
import 'package:gestion_formations/Services/local_storage.dart';
import 'package:gestion_formations/Services/supabase_config.dart';
import 'package:gestion_formations/Services/supabase_mapper.dart';
import 'package:gestion_formations/Services/polling_config.dart';

class LocalDataService {
  static final LocalDataService _instance = LocalDataService._internal();
  static const _cacheSchemaVersion = '5';
  static const _cacheSchemaKey = 'malintic_cache_schema';
  factory LocalDataService() => _instance;

  LocalDataService._internal() {
    // Initialiser la configuration de polling (development par défaut)
    _pollingConfig = _determinePollingConfig();
    _pollingController = PollingController(_pollingConfig);
    
    _invalidateObsoleteCache();
    _initInitialData();
    _loadFromStorage();
    _initLocalApiSync();
  }
  
  /// Déterminer la configuration de polling selon l'environnement
  PollingConfig _determinePollingConfig() {
    if (kDebugMode) {
      return PollingConfig.development();
    } else {
      return PollingConfig.production();
    }
  }
  
  /// Obtenir le contrôleur de polling (pour tests/monitoring)
  PollingController getPollingController() => _pollingController;
  
  /// Obtenir la configuration de polling
  PollingConfig getPollingConfig() => _pollingConfig;

  final LocalStorage _localStorage = LocalStorage();
  late final PollingController _pollingController;
  late final PollingConfig _pollingConfig;



  // ignore: unused_field
  Timer? _apiPollingTimer;
  bool _syncInProgress = false;
  bool _repairingMatricules = false;
  String? _lastStateEtag;

  void _invalidateObsoleteCache() {
    // Version 2 stops browser-to-server merging. Discard the old persisted
    // collections once so records deleted on the server cannot appear again.
    if (_localStorage.getItem(_cacheSchemaKey) == _cacheSchemaVersion) return;
    const cachedCollections = [
      'app_saved_users',
      'app_saved_formations',
      'app_saved_inscriptions',
      'app_saved_payments',
      'app_saved_seances',
      'app_saved_notifications',
      'app_saved_audit_logs',
    ];
    for (final key in cachedCollections) {
      _localStorage.removeItem(key);
    }
    _localStorage.setItem(_cacheSchemaKey, _cacheSchemaVersion);
  }

  Uri _apiUri(String path) => Uri.base.resolve('/api/$path');
  bool get _hasLocalApi =>
      (Uri.base.scheme == 'http' || Uri.base.scheme == 'https') &&
      Uri.base.hasAuthority;

  void _initLocalApiSync() {
    final isTestRuntime = Uri.base.scheme == 'file';
    if (isTestRuntime) return;
    if (!_hasLocalApi && !SupabaseConfig.isEnabled) return;
    
    _syncFromLocalApi();
    
    // Lancer le polling avec l'intervalle initial
    _scheduleNextSync();
  }
  
  /// Planifier le prochain sync avec l'intervalle actuel
  void _scheduleNextSync() {
    _apiPollingTimer?.cancel();
    
    final interval = _pollingController.getCurrentInterval();
    
    _apiPollingTimer = Timer(interval, () {
      _syncFromLocalApi();
      // Toujours replanifier après sync
      _scheduleNextSync();
    });
  }

  Set<String> _getDeletedDocs(String collection) {
    try {
      final raw = _localStorage.getItem('app_deleted_ids_$collection');
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        return list.map((e) => e.toString()).toSet();
      }
    } catch (_) {}
    return <String>{};
  }

  void _recordDeletedDoc(String collection, String docId) {
    try {
      final set = _getDeletedDocs(collection);
      set.add(docId);
      _localStorage.setItem('app_deleted_ids_$collection', jsonEncode(set.toList()));
    } catch (_) {}
  }

  Set<String> getDeletedDocs(String collection) => _getDeletedDocs(collection);
  void recordDeletedDoc(String collection, String docId) => _recordDeletedDoc(collection, docId);

  void _unrecordDeletedDoc(String collection, String docId) {
    try {
      final set = _getDeletedDocs(collection);
      if (set.remove(docId)) {
        _localStorage.setItem('app_deleted_ids_$collection', jsonEncode(set.toList()));
      }
    } catch (_) {}
  }
  void unrecordDeletedDoc(String collection, String docId) => _unrecordDeletedDoc(collection, docId);

  void _enqueuePendingSync(String collection, String docId, String method, Map<String, dynamic>? data) {
    try {
      final raw = _localStorage.getItem('app_pending_sync_queue');
      List<dynamic> queue = [];
      if (raw != null && raw.isNotEmpty) {
        try { queue = jsonDecode(raw) as List<dynamic>; } catch (_) {}
      }
      queue.add({
        'collection': collection,
        'docId': docId,
        'method': method,
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
      });
      _localStorage.setItem('app_pending_sync_queue', jsonEncode(queue));
    } catch (_) {}
  }

  Future<void> _flushPendingSyncQueue() async {
    if (!_hasLocalApi) return;
    final raw = _localStorage.getItem('app_pending_sync_queue');
    if (raw == null || raw.isEmpty) return;
    try {
      final List<dynamic> queue = jsonDecode(raw) as List<dynamic>;
      final List<dynamic> remaining = [];
      for (final item in queue) {
        if (item is! Map) continue;
        final collection = item['collection']?.toString() ?? '';
        final docId = item['docId']?.toString() ?? '';
        final method = item['method']?.toString() ?? 'PUT';
        final data = item['data'] is Map ? Map<String, dynamic>.from(item['data']) : null;

        try {
          if (method == 'DELETE') {
            await http.delete(
              _apiUri('$collection/${Uri.encodeComponent(docId)}'),
              headers: const {'ngrok-skip-browser-warning': 'true'},
            ).timeout(const Duration(seconds: 10));
          } else if (data != null) {
            await http.put(
              _apiUri('$collection/${Uri.encodeComponent(docId)}'),
              headers: const {
                'Content-Type': 'application/json',
                'ngrok-skip-browser-warning': 'true',
              },
              body: jsonEncode(data),
            ).timeout(const Duration(seconds: 10));
          }
        } catch (_) {
          remaining.add(item);
        }
      }
      if (remaining.isEmpty) {
        _localStorage.removeItem('app_pending_sync_queue');
      } else {
        _localStorage.setItem('app_pending_sync_queue', jsonEncode(remaining));
      }
    } catch (_) {}
  }

  Future<void> _syncFromLocalApi() async {
    if (_syncInProgress) return;
    _syncInProgress = true;
    try {
      await _flushPendingSyncQueue();

      if (!_hasLocalApi) {
        if (SupabaseConfig.isEnabled) {
          await _syncFromSupabase();
        }
        return;
      }

      final headers = <String, String>{
        'ngrok-skip-browser-warning': 'true',
        'Accept': 'application/json',
      };
      if (_lastStateEtag != null && _lastStateEtag!.isNotEmpty) {
        headers['If-None-Match'] = _lastStateEtag!;
      }

      final response = await http
          .get(_apiUri('state'), headers: headers)
          .timeout(_pollingConfig.requestTimeout);

      if (response.statusCode == 304) {
        // État inchangé côté serveur, aucune désérialisation nécessaire (optimisation latence)
        // ✅ C'est un succès: la requête s'est bien déroulée
        _pollingController.recordSuccess();
        _scheduleNextSync();
        return;
      }
      if (response.statusCode != 200) {
        // ❌ Erreur API
        _pollingController.recordError();
        _scheduleNextSync();
        if (SupabaseConfig.isEnabled) {
          await _syncFromSupabase();
        }
        return;
      }
      if (response.headers['etag'] != null) {
        _lastStateEtag = response.headers['etag'];
      }
      final state = jsonDecode(response.body) as Map<String, dynamic>;
      final users = (state['users'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map(
            (item) => User.fromMap(
              Map<String, dynamic>.from(item),
              item['id']?.toString() ?? '',
            ),
          )
          .toList();
      final formations = (state['formations'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map(
            (item) => Formation.fromMap(
              Map<String, dynamic>.from(item),
              item['id']?.toString() ?? '',
            ),
          )
          .toList();
      final inscriptions = (state['inscriptions'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map(
            (item) => Inscription.fromMap(
              Map<String, dynamic>.from(item),
              item['id']?.toString() ?? '',
            ),
          )
          .toList();
      final payments = (state['payments'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map(
            (item) => Payment.fromMap(
              Map<String, dynamic>.from(item),
              item['id']?.toString() ?? '',
            ),
          )
          .toList();
      final notifications = (state['notifications'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map(
            (item) => AppNotification.fromMap(
              Map<String, dynamic>.from(item),
              item['id']?.toString() ?? '',
            ),
          )
          .toList();
      final logs = (state['audit_logs'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((item) => AuditLog.fromMap(Map<String, dynamic>.from(item)))
          .toList();
      final seances = (state['seances'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map(
            (item) => Seance.fromMap(
              Map<String, dynamic>.from(item),
              item['id']?.toString() ?? '',
            ),
          )
          .toList();

      if (formations.isNotEmpty) {
        _formations
          ..clear()
          ..addAll(formations);
        _saveFormationsToStorage();
        _formationsController.add(List.unmodifiable(_formations));
      }
      if (users.isNotEmpty) {
        final deletedUserIds = _getDeletedDocs('users');
        final deletedUserEmails = _getDeletedDocs('user_emails');
        final validServerUsers = users.where((u) =>
            !deletedUserIds.contains(u.id) &&
            !deletedUserEmails.contains(u.email.trim().toLowerCase())
        ).toList();
        final serverUserIds = validServerUsers.map((u) => u.id).toSet();
        _users.removeWhere((u) =>
            deletedUserIds.contains(u.id) ||
            deletedUserEmails.contains(u.email.trim().toLowerCase()) ||
            !serverUserIds.contains(u.id)
        );
        for (final user in validServerUsers) {
          final existingIndex = _users.indexWhere((u) => u.id == user.id);
          if (existingIndex >= 0) {
            _users[existingIndex] = user;
          } else {
            _users.add(user);
          }
        }
        _saveUsersToStorage();
        _usersController.add(List.unmodifiable(_users));

        for (final deletedId in deletedUserIds) {
          if (users.any((u) => u.id == deletedId)) {
            _deleteRemoteDoc('users', deletedId);
          }
        }
      }
      if (inscriptions.isNotEmpty) {
        final deletedInscIds = _getDeletedDocs('inscriptions');
        final deletedUserIds = _getDeletedDocs('users');
        final deletedUserEmails = _getDeletedDocs('user_emails');
        final validInscriptions = inscriptions.where((i) {
          final email = i.email?.trim().toLowerCase() ?? '';
          return !deletedInscIds.contains(i.id) &&
              !deletedUserIds.contains(i.etudiantId) &&
              !deletedUserIds.contains(i.id) &&
              (email.isEmpty || !deletedUserEmails.contains(email));
        }).toList();
        final serverInscriptionIds = validInscriptions.map((i) => i.id).toSet();
        _inscriptions.removeWhere((i) {
          final email = i.email?.trim().toLowerCase() ?? '';
          return deletedInscIds.contains(i.id) ||
              deletedUserIds.contains(i.etudiantId) ||
              deletedUserIds.contains(i.id) ||
              (email.isNotEmpty && deletedUserEmails.contains(email)) ||
              !serverInscriptionIds.contains(i.id);
        });
        for (final inscription in validInscriptions) {
          final existingIndex = _inscriptions.indexWhere((i) => i.id == inscription.id);
          if (existingIndex >= 0) {
            _inscriptions[existingIndex] = inscription;
          } else {
            _inscriptions.add(inscription);
          }
        }
        _saveInscriptionsToStorage();
        _inscriptionsController.add(List.unmodifiable(_inscriptions));

        for (final deletedId in deletedInscIds) {
          if (inscriptions.any((i) => i.id == deletedId)) {
            _deleteRemoteDoc('inscriptions', deletedId);
          }
        }
      }
      if (payments.isNotEmpty) {
        final serverPaymentIds = payments.map((p) => p.id).toSet();
        _payments.removeWhere((p) => !serverPaymentIds.contains(p.id));
        for (final payment in payments) {
          final existingIndex = _payments.indexWhere((p) => p.id == payment.id);
          if (existingIndex >= 0) {
            _payments[existingIndex] = payment;
          } else {
            _payments.add(payment);
          }
        }
        _savePaymentsToStorage();
        _paymentsController.add(List.unmodifiable(_payments));
      }
      if (notifications.isNotEmpty) {
        final serverNotificationIds = notifications.map((n) => n.id).toSet();
        _notifications.removeWhere((n) => !serverNotificationIds.contains(n.id));
        for (final notification in notifications) {
          final existingIndex = _notifications.indexWhere((n) => n.id == notification.id);
          if (existingIndex >= 0) {
            _notifications[existingIndex] = notification;
          } else {
            _notifications.add(notification);
          }
        }
        _notificationsController.add(List.unmodifiable(_notifications));
      }
      if (logs.isNotEmpty) {
        final serverLogIds = logs.map((l) => l.id).toSet();
        _auditLogs.removeWhere((l) => !serverLogIds.contains(l.id));
        for (final log in logs) {
          final existingIndex = _auditLogs.indexWhere((l) => l.id == log.id);
          if (existingIndex >= 0) {
            _auditLogs[existingIndex] = log;
          } else {
            _auditLogs.add(log);
          }
        }
        _auditLogsController.add(List.unmodifiable(_auditLogs));
      }
      if (seances.isNotEmpty) {
        final serverSeanceIds = seances.map((s) => s.id).toSet();
        _seances.removeWhere((s) => !serverSeanceIds.contains(s.id));
        for (final seance in seances) {
          final existingIndex = _seances.indexWhere((s) => s.id == seance.id);
          if (existingIndex >= 0) {
            _seances[existingIndex] = seance;
          } else {
            _seances.add(seance);
          }
        }
        _saveSeancesToStorage();
        _seancesController.add(List.unmodifiable(_seances));
      }
      
      // ✅ Sync successful - record success for backoff optimization
      _pollingController.recordSuccess();
      _scheduleNextSync();
    } catch (e) {
      debugPrint('[Malintic] Erreur sync API: $e');
      
      // ❌ Sync failed - record error for exponential backoff
      _pollingController.recordError();
      _scheduleNextSync();
      
      if (SupabaseConfig.isEnabled) {
        try {
          await _syncFromSupabase();
        } catch (_) {}
      }
    } finally {
      _syncInProgress = false;
    }
  }

  Uri _supabaseUri(String collection) {
    final select = SupabaseMapper.selectFor(collection);
    return Uri.parse('${SupabaseConfig.url}/rest/v1/$collection?select=$select');
  }

  Future<void> _syncFromSupabase() async {
    if (!SupabaseConfig.isEnabled || !SupabaseConfig.isConfigured) return;
    try {
      final headers = SupabaseConfig.headers;

      final results = await Future.wait([
        http.get(_supabaseUri('formations'), headers: headers),
        http.get(_supabaseUri('users'), headers: headers),
        http.get(_supabaseUri('inscriptions'), headers: headers),
        http.get(_supabaseUri('payments'), headers: headers),
        http.get(_supabaseUri('seances'), headers: headers),
        http.get(_supabaseUri('audit_logs'), headers: headers),
        http.get(_supabaseUri('notifications'), headers: headers),
      ]).timeout(const Duration(seconds: 15));

      if (results[0].statusCode == 200) {
        final list = jsonDecode(results[0].body) as List<dynamic>;
        final formations = list
            .whereType<Map>()
            .map((m) => SupabaseMapper.formationFromRow(Map<String, dynamic>.from(m)))
            .toList();
        if (formations.isNotEmpty) {
          _formations
            ..clear()
            ..addAll(formations);
          _saveFormationsToStorage();
          _formationsController.add(List.unmodifiable(_formations));
        }
      }

      if (results[1].statusCode == 200) {
        final list = jsonDecode(results[1].body) as List<dynamic>;
        final users = list
            .whereType<Map>()
            .map((m) => SupabaseMapper.userFromRow(Map<String, dynamic>.from(m)))
            .toList();
        final deletedUserIds = _getDeletedDocs('users');
        final deletedUserEmails = _getDeletedDocs('user_emails');
        final validUsers = users
            .where(
              (u) =>
                  !deletedUserIds.contains(u.id) &&
                  !deletedUserEmails.contains(u.email.trim().toLowerCase()),
            )
            .toList();
        if (validUsers.isNotEmpty) {
          _users
            ..clear()
            ..addAll(validUsers);
          _saveUsersToStorage();
          _usersController.add(List.unmodifiable(_users));
        }
      }

      if (results[2].statusCode == 200) {
        final list = jsonDecode(results[2].body) as List<dynamic>;
        final inscriptions = list
            .whereType<Map>()
            .map((m) => SupabaseMapper.inscriptionFromRow(Map<String, dynamic>.from(m)))
            .toList();
        final deletedInscIds = _getDeletedDocs('inscriptions');
        final deletedUserIds = _getDeletedDocs('users');
        final deletedUserEmails = _getDeletedDocs('user_emails');
        final validInscriptions = inscriptions.where((i) {
          final email = i.email?.trim().toLowerCase() ?? '';
          return !deletedInscIds.contains(i.id) &&
              !deletedUserIds.contains(i.etudiantId) &&
              !deletedUserIds.contains(i.id) &&
              (email.isEmpty || !deletedUserEmails.contains(email));
        }).toList();
        _inscriptions
          ..clear()
          ..addAll(validInscriptions);
        _saveInscriptionsToStorage();
        _inscriptionsController.add(List.unmodifiable(_inscriptions));
      }

      if (results[3].statusCode == 200) {
        final list = jsonDecode(results[3].body) as List<dynamic>;
        final payments = list
            .whereType<Map>()
            .map((m) => SupabaseMapper.paymentFromRow(Map<String, dynamic>.from(m)))
            .toList();
        _payments
          ..clear()
          ..addAll(payments);
        _savePaymentsToStorage();
        _paymentsController.add(List.unmodifiable(_payments));
      }

      if (results[4].statusCode == 200) {
        final list = jsonDecode(results[4].body) as List<dynamic>;
        final seances = list
            .whereType<Map>()
            .map((m) => SupabaseMapper.seanceFromRow(Map<String, dynamic>.from(m)))
            .toList();
        _seances
          ..clear()
          ..addAll(seances);
        _saveSeancesToStorage();
        _seancesController.add(List.unmodifiable(_seances));
      }

      if (results[5].statusCode == 200) {
        final list = jsonDecode(results[5].body) as List<dynamic>;
        final logs = list
            .whereType<Map>()
            .map((m) => SupabaseMapper.auditLogFromRow(Map<String, dynamic>.from(m)))
            .toList();
        _auditLogs
          ..clear()
          ..addAll(logs);
        _saveAuditLogsToStorage();
        _auditLogsController.add(List.unmodifiable(_auditLogs));
      }

      if (results[6].statusCode == 200) {
        final list = jsonDecode(results[6].body) as List<dynamic>;
        final notifications = list
            .whereType<Map>()
            .map((m) => SupabaseMapper.notificationFromRow(Map<String, dynamic>.from(m)))
            .toList();
        if (notifications.isNotEmpty) {
          _notifications
            ..clear()
            ..addAll(notifications);
          _notificationsController.add(List.unmodifiable(_notifications));
        }
      }
    } catch (e) {
      debugPrint('[Malintic] Erreur sync Supabase: $e');
    }
  }

  Future<void> mergeLocalDataWithServer() async {
    await _syncFromLocalApi();
  }

  void setServerSessionActive(bool active) {}

  Future<void> refreshFromServer() {
    return _syncFromLocalApi();
  }

  Future<void> _syncDocToLocalApi(
    String collection,
    String docId,
    Map<String, dynamic> data,
  ) async {
    if (_hasLocalApi) {
      bool localSuccess = false;
      try {
        final response = await http
            .put(
              _apiUri('$collection/${Uri.encodeComponent(docId)}'),
              headers: const {
                'Content-Type': 'application/json',
                'ngrok-skip-browser-warning': 'true',
              },
              body: jsonEncode(data),
            )
            .timeout(const Duration(seconds: 10));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          localSuccess = true;
        }
      } catch (_) {}
      if (!localSuccess) {
        _enqueuePendingSync(collection, docId, 'PUT', data);
      }
    }

    if (SupabaseConfig.isEnabled && SupabaseConfig.isConfigured) {
      try {
        final row = SupabaseMapper.toRow(collection, data);
        await http
            .post(
              Uri.parse('${SupabaseConfig.url}/rest/v1/$collection'),
              headers: SupabaseConfig.writeHeaders,
              body: jsonEncode(row),
            )
            .timeout(const Duration(seconds: 10));
      } catch (e) {
        debugPrint('[Malintic] Erreur sync Supabase $collection/$docId: $e');
      }
    }
  }

  Future<void> _deleteRemoteDoc(String collection, String docId) async {
    _recordDeletedDoc(collection, docId);
    if (_hasLocalApi) {
      bool localSuccess = false;
      try {
        final response = await http
            .delete(
              _apiUri('$collection/${Uri.encodeComponent(docId)}'),
              headers: const {'ngrok-skip-browser-warning': 'true'},
            )
            .timeout(const Duration(seconds: 10));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          localSuccess = true;
        }
      } catch (_) {}
      if (!localSuccess) {
        _enqueuePendingSync(collection, docId, 'DELETE', null);
      }
    }

    if (SupabaseConfig.isEnabled && SupabaseConfig.isConfigured) {
      try {
        await http
            .delete(
              Uri.parse(
                '${SupabaseConfig.url}/rest/v1/$collection?id=eq.${Uri.encodeComponent(docId)}',
              ),
              headers: SupabaseConfig.headers,
            )
            .timeout(const Duration(seconds: 10));
      } catch (e) {
        debugPrint('[Malintic] Erreur delete Supabase $collection/$docId: $e');
      }
    }
  }

  Map<String, dynamic> exportFullBackup() {
    return {
      'version': '2.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'users': _users.map((u) => u.toMap()).toList(),
      'formations': _formations.map((f) => f.toMap()).toList(),
      'inscriptions': _inscriptions.map((i) => i.toMap()).toList(),
      'payments': _payments.map((p) => p.toMap()).toList(),
      'seances': _seances.map((s) => s.toMap()).toList(),
      'notifications': _notifications.map((n) => n.toMap()).toList(),
      'audit_logs': _auditLogs.map((a) => a.toMap()).toList(),
    };
  }

  Future<bool> importFullBackup(Map<String, dynamic> data) async {
    try {
      if (data['users'] is List) {
        final users = (data['users'] as List)
            .whereType<Map>()
            .map((item) => User.fromMap(Map<String, dynamic>.from(item), item['id']?.toString() ?? ''))
            .toList();
        if (users.isNotEmpty) {
          _users
            ..clear()
            ..addAll(users);
          _saveUsersToStorage();
          _usersController.add(List.unmodifiable(_users));
        }
      }
      if (data['formations'] is List) {
        final formations = (data['formations'] as List)
            .whereType<Map>()
            .map((item) => Formation.fromMap(Map<String, dynamic>.from(item), item['id']?.toString() ?? ''))
            .toList();
        if (formations.isNotEmpty) {
          _formations
            ..clear()
            ..addAll(formations);
          _saveFormationsToStorage();
          _formationsController.add(List.unmodifiable(_formations));
        }
      }
      if (data['inscriptions'] is List) {
        final inscriptions = (data['inscriptions'] as List)
            .whereType<Map>()
            .map((item) => Inscription.fromMap(Map<String, dynamic>.from(item), item['id']?.toString() ?? ''))
            .toList();
        if (inscriptions.isNotEmpty) {
          _inscriptions
            ..clear()
            ..addAll(inscriptions);
          _saveInscriptionsToStorage();
          _inscriptionsController.add(List.unmodifiable(_inscriptions));
        }
      }
      if (data['payments'] is List) {
        final payments = (data['payments'] as List)
            .whereType<Map>()
            .map((item) => Payment.fromMap(Map<String, dynamic>.from(item), item['id']?.toString() ?? ''))
            .toList();
        if (payments.isNotEmpty) {
          _payments
            ..clear()
            ..addAll(payments);
          _savePaymentsToStorage();
          _paymentsController.add(List.unmodifiable(_payments));
        }
      }
      if (data['seances'] is List) {
        final seances = (data['seances'] as List)
            .whereType<Map>()
            .map((item) => Seance.fromMap(Map<String, dynamic>.from(item), item['id']?.toString() ?? ''))
            .toList();
        if (seances.isNotEmpty) {
          _seances
            ..clear()
            ..addAll(seances);
          _saveSeancesToStorage();
          _seancesController.add(List.unmodifiable(_seances));
        }
      }
      return true;
    } catch (e) {
      debugPrint('[Malintic] Erreur import backup: $e');
      return false;
    }
  }

  void _deduplicateAndNormalizeUsers() {
    final deletedUserIds = _getDeletedDocs('users');
    final deletedUserEmails = _getDeletedDocs('user_emails');
    final Map<String, User> cleanMap = {};
    for (final u in _users) {
      final normEmail = u.email.trim().toLowerCase().replaceAll(
        '@mali-ntic.ml',
        '@malintic.ml',
      );
      if (deletedUserIds.contains(u.id) || deletedUserEmails.contains(normEmail) || deletedUserEmails.contains(u.email.trim().toLowerCase())) {
        continue;
      }
      final cleanName =
          '${u.prenom.trim().toLowerCase()}.${u.nom.trim().toLowerCase()}'
              .replaceAll(RegExp(r'[^a-z0-9.]'), '');
      final key = cleanName.replaceAll('.', '').isNotEmpty
          ? cleanName
          : (normEmail.isNotEmpty ? normEmail : u.id);

      final existing = cleanMap[key];
      if (existing == null) {
        cleanMap[key] = User(
          id: u.id,
          email: normEmail,
          nom: u.nom,
          prenom: u.prenom,
          phone: u.phone,
          matricule: u.matricule,
          role: u.role,
          password: u.password.isNotEmpty ? u.password : '00000000',
          photoUrl: u.photoUrl,
          assignedFormations: u.assignedFormations,
          estActif: u.estActif,
          dateCreation: u.dateCreation,
          dateModification: u.dateModification,
        );
      } else {
        final mergedAssignments = [
          ...existing.assignedFormations,
          ...u.assignedFormations,
        ];
        cleanMap[key] = User(
          id: existing.id,
          email: normEmail.contains('@malintic.ml')
              ? normEmail
              : existing.email,
          nom: existing.nom.isNotEmpty ? existing.nom : u.nom,
          prenom: existing.prenom.isNotEmpty ? existing.prenom : u.prenom,
          phone: existing.phone.isNotEmpty ? existing.phone : u.phone,
          matricule: existing.matricule ?? u.matricule,
          role: existing.role,
          password: existing.password.isNotEmpty
              ? existing.password
              : '00000000',
          photoUrl: existing.photoUrl ?? u.photoUrl,
          assignedFormations: mergedAssignments,
          estActif: existing.estActif,
          dateCreation: existing.dateCreation,
          dateModification: DateTime.now(),
        );
      }
    }
    _users.clear();
    _users.addAll(cleanMap.values);
  }

  List<User> _defaultBaselineUsers() {
    return [
      User(
        id: 'admin_mamadou',
        nom: 'TOURE',
        prenom: 'Mamadou',
        email: 'mamadou@malintic.ml',
        phone: '+223 70 00 00 01',
        role: UserRole.admin,
        matricule: 'ADM-2026-001',
        doitChangerMotDePasse: true,
        sexe: 'Homme',
        estActif: true,
        dateCreation: DateTime(2026, 8, 1),
      ),
      User(
        id: 'dg_souleymane',
        nom: 'TRAORE',
        prenom: 'SOULEYMANE',
        email: 'soulbico@malintic.ml',
        phone: '+223 76 00 00 01',
        role: UserRole.admin,
        sexe: 'Homme',
        estActif: true,
        dateCreation: DateTime(2026, 8, 1),
      ),
      User(
        id: 'admin_malintic',
        nom: 'M@LI-NTIC',
        prenom: 'Admin',
        email: 'admin@malintic.ml',
        phone: '+223 70 00 00 00',
        role: UserRole.admin,
        matricule: 'ADM-2026-000',
        sexe: 'Homme',
        estActif: true,
        dateCreation: DateTime(2026, 8, 1),
      ),
      User(
        id: 'formateur_1',
        prenom: 'Dr. Ousmane',
        nom: 'Diarra',
        email: 'ousmane.diarra@malintic.ml',
        phone: '+223 77 88 99 00',
        role: UserRole.formateur,
        specialite: 'Expert Flutter & Architectures Mobiles',
        estActif: true,
      ),
      User(
        id: 'formateur_2',
        prenom: 'Awa',
        nom: 'Koné',
        email: 'awa.kone@malintic.ml',
        phone: '+223 66 55 44 33',
        role: UserRole.formateur,
        specialite: 'Lead Web React & Node.js',
        estActif: true,
      ),
      User(
        id: 'formateur_3',
        prenom: 'Moussa',
        nom: 'Traoré',
        email: 'moussa.traore@malintic.ml',
        phone: '+223 71 22 33 44',
        role: UserRole.formateur,
        specialite: 'Infographie & Design Graphique',
        estActif: true,
      ),
    ];
  }

  void _loadFromStorage() {
    try {
      final deletedUserIds = _getDeletedDocs('users');
      final deletedUserEmails = _getDeletedDocs('user_emails');
      final deletedInscIds = _getDeletedDocs('inscriptions');

      final savedUsersRaw = _localStorage.getItem('app_saved_users');
      _users.clear();
      if (savedUsersRaw != null && savedUsersRaw.isNotEmpty) {
        final List<dynamic> list = jsonDecode(savedUsersRaw);
        for (final item in list) {
          if (item is Map) {
            final user = User.fromMap(Map<String, dynamic>.from(item), item['id']?.toString() ?? '');
            if (!deletedUserIds.contains(user.id) &&
                !deletedUserEmails.contains(user.email.trim().toLowerCase())) {
              _users.add(user);
            }
          }
        }
      } else {
        _users.addAll(_defaultBaselineUsers().where((u) =>
            !deletedUserIds.contains(u.id) &&
            !deletedUserEmails.contains(u.email.trim().toLowerCase())));
        _saveUsersToStorage();
      }
      _deduplicateAndNormalizeUsers();

      final savedFormationsRaw = _localStorage.getItem('app_saved_formations');
      if (savedFormationsRaw != null && savedFormationsRaw.isNotEmpty) {
        final List<dynamic> list = jsonDecode(savedFormationsRaw);
        _formations.clear();
        for (final item in list) {
          if (item is Map) {
            final formation = Formation.fromMap(Map<String, dynamic>.from(item), item['id']?.toString() ?? '');
            _formations.add(formation);
          }
        }
      }

      final savedInscRaw = _localStorage.getItem('app_saved_inscriptions');
      if (savedInscRaw != null && savedInscRaw.isNotEmpty) {
        final List<dynamic> list = jsonDecode(savedInscRaw);
        _inscriptions.clear();
        for (final item in list) {
          if (item is Map) {
            final insc = Inscription.fromMap(Map<String, dynamic>.from(item), item['id']?.toString() ?? '');
            final email = insc.email?.trim().toLowerCase() ?? '';
            if (!deletedInscIds.contains(insc.id) &&
                !deletedUserIds.contains(insc.etudiantId) &&
                !deletedUserIds.contains(insc.id) &&
                (email.isEmpty || !deletedUserEmails.contains(email))) {
              _inscriptions.add(insc);
            }
          }
        }
      }

      final savedPayRaw = _localStorage.getItem('app_saved_payments');
      if (savedPayRaw != null && savedPayRaw.isNotEmpty) {
        final List<dynamic> payList = jsonDecode(savedPayRaw);
        _payments.clear();
        for (final item in payList) {
          if (item is Map) {
            final pay = Payment.fromMap(Map<String, dynamic>.from(item), item['id']?.toString() ?? '');
            _payments.add(pay);
          }
        }
      }

      final savedSeancesRaw = _localStorage.getItem('app_saved_seances');
      if (savedSeancesRaw != null && savedSeancesRaw.isNotEmpty) {
        final List<dynamic> seanceList = jsonDecode(savedSeancesRaw);
        _seances.clear();
        for (final item in seanceList) {
          if (item is Map) {
            final seance = Seance.fromMap(Map<String, dynamic>.from(item), item['id']?.toString() ?? '');
            _seances.add(seance);
          }
        }
      }
      _usersController.add(List.unmodifiable(_users));
      _formationsController.add(List.unmodifiable(_formations));
      _inscriptionsController.add(List.unmodifiable(_inscriptions));
      _paymentsController.add(List.unmodifiable(_payments));
      _seancesController.add(List.unmodifiable(_seances));
    } catch (e) {
      debugPrint('[Malintic] Erreur chargement stockage local: $e');
    }
  }

  void _saveFormationsToStorage() {
    try {
      final list = _formations.map((f) => f.toMap()).toList();
      _localStorage.setItem('app_saved_formations', jsonEncode(list));
    } catch (e) { debugPrint('[Malintic] Erreur sauvegarde formations: $e'); }
  }

  void _saveUsersToStorage() {
    try {
      final list = _users.map((u) => u.toMap()).toList();
      _localStorage.setItem('app_saved_users', jsonEncode(list));
    } catch (e) { debugPrint('[Malintic] Erreur sauvegarde users: $e'); }
  }

  void _saveInscriptionsToStorage() {
    try {
      final list = _inscriptions.map((i) => i.toMap()).toList();
      _localStorage.setItem('app_saved_inscriptions', jsonEncode(list));
    } catch (e) { debugPrint('[Malintic] Erreur sauvegarde inscriptions: $e'); }
  }

  void _savePaymentsToStorage() {
    try {
      final list = _payments.map((p) => p.toMap()).toList();
      _localStorage.setItem('app_saved_payments', jsonEncode(list));
    } catch (e) { debugPrint('[Malintic] Erreur sauvegarde paiements: $e'); }
  }

  void _saveSeancesToStorage() {
    try {
      final list = _seances.map((s) => s.toMap()).toList();
      _localStorage.setItem('app_saved_seances', jsonEncode(list));
    } catch (e) { debugPrint('[Malintic] Erreur sauvegarde séances: $e'); }
  }

  // Reactive Data Controllers
  final _usersController = StreamController<List<User>>.broadcast();
  final _formationsController = StreamController<List<Formation>>.broadcast();
  final _inscriptionsController = StreamController<List<Inscription>>.broadcast();
  final _paymentsController = StreamController<List<Payment>>.broadcast();
  final _seancesController = StreamController<List<Seance>>.broadcast();
  final _notificationsController = StreamController<List<AppNotification>>.broadcast();
  final _auditLogsController = StreamController<List<AuditLog>>.broadcast();

  // Internal Storage Lists
  final List<User> _users = [];
  final List<Formation> _formations = [];
  final List<Inscription> _inscriptions = [];
  final List<Payment> _payments = [];
  final List<Seance> _seances = [];
  final List<AppNotification> _notifications = [];
  final List<AuditLog> _auditLogs = [
    AuditLog(id: 'log_1', userNom: 'Mamadou Toure', userRole: 'Admin', action: 'Validation Inscription', description: 'Inscription validée pour le stagiaire Seydou Coulibaly (Développement Mobile Flutter)', timestamp: DateTime.now().subtract(const Duration(minutes: 15))),
    AuditLog(id: 'log_2', userNom: 'Système SFP', userRole: 'Système', action: 'Paiement Enregistré', description: 'Acompte Orange Money reçu (75 000 FCFA) par Fatoumata Sidibé (REF-OM-88392)', timestamp: DateTime.now().subtract(const Duration(hours: 1, minutes: 20))),
    AuditLog(id: 'log_3', userNom: 'Dr. Ousmane Diarra', userRole: 'Formateur', action: 'Pointage Présence', description: 'Pointage effectué pour le module bases de Dart (18/20 stagiaires présents)', timestamp: DateTime.now().subtract(const Duration(hours: 3))),
    AuditLog(id: 'log_4', userNom: 'Admin SFP', userRole: 'Admin', action: 'Création Formation', description: 'Ajout de la nouvelle session SFP5', timestamp: DateTime.now().subtract(const Duration(days: 1))),
  ];

  Stream<List<AuditLog>> watchAuditLogs() async* {
    yield List.unmodifiable(_auditLogs);
    yield* _auditLogsController.stream;
  }

  List<AuditLog> getAuditLogs() => List.unmodifiable(_auditLogs);

  Future<void> logAction({required String userNom, required String userRole, required String action, required String description, String? targetId, String? targetType, AuditSeverity severity = AuditSeverity.info}) async {
    final log = AuditLog(id: 'log_${DateTime.now().millisecondsSinceEpoch}', userNom: userNom, userRole: userRole, action: action, description: description, timestamp: DateTime.now(), targetId: targetId, targetType: targetType, severity: severity);
    _auditLogs.insert(0, log);
    _auditLogsController.add(List.unmodifiable(_auditLogs));
    try { await _syncDocToLocalApi('audit_logs', log.id, log.toMap()); } catch (e) { debugPrint('[Malintic] Erreur sync audit: $e'); }
  }

  void _initInitialData() {
    // Never reseed demo records in production after a browser refresh. Tests
    // run from a file URI and use these deterministic fixtures.
    final isTestRuntime = Uri.base.scheme == 'file';
    if (!isTestRuntime &&
        !const bool.fromEnvironment('ENABLE_DEMO_DATA', defaultValue: false)) {
      return;
    }
    // 1. Initial Users (Demo Students and Formateur)
    _users.clear();
    _users.addAll([
      User(
        id: 'etudiant_1',
        prenom: 'Seydou',
        nom: 'Coulibaly',
        email: 'seydou.coulibaly@malintic.ml',
        password: '00000000',
        phone: '+223 76 12 34 56',
        role: UserRole.apprenant,
        assignedFormations: [
          {
            'formationId': 'form_1',
            'title': 'Développement Mobile Flutter',
            'modules': [
              {'title': 'Bases de Dart', 'assignedHours': 10, 'doneHours': 10},
              {
                'title': 'Widgets et UI Material 3',
                'assignedHours': 10,
                'doneHours': 8,
              },
              {'title': 'Gestion d\'état', 'assignedHours': 10, 'doneHours': 4},
              {
                'title': 'Intégration API REST',
                'assignedHours': 10,
                'doneHours': 0,
              },
            ],
          },
        ],
      ),
      User(
        id: 'etudiant_2',
        prenom: 'Fatoumata',
        nom: 'Sidibé',
        email: 'fatoumata.sidibe@malintic.ml',
        password: '00000000',
        phone: '+223 65 43 21 09',
        role: UserRole.apprenant,
        assignedFormations: [
          {
            'formationId': 'form_sfp_2026',
            'title': 'Stage de Formation Professionnelle - SFP5',
            'modules': [
              {
                'title': 'Base de données + IA',
                'assignedHours': 10,
                'doneHours': 6,
              },
              {'title': 'Word et Excel', 'assignedHours': 10, 'doneHours': 10},
              {
                'title': 'Community Management',
                'assignedHours': 10,
                'doneHours': 2,
              },
            ],
          },
        ],
      ),
      User(
        id: 'etudiant_3',
        prenom: 'Ibrahim',
        nom: 'Maïga',
        email: 'ibrahim.maiga@malintic.ml',
        password: '00000000',
        phone: '+223 70 99 88 77',
        role: UserRole.apprenant,
        assignedFormations: [
          {
            'formationId': 'form_2',
            'title': 'Développement Web Fullstack React & Node.js',
            'modules': [
              {
                'title': 'HTML5/CSS3/JavaScript ES6',
                'assignedHours': 15,
                'doneHours': 15,
              },
              {
                'title': 'React.js Fundamentals',
                'assignedHours': 15,
                'doneHours': 10,
              },
            ],
          },
        ],
      ),
      User(
        id: 'etudiant_4',
        prenom: 'Mariam',
        nom: 'Diallo',
        email: 'mariam.diallo@malintic.ml',
        password: '00000000',
        phone: '+223 66 11 22 33',
        role: UserRole.apprenant,
        assignedFormations: [],
      ),
      User(
        id: 'formateur_1',
        prenom: 'Dr. Ousmane',
        nom: 'Diarra',
        email: 'ousmane.diarra@malintic.ml',
        phone: '+223 76 00 11 22',
        role: UserRole.formateur,
      ),
    ]);

    // 2. Initial Formations
    _formations.addAll([
      Formation(
        id: 'form_1',
        titre: 'Développement Mobile Flutter',
        description:
            'Apprenez à créer des applications iOS et Android performantes et réactives avec Flutter et Dart.',
        modules: [
          'Bases de Dart',
          'Widgets et UI Material 3',
          'Gestion d\'état',
          'Intégration API REST',
        ],
        formateurIds: ['formateur_1'],
        prix: 150000,
        prixEnLigne: 120000,
        type: FormationType.mixte,
        status: FormationStatus.enCours,
        dureeSemaines: 8,
        dureeHeures: '40h',
        horaires: [
          Horaire(jour: 'Samedi', heureDebut: '09:00', heureFin: '13:00'),
        ],
        dateDebut: DateTime.now().subtract(const Duration(days: 5)),
        dateFin: DateTime.now().add(const Duration(days: 50)),
        dateCreation: DateTime.now().subtract(const Duration(days: 15)),
        capaciteMax: 20,
        nombreInscrits: 1,
      ),
      Formation(
        id: 'form_2',
        titre: 'Développement Web Fullstack React & Node.js',
        description:
            'Formation complète pour concevoir des applications web modernes et évolutives.',
        modules: [
          'HTML5/CSS3/JavaScript ES6',
          'React.js Fundamentals',
          'Node.js & Express',
          'MongoDB',
        ],
        formateurIds: ['formateur_1'],
        prix: 180000,
        prixEnLigne: 140000,
        type: FormationType.enligne,
        status: FormationStatus.programmee,
        dureeSemaines: 10,
        dureeHeures: '60h',
        horaires: [
          Horaire(
            jour: 'Lundi & Mercredi',
            heureDebut: '18:00',
            heureFin: '20:30',
          ),
        ],
        dateDebut: DateTime.now().add(const Duration(days: 10)),
        dateFin: DateTime.now().add(const Duration(days: 80)),
        dateCreation: DateTime.now().subtract(const Duration(days: 10)),
        capaciteMax: 25,
        nombreInscrits: 0,
      ),
      Formation(
        id: 'form_sfp_2026',
        titre: 'Stage de Formation Professionnelle - SFP5',
        description:
            'Stage professionnel de 3 mois. Choisissez 3 modules parmi les 19 proposés et bénéficiez des bonus offerts : initiation en informatique, PowerPoint + IA et mémoire de fin d’étude universitaire ou professionnel.',
        modules: [
          'Base de données + IA',
          'Initiation à Windows Server',
          'Initiation au Réseau Téléphonique VoIP',
          'Initiation à la Sécurité Informatique',
          'Maintenance Informatique',
          'Système de Vidéosurveillance Analogique',
          'Initiation au Réseau Informatique',
          'Initiation au Système de Panneau Solaire (SPS)',
          'Adobe Photoshop',
          'Adobe Première Pro',
          'CapCut / VN + IA (Vidéos)',
          'Canva + IA (Affiches)',
          'Sage 100 comptabilité Générale',
          'IMITECH (Initiation en entrepreneuriat : Business Model Canvas)',
          'Word et Excel',
          'Community Management',
          'Intelligence Artificielle (IA)',
          'Internet des Objets (IOT)',
          'Création d’applications (Flutter)',
        ],
        modulesBonus: [
          'Initiation en informatique (Matériels, Logiciels)',
          'PowerPoint + IA',
          'Mémoire de fin d’étude Universitaire ou Professionnel',
        ],
        modulePrices: {
          'Base de données + IA': 33000,
          'Initiation à Windows Server': 28000,
          'Initiation au Réseau Téléphonique VoIP': 26000,
          'Initiation à la Sécurité Informatique': 30000,
          'Maintenance Informatique': 29000,
          'Système de Vidéosurveillance Analogique': 27000,
          'Initiation au Réseau Informatique': 28000,
          'Initiation au Système de Panneau Solaire (SPS)': 28000,
          'Adobe Photoshop': 22000,
          'Adobe Première Pro': 22000,
          'CapCut / VN + IA (Vidéos)': 22000,
          'Canva + IA (Affiches)': 20000,
          'Sage 100 comptabilité Générale': 28000,
          'IMITECH (Initiation en entrepreneuriat : Business Model Canvas)':
              25000,
          'Word et Excel': 20000,
          'Community Management': 23000,
          'Intelligence Artificielle (IA)': 32000,
          'Internet des Objets (IOT)': 28000,
          'Création d’applications (Flutter)': 33000,
        },
        formateurIds: ['formateur_1'],
        prix: 100000,
        prixEnLigne: 125000,
        type: FormationType.mixte,
        status: FormationStatus.programmee,
        dureeSemaines: 12,
        dureeHeures: '3 mois • 3 séances par semaine • 3h par séance',
        horaires: [
          Horaire(
            jour: 'À définir',
            heureDebut: 'À définir',
            heureFin: '3h par séance',
          ),
        ],
        dateDebut: DateTime(2026, 6, 27),
        dateFin: DateTime(2026, 9, 27),
        dateCreation: DateTime.now(),
        capaciteMax: 30,
        nombreInscrits: 0,
        estStage: true,
        maxModulesParEtudiant: 3,
      ),
    ]);

    // 3. Initial Inscriptions & Payments
    _inscriptions.addAll([
      Inscription(
        id: 'insc_1',
        etudiantId: 'etudiant_1',
        formationId: 'form_1',
        status: InscriptionStatus.acceptee,
        dateInscription: DateTime.now().subtract(const Duration(days: 4)),
        paiementId: 'pay_1',
        paiementEffectue: true,
        dateAcceptation: DateTime.now()
            .subtract(const Duration(days: 3))
            .toIso8601String(),
        prenom: 'Seydou',
        nom: 'Coulibaly',
        email: 'seydou.coulibaly@malintic.ml',
        telephone: '+223 76 12 34 56',
        typeFormation: 'Présentielle',
      ),
      Inscription(
        id: 'insc_2',
        etudiantId: 'etudiant_2',
        formationId: 'form_sfp_2026',
        status: InscriptionStatus.acceptee,
        dateInscription: DateTime.now().subtract(const Duration(days: 2)),
        paiementId: 'pay_2',
        paiementEffectue: true,
        dateAcceptation: DateTime.now()
            .subtract(const Duration(days: 1))
            .toIso8601String(),
        prenom: 'Fatoumata',
        nom: 'Sidibé',
        email: 'fatoumata.sidibe@malintic.ml',
        telephone: '+223 65 43 21 09',
        typeFormation: 'Mixte',
        modules: [
          'Base de données + IA',
          'Word et Excel',
          'Community Management',
        ],
      ),
      Inscription(
        id: 'insc_3',
        etudiantId: 'etudiant_3',
        formationId: 'form_2',
        status: InscriptionStatus.acceptee,
        dateInscription: DateTime.now().subtract(const Duration(days: 6)),
        paiementId: 'pay_3',
        paiementEffectue: true,
        dateAcceptation: DateTime.now()
            .subtract(const Duration(days: 5))
            .toIso8601String(),
        prenom: 'Ibrahim',
        nom: 'Maïga',
        email: 'ibrahim.maiga@malintic.ml',
        telephone: '+223 70 99 88 77',
        typeFormation: 'En Ligne',
      ),
      Inscription(
        id: 'insc_4',
        etudiantId: 'etudiant_4',
        formationId: 'form_sfp_2026',
        status: InscriptionStatus.enAttente,
        dateInscription: DateTime.now().subtract(const Duration(hours: 4)),
        paiementEffectue: false,
        prenom: 'Mariam',
        nom: 'Diallo',
        email: 'mariam.diallo@malintic.ml',
        telephone: '+223 66 11 22 33',
        typeFormation: 'Mixte',
        modules: ['Adobe Photoshop', 'Canva + IA (Affiches)', 'Word et Excel'],
      ),
    ]);

    _payments.addAll([
      Payment(
        id: 'pay_1',
        inscriptionId: 'insc_1',
        etudiantId: 'etudiant_1',
        formationId: 'form_1',
        montant: 150000,
        status: PaymentStatus.effectue,
        methode: PaymentMethod.orangeMoney,
        dateCreation: DateTime.now().subtract(const Duration(days: 4)),
        dateEffectuation: DateTime.now().subtract(const Duration(days: 4)),
        referenceTransaction: 'OM-2026-88492',
      ),
      Payment(
        id: 'pay_2',
        inscriptionId: 'insc_2',
        etudiantId: 'etudiant_2',
        formationId: 'form_sfp_2026',
        montant: 75000,
        status: PaymentStatus.effectue,
        methode: PaymentMethod.moovMoney,
        dateCreation: DateTime.now().subtract(const Duration(days: 2)),
        dateEffectuation: DateTime.now().subtract(const Duration(days: 2)),
        referenceTransaction: 'MM-2026-11930',
      ),
      Payment(
        id: 'pay_3',
        inscriptionId: 'insc_3',
        etudiantId: 'etudiant_3',
        formationId: 'form_2',
        montant: 180000,
        status: PaymentStatus.effectue,
        methode: PaymentMethod.virement,
        dateCreation: DateTime.now().subtract(const Duration(days: 6)),
        dateEffectuation: DateTime.now().subtract(const Duration(days: 6)),
        referenceTransaction: 'VIR-2026-00128',
      ),
    ]);

    // 4. Initial Notifications
    _notifications.add(
      AppNotification(
        id: 'notif_1',
        title: 'Bienvenue sur M@LI-NTIC',
        description:
            'Découvrez vos cours et suivez vos inscriptions facilement.',
        senderId: 'admin_malintic',
        senderEmail: 'admin@malintic.ml',
        targetRoles: ['apprenant', 'formateur', 'admin'],
        targetUserIds: [],
        audience: ['all'],
        readBy: [],
        reminderCount: 0,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        updatedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    );
  }

  // --- USERS ---
  Stream<List<User>> watchUsers() async* {
    yield List.unmodifiable(_users);
    yield* _usersController.stream;
  }

  Stream<List<User>> watchEmployees() async* {
    yield List.unmodifiable(
      _users.where((u) => u.role != UserRole.apprenant).toList(),
    );
    yield* _usersController.stream.map(
      (users) => List.unmodifiable(
        users.where((u) => u.role != UserRole.apprenant).toList(),
      ),
    );
  }

  List<User> getUsers() => List.unmodifiable(_users);

  List<User> getEmployees() => List.unmodifiable(
    _users.where((u) => u.role != UserRole.apprenant).toList(),
  );

  User? getUserById(String id) {
    try {
      return _users.firstWhere((u) => u.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<User> addUser(User user) async {
    _unrecordDeletedDoc('users', user.id);
    final isNew = !_users.any((u) => u.id == user.id);
    _users.removeWhere((u) => u.id == user.id);
    _users.add(user);
    _usersController.add(List.unmodifiable(_users));
    _saveUsersToStorage();
    await _syncDocToLocalApi(
      'users',
      user.id,
      // #1 — toMapWithPassword() uniquement pour la transmission API (création de compte).
      // La valeur password est vide après fromMap(), donc seul l'admin en création
      // transmet un mot de passe. Il sera haché immédiatement côté serveur.
      user.password.isNotEmpty ? user.toMapWithPassword() : user.toMap(),
    );
    if (isNew) {
      logAction(
        userNom: '${user.prenom} ${user.nom}'.trim().isNotEmpty ? '${user.prenom} ${user.nom}'.trim() : 'Utilisateur',
        userRole: user.role.name,
        action: 'Création compte',
        description: 'Compte ${user.role.name} créé (${user.email})',
      );
    }
    return user;
  }

  Future<void> setUserActive(String userId, bool isActive) async {
    final index = _users.indexWhere((u) => u.id == userId);
    if (index != -1) {
      final old = _users[index];
      final updatedUser = User(
        id: old.id,
        email: old.email,
        nom: old.nom,
        prenom: old.prenom,
        phone: old.phone,
        matricule: old.matricule,
        role: old.role,
        password: old.password,
        photoUrl: old.photoUrl,
        assignedFormations: old.assignedFormations,
        estActif: isActive,
        dateCreation: old.dateCreation,
        dateModification: DateTime.now(),
      );
      _users[index] = updatedUser;
      _usersController.add(List.unmodifiable(_users));
      _saveUsersToStorage();
      await _syncDocToLocalApi('users', updatedUser.id, updatedUser.toMap());
      logAction(
        userNom: 'Administration',
        userRole: 'admin',
        action: isActive ? 'Déblocage utilisateur' : 'Blocage utilisateur',
        description: '${old.prenom} ${old.nom} (${old.email}) - Statut: ${isActive ? "Actif" : "Bloqué"}',
      );
    }
  }

  Future<void> deleteUser(String userId) async {
    final old = getUserById(userId);
    final oldEmail = old?.email.trim().toLowerCase() ?? '';
    _recordDeletedDoc('users', userId);
    if (oldEmail.isNotEmpty) {
      _recordDeletedDoc('user_emails', oldEmail);
    }
    _users.removeWhere((u) => u.id == userId || (oldEmail.isNotEmpty && u.email.trim().toLowerCase() == oldEmail));
    _saveUsersToStorage();
    _usersController.add(List.unmodifiable(_users));
    try {
      _localStorage.removeItem('user_pw_$userId');
      _localStorage.removeItem('user_pw_changed_$userId');
    } catch (_) {}
    try {
      await _deleteRemoteDoc('users', userId);
    } catch (_) {}

    // Cascade deletion of all inscriptions linked to this user
    final linkedInscriptions = _inscriptions.where((i) =>
        i.etudiantId == userId ||
        i.id == userId ||
        (oldEmail.isNotEmpty && (i.email?.trim().toLowerCase() == oldEmail))
    ).toList();
    for (final ins in linkedInscriptions) {
      await deleteInscription(ins.id);
    }

    logAction(
      userNom: 'Administration',
      userRole: 'admin',
      action: 'Suppression utilisateur',
      description: old != null ? '${old.prenom} ${old.nom} (${old.email} - ${old.role.name})' : 'ID: $userId',
    );
  }

  String _generateMatricule() {
    final now = DateTime.now();
    final stamp = now.millisecondsSinceEpoch.toString();
    final suffix = stamp.substring(stamp.length - 6);
    return 'MAT${now.year % 100}$suffix';
  }

  /// Repairs older validated applications created before matricule assignment
  /// was added. The generated value is persisted to the shared local API, so
  /// every staff account receives the same identifier.
  Future<int> assignMissingMatriculesToValidatedStudents() async {
    if (_repairingMatricules) return 0;
    _repairingMatricules = true;
    try {
      final accepted = _inscriptions
          .where((item) => item.status == InscriptionStatus.acceptee)
          .toList();
      var repaired = 0;
      for (final student in List<User>.from(_users)) {
        if (!student.isEtudiant || student.matricule?.trim().isNotEmpty == true) {
          continue;
        }
        final isValidated = accepted.any(
          (inscription) =>
              inscription.etudiantId == student.id ||
              (inscription.email?.trim().isNotEmpty == true &&
                  inscription.email!.trim().toLowerCase() ==
                      student.email.trim().toLowerCase()),
        );
        if (!isValidated) continue;
        await addUser(
          User(
            id: student.id,
            email: student.email,
            nom: student.nom,
            prenom: student.prenom,
            phone: student.phone,
            matricule: _generateMatricule(),
            role: student.role,
            password: student.password,
            photoUrl: student.photoUrl,
            assignedFormations: student.assignedFormations,
            estActif: student.estActif,
            dateCreation: student.dateCreation,
            dateModification: DateTime.now(),
          ),
        );
        repaired++;
      }
      return repaired;
    } finally {
      _repairingMatricules = false;
    }
  }

  // --- FORMATIONS ---
  Stream<List<Formation>> watchFormations() async* {
    yield List.unmodifiable(_formations);
    yield* _formationsController.stream;
  }

  List<Formation> getFormations() => List.unmodifiable(_formations);

  /// Returns only the formations a trainer is responsible for. Both module-level
  /// and formation-level assignments are fully supported across all formation types.
  List<Formation> getFormationsForFormateur(String formateurId) => _formations
      .where(
        (formation) {
          final hasExplicitModule = formation.modules.any(
            (module) => formation.moduleFormateurIds[module] == formateurId,
          );
          final isExplicitNonModularTrainer =
              formation.modules.isEmpty && formation.formateurIds.contains(formateurId);
          return hasExplicitModule || isExplicitNonModularTrainer;
        },
      )
      .toList();

  /// Returns a reactive stream of formations assigned to a specific formateur
  Stream<List<Formation>> watchFormationsForFormateur(String formateurId) async* {
    yield getFormationsForFormateur(formateurId);
    yield* _formationsController.stream.map((_) => getFormationsForFormateur(formateurId));
  }

  /// Returns all learners strictly enrolled in any module taught by this trainer.
  List<User> getStudentsForFormateur(String formateurId) {
    final formations = getFormationsForFormateur(formateurId);
    final modulesParFormation = {
      for (final formation in formations)
        formation.id: getModulesForFormateur(formation, formateurId).toSet(),
    };

    final deletedUserIds = getDeletedDocs('users');
    final deletedUserEmails = getDeletedDocs('user_emails');

    return _users.where((user) {
      if (user.role != UserRole.apprenant) return false;
      final email = user.email.trim().toLowerCase();
      if (deletedUserIds.contains(user.id)) return false;
      if (email.isNotEmpty && deletedUserEmails.contains(email)) return false;
      return user.assignedFormations.any((assignment) {
        final formationId = assignment['formationId']?.toString() ?? '';
        final trainerModules = modulesParFormation[formationId];
        if (trainerModules == null || trainerModules.isEmpty) return false;

        final rawModules = assignment['modules'] as List<dynamic>? ?? [];
        if (rawModules.isEmpty) {
          return true;
        }
        final studentModules = rawModules.map((item) {
          if (item is Map) return item['title']?.toString() ?? '';
          return item.toString();
        }).toSet();

        return studentModules.any(trainerModules.contains);
      });
    }).toList();
  }

  /// Returns a stream of learners enrolled only in modules assigned to this formateur.
  Stream<List<User>> watchStudentsForFormateur(String formateurId) async* {
    yield getStudentsForFormateur(formateurId);
    yield* _usersController.stream.map((_) => getStudentsForFormateur(formateurId));
  }

  /// Returns exactly the modules assigned to a trainer within one formation.
  /// If the formation has no sub-modules but is assigned to the trainer, returns [formation.titre].
  List<String> getModulesForFormateur(Formation formation, String formateurId) {
    if (formation.modules.isNotEmpty) {
      return formation.modules
          .where(
            (module) => formation.moduleFormateurIds[module] == formateurId,
          )
          .toList();
    }
    if (formation.formateurIds.contains(formateurId)) {
      return [formation.titre];
    }
    return const [];
  }

  /// Replaces a trainer's module and formation responsibilities across the catalogue.
  /// Both standard formations and SFP modular stages are properly persisted.
  Future<void> replaceFormateurAssignments(
    String formateurId,
    Map<String, List<String>> modulesByFormationId,
  ) async {
    final formateur = getUserById(formateurId);
    if (formateur == null || formateur.role != UserRole.formateur) {
      throw StateError('Le profil sélectionné n’est pas un formateur.');
    }

    for (final formation in List<Formation>.from(_formations)) {
      final selectedModules =
          (modulesByFormationId[formation.id] ?? const <String>[]).toSet();

      final assignments = Map<String, String>.from(formation.moduleFormateurIds)
        ..removeWhere((_, assignedId) => assignedId == formateurId);

      for (final module in selectedModules) {
        if (formation.modules.contains(module)) {
          assignments[module] = formateurId;
        }
      }

      final trainerIds = Set<String>.from(formation.formateurIds)
        ..remove(formateurId);

      if (formation.modules.isNotEmpty) {
        if (selectedModules.any((m) => formation.modules.contains(m))) {
          trainerIds.add(formateurId);
        }
      } else {
        if (selectedModules.isNotEmpty) {
          trainerIds.add(formateurId);
        }
      }

      await updateFormation(
        Formation(
          id: formation.id,
          titre: formation.titre,
          description: formation.description,
          modules: formation.modules,
          modulePrices: formation.modulePrices,
          moduleFormateurIds: assignments,
          modulesBonus: formation.modulesBonus,
          imageUrl: formation.imageUrl,
          imageFormat: formation.imageFormat,
          formateurIds: trainerIds.toList(),
          prix: formation.prix,
          prixEnLigne: formation.prixEnLigne,
          type: formation.type,
          status: formation.status,
          dureeSemaines: formation.dureeSemaines,
          dureeHeures: formation.dureeHeures,
          horaires: formation.horaires,
          dateDebut: formation.dateDebut,
          dateFin: formation.dateFin,
          dateCreation: formation.dateCreation,
          capaciteMax: formation.capaciteMax,
          nombreInscrits: formation.nombreInscrits,
          estStage: formation.estStage,
          maxModulesParEtudiant: formation.maxModulesParEtudiant,
        ),
      );
    }

    // Rebuild all trainer summaries so every assigned formation & module is synchronized.
    await _syncAllFormateurAssignments();

    await addNotification(
      AppNotification(
        id: 'notif_form_${DateTime.now().microsecondsSinceEpoch}',
        title: 'Attribution de formations',
        description: 'Vos cours et modules assignés ont été mis à jour dans le catalogue.',
        senderId: 'admin_malintic',
        senderEmail: 'admin@malintic.ml',
        targetRoles: ['formateur'],
        targetUserIds: [formateurId],
        audience: [formateur.email],
        readBy: [],
        reminderCount: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  int _defaultModuleHours(Formation formation) {
    final match = RegExp(r'\d+').firstMatch(formation.dureeHeures ?? '');
    final totalHours = int.tryParse(match?.group(0) ?? '') ??
        (formation.dureeSemaines > 0 ? formation.dureeSemaines * 10 : 10);
    if (formation.modules.isEmpty) return totalHours.clamp(1, 999);
    return (totalHours / formation.modules.length).ceil().clamp(1, 999);
  }

  Future<void> _syncFormateurAssignedFormations(
    String formateurId,
    Map<String, List<String>> modulesByFormationId,
  ) async {
    final formateur = getUserById(formateurId);
    if (formateur == null || formateur.role != UserRole.formateur) return;

    final assignments = formateur.assignedFormations
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final activeFormationIds = modulesByFormationId.entries
        .where((entry) => entry.value.isNotEmpty)
        .map((entry) => entry.key)
        .toSet();

    assignments.removeWhere(
      (item) => !activeFormationIds.contains(item['formationId']),
    );

    for (final formationId in activeFormationIds) {
      final formation = getFormationById(formationId);
      if (formation == null) continue;

      final selectedModules = modulesByFormationId[formationId] ?? const <String>[];
      if (selectedModules.isEmpty) continue;

      final hoursPerModule = _defaultModuleHours(formation);
      final assignmentIndex = assignments.indexWhere(
        (item) => item['formationId'] == formationId,
      );
      final previousModules = assignmentIndex == -1
          ? <Map<String, dynamic>>[]
          : (assignments[assignmentIndex]['modules'] as List<dynamic>? ?? [])
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();

      final assignedModules = selectedModules.map((module) {
        final previous = previousModules
            .where((item) => item['title'] == module)
            .cast<Map<String, dynamic>?>()
            .firstOrNull;
        return <String, dynamic>{
          'title': module,
          'assignedHours': previous?['assignedHours'] ?? hoursPerModule,
          'doneHours': previous?['doneHours'] ?? 0,
        };
      }).toList();

      final assignment = <String, dynamic>{
        'formationId': formationId,
        'title': formation.titre,
        'modules': assignedModules,
        'dateAssigned': assignmentIndex == -1
            ? DateTime.now().toIso8601String()
            : assignments[assignmentIndex]['dateAssigned'],
      };

      if (assignmentIndex == -1) {
        assignments.add(assignment);
      } else {
        assignments[assignmentIndex] = assignment;
      }
    }

    await addUser(
      User(
        id: formateur.id,
        email: formateur.email,
        nom: formateur.nom,
        prenom: formateur.prenom,
        phone: formateur.phone,
        matricule: formateur.matricule,
        role: formateur.role,
        password: formateur.password,
        photoUrl: formateur.photoUrl,
        assignedFormations: assignments,
        sexe: formateur.sexe,
        estActif: formateur.estActif,
        dateCreation: formateur.dateCreation,
        dateModification: DateTime.now(),
      ),
    );
  }

  Future<void> _syncAllFormateurAssignments() async {
    final modulesByTrainer = <String, Map<String, List<String>>>{};

    for (final formation in _formations) {
      if (formation.modules.isNotEmpty) {
        // 1. Process explicit module-level assignments for formations with modules
        for (final entry in formation.moduleFormateurIds.entries) {
          if (!formation.modules.contains(entry.key)) continue;
          modulesByTrainer
              .putIfAbsent(entry.value, () => <String, List<String>>{})
              .putIfAbsent(formation.id, () => <String>[])
              .add(entry.key);
        }
      } else {
        // 2. Process formation-level assignments for formations without sub-modules
        for (final trainerId in formation.formateurIds) {
          modulesByTrainer
              .putIfAbsent(trainerId, () => <String, List<String>>{})
              .putIfAbsent(formation.id, () => <String>[])
              .add(formation.titre);
        }
      }
    }

    for (final formateur
        in _users.where((user) => user.role == UserRole.formateur).toList()) {
      await _syncFormateurAssignedFormations(
        formateur.id,
        modulesByTrainer[formateur.id] ?? const <String, List<String>>{},
      );
    }
  }

  Future<void> addFormation(Formation formation) async {
    final id = formation.id.isEmpty
        ? 'form_${DateTime.now().millisecondsSinceEpoch}'
        : formation.id;
    final syncedFormation = Formation(
      id: id,
      titre: formation.titre,
      description: formation.description,
      modules: formation.modules,
      modulePrices: formation.modulePrices,
      moduleFormateurIds: formation.moduleFormateurIds,
      modulesBonus: formation.modulesBonus,
      imageUrl: formation.imageUrl,
      imageFormat: formation.imageFormat,
      formateurIds: formation.formateurIds,
      prix: formation.prix,
      prixEnLigne: formation.prixEnLigne,
      type: formation.type,
      status: formation.status,
      dureeSemaines: formation.dureeSemaines,
      dureeHeures: formation.dureeHeures,
      horaires: formation.horaires,
      dateDebut: formation.dateDebut,
      dateFin: formation.dateFin,
      dateCreation: formation.dateCreation,
      capaciteMax: formation.capaciteMax,
      nombreInscrits: formation.nombreInscrits,
      estStage: formation.estStage,
      maxModulesParEtudiant: formation.maxModulesParEtudiant,
    );

    _formations.removeWhere((f) => f.id == syncedFormation.id);
    _formations.add(syncedFormation);
    _formationsController.add(List.unmodifiable(_formations));
    _saveFormationsToStorage();
    await _syncDocToLocalApi(
      'formations',
      syncedFormation.id,
      syncedFormation.toMap(),
    );
    logAction(
      userNom: 'Administration',
      userRole: 'admin',
      action: 'Création formation',
      description: 'Nouvelle formation: "${syncedFormation.titre}" (${syncedFormation.modules.length} modules, ${syncedFormation.prix.toStringAsFixed(0)} FCFA)',
    );
  }

  Future<void> updateFormation(Formation formation) async {
    final index = _formations.indexWhere((f) => f.id == formation.id);
    if (index != -1) {
      _formations[index] = formation;
    } else {
      _formations.add(formation);
    }
    _formationsController.add(List.unmodifiable(_formations));
    _saveFormationsToStorage();
    await _syncDocToLocalApi('formations', formation.id, formation.toMap());
    logAction(
      userNom: 'Administration',
      userRole: 'admin',
      action: 'Modification formation',
      description: 'Mise à jour: "${formation.titre}"',
    );
  }

  Future<void> deleteFormation(String id) async {
    final old = getFormationById(id);
    _formations.removeWhere((f) => f.id == id);
    _formationsController.add(List.unmodifiable(_formations));
    _saveFormationsToStorage();
    try {
      await _deleteRemoteDoc('formations', id);
    } catch (_) {}
    logAction(
      userNom: 'Administration',
      userRole: 'admin',
      action: 'Suppression formation',
      description: old != null ? 'Suppression de "${old.titre}"' : 'ID: $id',
    );
  }

  /// Returns all learners enrolled in a specific module of a formation.
  /// If [moduleTitle] is null or empty, returns all learners enrolled in the formation.
  List<User> getStudentsForFormationModule(String formationId, String? moduleTitle) {
    return _users.where((user) {
      if (user.role != UserRole.apprenant) return false;
      return user.assignedFormations.any((assignment) {
        if (assignment['formationId'] != formationId) return false;
        if (moduleTitle == null ||
            moduleTitle.isEmpty ||
            moduleTitle == 'Tous les modules' ||
            moduleTitle == 'Tous') {
          return true;
        }
        final rawModules = assignment['modules'] as List<dynamic>? ?? [];
        if (rawModules.isEmpty) {
          // If no specific modules are specified on student assignment, he is in all modules
          return true;
        }
        final selected = rawModules.map((item) {
          if (item is Map) return item['title']?.toString() ?? '';
          return item.toString();
        }).toSet();
        return selected.contains(moduleTitle);
      });
    }).toList();
  }

  /// Adds a slot to a formation and persists the change
  Future<void> addHoraireToFormation(String formationId, Horaire horaire) async {
    final formation = getFormationById(formationId);
    if (formation == null) return;
    final horaires = [...formation.horaires, horaire];
    await updateFormation(formation.copyWith(horaires: horaires));
  }

  /// Updates a slot in a formation at a specific index
  Future<void> updateHoraireInFormation(String formationId, int index, Horaire horaire) async {
    final formation = getFormationById(formationId);
    if (formation == null || index < 0 || index >= formation.horaires.length) return;
    final horaires = List<Horaire>.from(formation.horaires);
    horaires[index] = horaire;
    await updateFormation(formation.copyWith(horaires: horaires));
  }

  /// Removes a slot from a formation at a specific index
  Future<void> deleteHoraireFromFormation(String formationId, int index) async {
    final formation = getFormationById(formationId);
    if (formation == null || index < 0 || index >= formation.horaires.length) return;
    final horaires = List<Horaire>.from(formation.horaires)..removeAt(index);
    await updateFormation(formation.copyWith(horaires: horaires));
  }

  /// Duplicates a slot to another day
  Future<void> duplicateHoraireInFormation(String formationId, int index, String targetDay) async {
    final formation = getFormationById(formationId);
    if (formation == null || index < 0 || index >= formation.horaires.length) return;
    final source = formation.horaires[index];
    final duplicated = Horaire(
      jour: targetDay,
      heureDebut: source.heureDebut,
      heureFin: source.heureFin,
      module: source.module,
      groupe: source.groupe,
      modalite: source.modalite,
      lieuOuLien: source.lieuOuLien,
    );
    final horaires = [...formation.horaires, duplicated];
    await updateFormation(formation.copyWith(horaires: horaires));
  }

  /// Checks whether a slot conflicts with other scheduled sessions (same room or same trainer)
  List<String> checkPlanningConflicts({
    required String day,
    required String start,
    required String end,
    String? formateurId,
    String? salleOuLien,
    String? currentFormationId,
    int? currentHoraireIndex,
  }) {
    final conflicts = <String>[];
    if (start.isEmpty || end.isEmpty) return conflicts;

    int parseTime(String time) {
      final parts = time.split(':');
      if (parts.isEmpty) return 0;
      final h = int.tryParse(parts[0]) ?? 0;
      final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
      return h * 60 + m;
    }

    final newStart = parseTime(start);
    final newEnd = parseTime(end);
    if (newEnd <= newStart) return conflicts;

    for (final formation in _formations) {
      for (int i = 0; i < formation.horaires.length; i++) {
        if (formation.id == currentFormationId && i == currentHoraireIndex) {
          continue; // Skip self when updating
        }
        final h = formation.horaires[i];
        if (h.jour != day) continue;

        final hStart = parseTime(h.heureDebut);
        final hEnd = parseTime(h.heureFin);

        // Check time overlap: (start < otherEnd) && (end > otherStart)
        final isOverlap = (newStart < hEnd) && (newEnd > hStart);
        if (!isOverlap) continue;

        // Check room conflict
        if (salleOuLien != null &&
            salleOuLien.trim().isNotEmpty &&
            h.lieuOuLien != null &&
            h.lieuOuLien!.trim().isNotEmpty &&
            h.lieuOuLien!.trim().toLowerCase() == salleOuLien.trim().toLowerCase()) {
          conflicts.add('La salle "$salleOuLien" est déjà occupée par "${formation.titre}" ($day ${h.heureDebut}-${h.heureFin}).');
        }

        // Check trainer conflict
        if (formateurId != null && formateurId.isNotEmpty) {
          final slotTrainer = h.module != null
              ? formation.moduleFormateurIds[h.module]
              : (formation.formateurIds.isNotEmpty ? formation.formateurIds.first : null);
          if (slotTrainer == formateurId) {
            final trainerUser = getUserById(formateurId);
            final trainerName = trainerUser?.nomComplet ?? 'Le formateur';
            conflicts.add('$trainerName donne déjà le cours "${h.module ?? formation.titre}" le $day de ${h.heureDebut} à ${h.heureFin}.');
          }
        }
      }
    }
    return conflicts;
  }

  /// Analyzes the entire database schedule and returns all detected conflicts (rooms, trainers)
  List<Map<String, dynamic>> getAllPlanningConflicts() {
    final results = <Map<String, dynamic>>[];
    int parseTime(String time) {
      final parts = time.split(':');
      if (parts.isEmpty) return 0;
      final h = int.tryParse(parts[0]) ?? 0;
      final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
      return h * 60 + m;
    }

    final allSessions = <Map<String, dynamic>>[];
    for (final formation in _formations) {
      for (int i = 0; i < formation.horaires.length; i++) {
        final h = formation.horaires[i];
        final trainerId = h.module != null &&
                formation.moduleFormateurIds.containsKey(h.module)
            ? formation.moduleFormateurIds[h.module]
            : (formation.formateurIds.isNotEmpty
                ? formation.formateurIds.first
                : null);
        final trainerUser = trainerId != null ? getUserById(trainerId) : null;

        allSessions.add({
          'formationId': formation.id,
          'formationTitre': formation.titre,
          'horaireIndex': i,
          'horaire': h,
          'day': h.jour,
          'start': parseTime(h.heureDebut),
          'end': parseTime(h.heureFin),
          'trainerId': trainerId,
          'trainerName': trainerUser?.nomComplet,
          'salle': h.lieuOuLien?.trim().toLowerCase(),
          'salleDisplay': h.lieuOuLien?.trim(),
        });
      }
    }

    // Compare each pair
    for (int i = 0; i < allSessions.length; i++) {
      for (int j = i + 1; j < allSessions.length; j++) {
        final s1 = allSessions[i];
        final s2 = allSessions[j];

        if (s1['day'] != s2['day']) continue;

        // Check time overlap: (start1 < end2) && (end1 > start2)
        final isOverlap =
            (s1['start'] < s2['end']) && (s1['end'] > s2['start']);
        if (!isOverlap) continue;

        // 1. Room conflict (exclude online links)
        final salle1 = s1['salle'] as String?;
        final salle2 = s2['salle'] as String?;
        if (salle1 != null &&
            salle1.isNotEmpty &&
            salle1 == salle2 &&
            !salle1.startsWith('http') &&
            !salle1.contains('meet.google') &&
            !salle1.contains('zoom')) {
          results.add({
            'type': 'salle',
            'day': s1['day'],
            'title': 'Conflit de Salle (${s1['salleDisplay']})',
            'description':
                'La salle "${s1['salleDisplay']}" est assignée simultanément à "${s1['formationTitre']}" (${s1['horaire'].heureDebut}-${s1['horaire'].heureFin}) et "${s2['formationTitre']}" (${s2['horaire'].heureDebut}-${s2['horaire'].heureFin}).',
            'formation1Id': s1['formationId'],
            'formation2Id': s2['formationId'],
            'horaireIndex1': s1['horaireIndex'],
            'horaireIndex2': s2['horaireIndex'],
            'horaire1': s1['horaire'],
            'horaire2': s2['horaire'],
          });
        }

        // 2. Trainer conflict
        final t1 = s1['trainerId'] as String?;
        final t2 = s2['trainerId'] as String?;
        if (t1 != null && t1.isNotEmpty && t1 == t2) {
          final tName = s1['trainerName'] ?? 'Le formateur';
          results.add({
            'type': 'formateur',
            'day': s1['day'],
            'title': 'Conflit de Formateur ($tName)',
            'description':
                '$tName est programmé simultanément sur "${s1['formationTitre']}" (${s1['horaire'].heureDebut}-${s1['horaire'].heureFin}) et "${s2['formationTitre']}" (${s2['horaire'].heureDebut}-${s2['horaire'].heureFin}).',
            'formation1Id': s1['formationId'],
            'formation2Id': s2['formationId'],
            'horaireIndex1': s1['horaireIndex'],
            'horaireIndex2': s2['horaireIndex'],
            'horaire1': s1['horaire'],
            'horaire2': s2['horaire'],
          });
        }
      }
    }

    return results;
  }

  // --- INSCRIPTIONS ---
  Stream<List<Inscription>> watchInscriptions() async* {
    yield List.unmodifiable(_inscriptions);
    yield* _inscriptionsController.stream;
  }

  List<Inscription> getInscriptions() => List.unmodifiable(_inscriptions);

  Inscription? getInscriptionById(String id) {
    try {
      return _inscriptions.firstWhere((i) => i.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<Inscription> createInscription({
    String? apprenantId,
    String? etudiantId,
    required String formationId,
    String? prenom,
    String? nom,
    String? email,
    String? telephone,
    String? description,
    List<String>? modules,
    String? typeFormation,
    String? sexe,
  }) async {
    final formation = getFormationById(formationId);
    if (formation == null) {
      throw StateError('Formation introuvable.');
    }
    final selectedModules = (modules ?? const <String>[]).toSet().toList();
    if (selectedModules.any((module) => !formation.modules.contains(module))) {
      throw ArgumentError(
        'Un module sélectionné ne fait pas partie de cette formation.',
      );
    }
    if (formation.estStage) {
      final maxModules = formation.maxModulesParEtudiant ?? 3;
      if (selectedModules.length != maxModules) {
        throw ArgumentError(
          'Le stage SFP exige exactement $maxModules modules.',
        );
      }
    }
    final effectiveApprenantId = (apprenantId ?? etudiantId ?? '');
    final normalizedEmail = email?.trim().toLowerCase() ?? '';
    final existing = _inscriptions.where((item) {
      final sameFormation = item.formationId == formationId;
      final sameEmail =
          normalizedEmail.isNotEmpty &&
          (item.email?.trim().toLowerCase() ?? '') == normalizedEmail;
      final sameStudent =
          effectiveApprenantId.isNotEmpty && item.apprenantId == effectiveApprenantId;
      return sameFormation && (sameEmail || sameStudent);
    }).firstOrNull;
    if (existing != null) {
      // A browser refresh or an API retry must not create a second dossier.
      return existing;
    }

    final inscId = 'insc_${DateTime.now().millisecondsSinceEpoch}';
    final newInsc = Inscription(
      id: inscId,
      apprenantId: effectiveApprenantId,
      formationId: formationId,
      status: InscriptionStatus.enAttente,
      dateInscription: DateTime.now(),
      // An enrolment is administrative only. A payment is created exclusively
      // when the cashier records an actual versement in the Payments module.
      paiementId: null,
      paiementEffectue: false,
      prenom: prenom,
      nom: nom,
      email: email,
      telephone: telephone,
      description: description,
      modules: selectedModules.isNotEmpty ? selectedModules : formation.modules,
      typeFormation: typeFormation,
      sexe: sexe ?? 'Homme',
    );

    _inscriptions.add(newInsc);

    // The user account and assigned modules are created only when an
    // administrator validates this dossier in acceptInscription().

    _inscriptionsController.add(List.unmodifiable(_inscriptions));
    _saveInscriptionsToStorage();
    await _syncDocToLocalApi('inscriptions', newInsc.id, newInsc.toMap());

    final studentName = [prenom, nom].where((s) => s != null && s.isNotEmpty).join(' ');
    await addNotification(
      AppNotification(
        id: 'notif_insc_${DateTime.now().microsecondsSinceEpoch}',
        title: 'Nouvelle Inscription',
        description: '${studentName.isNotEmpty ? studentName : "Un apprenant"} a soumis une inscription pour ${formation.titre}.',
        senderId: 'system',
        senderEmail: 'system@malintic.ml',
        targetRoles: ['admin', 'assistant', 'dg', 'comptable'],
        targetUserIds: [],
        audience: ['admin', 'assistant'],
        readBy: [],
        reminderCount: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    return newInsc;
  }

  Future<Inscription> ensureInscriptionForStudent({
    required User student,
    required Formation formation,
  }) async {
    final existing = _inscriptions
        .where(
          (item) =>
              item.etudiantId == student.id && item.formationId == formation.id,
        )
        .firstOrNull;
    if (existing != null) return existing;

    final inscription = Inscription(
      id: 'insc_${DateTime.now().millisecondsSinceEpoch}',
      etudiantId: student.id,
      formationId: formation.id,
      status: InscriptionStatus.acceptee,
      dateInscription: DateTime.now(),
      paiementEffectue: false,
      prenom: student.prenom,
      nom: student.nom,
      email: student.email,
      telephone: student.phone,
      modules: formation.modules,
      typeFormation: formation.type.toString(),
      dateAcceptation: DateTime.now().toIso8601String(),
    );
    _inscriptions.add(inscription);
    _inscriptionsController.add(List.unmodifiable(_inscriptions));
    _saveInscriptionsToStorage();
    await _syncDocToLocalApi(
      'inscriptions',
      inscription.id,
      inscription.toMap(),
    );
    return inscription;
  }

  Formation? getFormationById(String id) {
    try {
      return _formations.firstWhere((f) => f.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<Formation?> fetchPublicFormationById(String id) async {
    if (id.isEmpty) return null;

    final cached = getFormationById(id);
    if (cached != null) return cached;

    if (!_hasLocalApi) return null;

    Formation? fromApi;
    try {
      final singleResponse = await http
          .get(_apiUri('formations/${Uri.encodeComponent(id)}'))
          .timeout(const Duration(seconds: 8));
      if (singleResponse.statusCode == 200) {
        final map = jsonDecode(singleResponse.body);
        if (map is Map<String, dynamic>) {
          fromApi = Formation.fromMap(map, id);
        }
      }
    } catch (_) {}

    if (fromApi == null) {
      try {
        final listResponse = await http
            .get(_apiUri('formations'))
            .timeout(const Duration(seconds: 8));
        if (listResponse.statusCode == 200) {
          final list = jsonDecode(listResponse.body);
          if (list is List) {
            for (final item in list) {
              if (item is Map && item['id']?.toString() == id) {
                fromApi = Formation.fromMap(
                  Map<String, dynamic>.from(item),
                  id,
                );
                break;
              }
            }
          }
        }
      } catch (_) {}
    }

    if (fromApi == null) return null;

    final index = _formations.indexWhere((f) => f.id == id);
    if (index >= 0) {
      _formations[index] = fromApi;
    } else {
      _formations.add(fromApi);
    }
    _formationsController.add(List.unmodifiable(_formations));
    _saveFormationsToStorage();
    return fromApi;
  }

  Future<void> updateInscriptionStatus(
    String id,
    String statusStr, {
    String? motifRejet,
  }) async {
    if (statusStr == 'valide' || statusStr == 'acceptee') {
      await acceptInscription(id);
      return;
    }

    final index = _inscriptions.indexWhere((i) => i.id == id);
    if (index != -1) {
      final old = _inscriptions[index];
      InscriptionStatus status = InscriptionStatus.enAttente;
      if (statusStr == 'valide' || statusStr == 'acceptee') {
        status = InscriptionStatus.acceptee;
      } else if (statusStr == 'rejete' || statusStr == 'rejetee') {
        status = InscriptionStatus.rejetee;
      }

      final updatedInsc = Inscription(
        id: old.id,
        etudiantId: old.etudiantId,
        formationId: old.formationId,
        status: status,
        dateInscription: old.dateInscription,
        paiementId: old.paiementId,
        paiementEffectue: old.paiementEffectue,
        dateAcceptation: status == InscriptionStatus.acceptee
            ? DateTime.now().toIso8601String()
            : old.dateAcceptation,
        motifRejet: motifRejet ?? old.motifRejet,
        prenom: old.prenom,
        nom: old.nom,
        email: old.email,
        telephone: old.telephone,
        description: old.description,
        modules: old.modules,
        typeFormation: old.typeFormation,
      );
      _inscriptions[index] = updatedInsc;
      _inscriptionsController.add(List.unmodifiable(_inscriptions));
      _saveInscriptionsToStorage();
      await _syncDocToLocalApi(
        'inscriptions',
        updatedInsc.id,
        updatedInsc.toMap(),
      );
    }
  }

  Future<User> acceptInscription(
    String inscriptionId, {
    Map<String, int> moduleHours = const {},
    Formation? formationOverride,
  }) async {
    final inscriptionIndex = _inscriptions.indexWhere(
      (i) => i.id == inscriptionId,
    );
    if (inscriptionIndex == -1) {
      throw StateError('Inscription introuvable: $inscriptionId');
    }

    final inscription = _inscriptions[inscriptionIndex];
    if (inscription.status == InscriptionStatus.acceptee) {
      throw StateError('Cette inscription a déjà été validée.');
    }
    // La liste partagée peut être actualisée pendant que la boîte de dialogue
    // de validation est ouverte. On privilégie donc son instantané de
    // formation et, pour un ancien lien public, on recrée le strict minimum.
    final formation =
        formationOverride ??
        getFormationById(inscription.formationId) ??
        Formation(
          id: inscription.formationId,
          titre: 'Formation ${inscription.formationId}',
          description: inscription.description ?? '',
          modules: inscription.modules ?? const <String>[],
          formateurIds: const [],
          prix: 0,
          type: FormationType.presentielle,
          status: FormationStatus.programmee,
          dureeSemaines: 0,
          horaires: const [],
          dateCreation: DateTime.now(),
          estStage: (inscription.modules?.length ?? 0) == 3,
          maxModulesParEtudiant: (inscription.modules?.length ?? 0) == 3
              ? 3
              : null,
        );

    final email = inscription.email?.trim().toLowerCase() ?? '';
    User? student = getUserById(inscription.etudiantId);
    if (student == null && email.isNotEmpty) {
      for (final user in _users) {
        if (user.email.trim().toLowerCase() == email) {
          student = user;
          break;
        }
      }
    }

    final now = DateTime.now();
    final studentId =
        student?.id ??
        (inscription.etudiantId.isNotEmpty &&
                !inscription.etudiantId.startsWith('web_')
            ? inscription.etudiantId
            : 'etudiant_${now.millisecondsSinceEpoch}');
    final existingAssignments =
        student?.assignedFormations
            .map((item) => Map<String, dynamic>.from(item))
            .toList() ??
        <Map<String, dynamic>>[];
    final assignmentIndex = existingAssignments.indexWhere(
      (item) => item['formationId'] == formation.id,
    );
    final moduleNames =
        (inscription.modules != null && inscription.modules!.isNotEmpty)
        ? inscription.modules!
        : formation.estStage
        ? <String>[]
        : formation.modules;
    if (formation.estStage) {
      final maxModules = formation.maxModulesParEtudiant ?? 3;
      if (moduleNames.length != maxModules) {
        throw StateError(
          'Cette inscription SFP doit contenir exactement $maxModules modules.',
        );
      }
    }
    final assignedModules = moduleNames.map((module) {
      final previous = assignmentIndex == -1
          ? null
          : (existingAssignments[assignmentIndex]['modules']
                        as List<dynamic>? ??
                    [])
                .whereType<Map>()
                .cast<Map<String, dynamic>>()
                .where((item) => item['title'] == module)
                .firstOrNull;
      return <String, dynamic>{
        'title': module,
        'assignedHours': moduleHours[module] ?? previous?['assignedHours'] ?? 1,
        'doneHours': previous?['doneHours'] ?? 0,
      };
    }).toList();
    final requestedMode = inscription.typeFormation?.toLowerCase() ?? '';
    final modeSuivi = requestedMode.contains('ligne')
        ? 'En ligne'
        : requestedMode.contains('present')
        ? 'Présentiel'
        : formation.type == FormationType.enligne
        ? 'En ligne'
        : formation.type == FormationType.mixte
        ? 'Mixte'
        : 'Présentiel';
    final assignment = <String, dynamic>{
      'formationId': formation.id,
      'title': formation.titre,
      'modeSuivi': modeSuivi,
      'modules': assignedModules,
      'dateAssigned': assignmentIndex == -1
          ? now.toIso8601String()
          : existingAssignments[assignmentIndex]['dateAssigned'],
    };
    if (assignmentIndex == -1) {
      existingAssignments.add(assignment);
    } else {
      existingAssignments[assignmentIndex] = assignment;
    }

    final updatedStudent = User(
      id: studentId,
      email: email.isNotEmpty
          ? email
          : (student?.email ?? '$studentId@local.invalid'),
      nom: inscription.nom?.trim().isNotEmpty == true
          ? inscription.nom!.trim()
          : (student?.nom ?? ''),
      prenom: inscription.prenom?.trim().isNotEmpty == true
          ? inscription.prenom!.trim()
          : (student?.prenom ?? ''),
      phone: inscription.telephone?.trim().isNotEmpty == true
          ? inscription.telephone!.trim()
          : (student?.phone ?? ''),
      matricule: student?.matricule?.trim().isNotEmpty == true
          ? student!.matricule
          : _generateMatricule(),
      role: UserRole.apprenant,
      password: student?.password.isNotEmpty == true
          ? student!.password
          : '00000000',
      photoUrl: student?.photoUrl,
      assignedFormations: existingAssignments,
      sexe: inscription.sexe ?? student?.sexe ?? 'Homme',
      estActif: true,
      dateCreation: student?.dateCreation ?? now,
      dateModification: now,
    );
    await addUser(updatedStudent);

    final updatedInscription = Inscription(
      id: inscription.id,
      etudiantId: updatedStudent.id,
      formationId: inscription.formationId,
      status: InscriptionStatus.acceptee,
      dateInscription: inscription.dateInscription,
      paiementId: inscription.paiementId,
      paiementEffectue: inscription.paiementEffectue,
      dateAcceptation: inscription.dateAcceptation ?? now.toIso8601String(),
      motifRejet: null,
      prenom: inscription.prenom,
      nom: inscription.nom,
      email: inscription.email,
      telephone: inscription.telephone,
      description: inscription.description,
      modules: inscription.modules,
      typeFormation: inscription.typeFormation,
      sexe: inscription.sexe,
    );
    final targetIndex = _inscriptions.indexWhere((i) => i.id == inscription.id);
    if (targetIndex >= 0) {
      _inscriptions[targetIndex] = updatedInscription;
    } else {
      _inscriptions.add(updatedInscription);
    }
    _inscriptionsController.add(List.unmodifiable(_inscriptions));
    _saveInscriptionsToStorage();
    await _syncDocToLocalApi(
      'inscriptions',
      updatedInscription.id,
      updatedInscription.toMap(),
    );

    final acceptedCount = _inscriptions
        .where(
          (item) =>
              item.formationId == formation.id &&
              item.status == InscriptionStatus.acceptee,
        )
        .map((item) => item.etudiantId)
        .toSet()
        .length;
    await updateFormation(
      Formation(
        id: formation.id,
        titre: formation.titre,
        description: formation.description,
        modules: formation.modules,
        modulePrices: formation.modulePrices,
        moduleFormateurIds: formation.moduleFormateurIds,
        modulesBonus: formation.modulesBonus,
        imageUrl: formation.imageUrl,
        imageFormat: formation.imageFormat,
        formateurIds: formation.formateurIds,
        prix: formation.prix,
        prixEnLigne: formation.prixEnLigne,
        type: formation.type,
        status: formation.status,
        dureeSemaines: formation.dureeSemaines,
        dureeHeures: formation.dureeHeures,
        horaires: formation.horaires,
        dateDebut: formation.dateDebut,
        dateFin: formation.dateFin,
        dateCreation: formation.dateCreation,
        capaciteMax: formation.capaciteMax,
        nombreInscrits: acceptedCount,
        estStage: formation.estStage,
        maxModulesParEtudiant: formation.maxModulesParEtudiant,
      ),
    );

    final alreadyNotified = _notifications.any(
      (notification) =>
          notification.targetUserIds.contains(updatedStudent.id) &&
          notification.description.contains(formation.titre),
    );
    if (!alreadyNotified) {
      await addNotification(
        AppNotification(
          id: 'notif_${now.microsecondsSinceEpoch}',
          title: 'Inscription validée',
          description: 'Votre inscription à ${formation.titre} a été validée.',
          senderId: 'admin_malintic',
          senderEmail: 'admin@malintic.ml',
          targetRoles: ['apprenant'],
          targetUserIds: [updatedStudent.id],
          audience: ['apprenant'],
          readBy: [],
          reminderCount: 0,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    logAction(
      userNom: 'Administration',
      userRole: 'admin',
      action: 'Validation inscription',
      description: 'Dossier validé pour ${updatedStudent.prenom} ${updatedStudent.nom} - Formation: ${formation.titre}',
    );

    return updatedStudent;
  }

  Future<void> updateInscriptionPaymentStatus(
    String inscriptionId,
    bool paiementEffectue,
  ) async {
    final index = _inscriptions.indexWhere((i) => i.id == inscriptionId);
    if (index == -1) return;

    final old = _inscriptions[index];
    final updated = Inscription(
      id: old.id,
      etudiantId: old.etudiantId,
      formationId: old.formationId,
      status: old.status,
      dateInscription: old.dateInscription,
      paiementId: old.paiementId,
      paiementEffectue: paiementEffectue,
      dateAcceptation: old.dateAcceptation,
      motifRejet: old.motifRejet,
      prenom: old.prenom,
      nom: old.nom,
      email: old.email,
      telephone: old.telephone,
      description: old.description,
      modules: old.modules,
      typeFormation: old.typeFormation,
    );
    _inscriptions[index] = updated;
    _inscriptionsController.add(List.unmodifiable(_inscriptions));
    _saveInscriptionsToStorage();
    await _syncDocToLocalApi('inscriptions', updated.id, updated.toMap());
  }

  Future<void> deleteInscription(String id) async {
    final old = _inscriptions.where((i) => i.id == id).firstOrNull;
    final email = (old?.email ?? '').trim().toLowerCase();
    final etudiantId = old?.etudiantId.trim() ?? '';

    _recordDeletedDoc('inscriptions', id);
    if (etudiantId.isNotEmpty) {
      _recordDeletedDoc('inscriptions', etudiantId);
    }
    if (email.isNotEmpty) {
      _recordDeletedDoc('user_emails', email);
    }

    _inscriptions.removeWhere((i) {
      final insEmail = (i.email ?? '').trim().toLowerCase();
      return i.id == id ||
          (etudiantId.isNotEmpty && i.etudiantId == etudiantId) ||
          (email.isNotEmpty && insEmail == email);
    });
    _inscriptionsController.add(List.unmodifiable(_inscriptions));
    _saveInscriptionsToStorage();
    try {
      await _deleteRemoteDoc('inscriptions', id);
      if (etudiantId.isNotEmpty && etudiantId != id) {
        await _deleteRemoteDoc('inscriptions', etudiantId);
      }
    } catch (_) {}
  }

  // --- PAYMENTS ---
  Stream<List<Payment>> watchPayments() async* {
    yield List.unmodifiable(_payments);
    yield* _paymentsController.stream;
  }

  List<Payment> getPayments() => List.unmodifiable(_payments);

  Future<void> addPayment(Payment payment) async {
    if (payment.montant <= 0) {
      throw ArgumentError.value(
        payment.montant,
        'montant',
        'Le montant doit être supérieur à zéro.',
      );
    }
    if (payment.trancheNumero < 1 ||
        payment.nombreTranches < 1 ||
        payment.trancheNumero > payment.nombreTranches) {
      throw ArgumentError('Numéro de tranche invalide.');
    }

    if (payment.status == PaymentStatus.effectue) {
      final existing = getPaymentsForInscription(payment.inscriptionId);
      if (existing.any(
        (item) =>
            item.status == PaymentStatus.effectue &&
            item.trancheNumero == payment.trancheNumero,
      )) {
        throw StateError('Cette tranche a déjà été enregistrée.');
      }

      final base = getInscriptionBaseTotal(payment.inscriptionId);
      final existingDiscount = getInscriptionDiscountTotal(
        payment.inscriptionId,
      );
      final totalDue =
          (base -
                  (payment.remise > existingDiscount
                      ? payment.remise
                      : existingDiscount))
              .clamp(0, double.infinity)
              .toDouble();
      final proposedPaid =
          getInscriptionPaidAmount(payment.inscriptionId) + payment.montant;
      if (proposedPaid > totalDue) {
        throw StateError(
          'Le versement dépasse le solde restant de ${((totalDue - getInscriptionPaidAmount(payment.inscriptionId)).clamp(0, double.infinity)).toStringAsFixed(0)} FCFA.',
        );
      }
    }
    _payments.add(payment);
    _paymentsController.add(List.unmodifiable(_payments));
    _savePaymentsToStorage();
    await _syncDocToLocalApi('payments', payment.id, payment.toMap());
    await updateInscriptionPaymentStatus(
      payment.inscriptionId,
      getInscriptionPaidAmount(payment.inscriptionId) >=
          getInscriptionTotalDue(payment.inscriptionId),
    );

    final insc = getInscriptionById(payment.inscriptionId);
    final form = insc != null ? getFormationById(insc.formationId) : null;
    final stud = insc != null ? getUserById(insc.etudiantId) : null;
    final studName = stud != null
        ? '${stud.prenom} ${stud.nom}'
        : (insc != null && ((insc.prenom?.isNotEmpty == true) || (insc.nom?.isNotEmpty == true))
            ? '${insc.prenom ?? ""} ${insc.nom ?? ""}'.trim()
            : 'Un étudiant');

    logAction(
      userNom: studName,
      userRole: stud?.role.name ?? 'apprenant',
      action: 'Paiement effectué',
      description: 'Versement de ${payment.montant.toStringAsFixed(0)} FCFA (${payment.methode.name.toUpperCase()}) pour ${form?.titre ?? "Formation"} (Tranche ${payment.trancheNumero}/${payment.nombreTranches})',
    );

    // Notify Admins & Accounting
    await addNotification(
      AppNotification(
        id: 'notif_pay_${DateTime.now().microsecondsSinceEpoch}',
        title: 'Paiement reçu',
        description: 'Versement de ${payment.montant.toStringAsFixed(0)} FCFA reçu de $studName (${form?.titre ?? "Formation"}).',
        senderId: 'system',
        senderEmail: 'comptabilite@malintic.ml',
        targetRoles: ['admin', 'comptable', 'daf', 'dg'],
        targetUserIds: [],
        audience: ['admin', 'comptable'],
        readBy: [],
        reminderCount: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    // Notify Student
    if (stud != null || (insc != null && insc.etudiantId.isNotEmpty)) {
      await addNotification(
        AppNotification(
          id: 'notif_stud_${DateTime.now().microsecondsSinceEpoch}',
          title: 'Confirmation de versement',
          description: 'Votre paiement de ${payment.montant.toStringAsFixed(0)} FCFA pour ${form?.titre ?? "votre formation"} a été validé avec succès.',
          senderId: 'comptabilite',
          senderEmail: 'comptabilite@malintic.ml',
          targetRoles: ['apprenant'],
          targetUserIds: [stud?.id ?? insc!.etudiantId],
          audience: [stud?.email ?? insc?.email ?? ''],
          readBy: [],
          reminderCount: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
    }
  }

  Future<void> deletePayment(String id) async {
    _recordDeletedDoc('payments', id);
    _payments.removeWhere((p) => p.id == id);
    _paymentsController.add(List.unmodifiable(_payments));
    _savePaymentsToStorage();
    try {
      await _deleteRemoteDoc('payments', id);
    } catch (_) {}
  }

  List<Payment> getPaymentsForInscription(String inscriptionId) {
    final targetInsc = getInscriptionById(inscriptionId);
    final deletedPaymentIds = getDeletedDocs('payments');
    return _payments.where((payment) {
      if (deletedPaymentIds.contains(payment.id)) return false;
      if (payment.inscriptionId == inscriptionId) return true;
      if (targetInsc != null &&
          targetInsc.formationId.isNotEmpty &&
          payment.formationId == targetInsc.formationId &&
          ((targetInsc.etudiantId.isNotEmpty && payment.etudiantId == targetInsc.etudiantId) ||
           (targetInsc.apprenantId.isNotEmpty && payment.etudiantId == targetInsc.apprenantId))) {
        return true;
      }
      return false;
    }).toList();
  }

  double getFormationModulesTotal(
    String formationId, {
    List<String>? moduleIds,
    String? typeFormation,
  }) {
    final formation = getFormationById(formationId);
    if (formation == null) return 0;

    final isEnLigne = typeFormation?.toLowerCase().contains('ligne') == true;
    final basePrice = isEnLigne && (formation.prixEnLigne ?? 0) > 0
        ? formation.prixEnLigne!
        : formation.prix;

    // Si une sélection partielle de modules est spécifiée et que des prix individuels existent
    if (moduleIds != null &&
        moduleIds.isNotEmpty &&
        moduleIds.length < formation.modules.length &&
        formation.modulePrices.isNotEmpty) {
      final hasPrices = moduleIds.any(
        (module) => formation.modulePrices.containsKey(module),
      );
      if (hasPrices) {
        final modulesTotal = moduleIds.fold<double>(
          0,
          (total, module) => total + (formation.modulePrices[module] ?? 0),
        );
        if (modulesTotal > 0) return modulesTotal;
      }
    }

    return basePrice;
  }

  double getInscriptionBaseTotal(String inscriptionId) {
    final inscription = getInscriptionById(inscriptionId);
    if (inscription == null) return 0;
    return getFormationModulesTotal(
      inscription.formationId,
      moduleIds: inscription.modules,
      typeFormation: inscription.typeFormation,
    );
  }

  double getInscriptionDiscountTotal(String inscriptionId) {
    // A discount is a decision for an inscription, not one discount per
    // installment. Keep the highest recorded decision instead of adding it.
    final deletedPaymentIds = getDeletedDocs('payments');
    return getPaymentsForInscription(inscriptionId)
        .where((payment) => !deletedPaymentIds.contains(payment.id) && payment.status != PaymentStatus.echoue)
        .fold<double>(
          0,
          (value, payment) => payment.remise > value ? payment.remise : value,
        );
  }

  double getInscriptionTotalDue(String inscriptionId) {
    final base = getInscriptionBaseTotal(inscriptionId);
    final remise = getInscriptionDiscountTotal(inscriptionId);
    return (base - remise).clamp(0, double.infinity).toDouble();
  }

  double getInscriptionPaidAmount(String inscriptionId) {
    final deletedPaymentIds = getDeletedDocs('payments');
    return getPaymentsForInscription(inscriptionId)
        .where((payment) => !deletedPaymentIds.contains(payment.id) && payment.status == PaymentStatus.effectue)
        .fold<double>(0, (total, payment) => total + payment.montant);
  }

  double getInscriptionBalance(String inscriptionId) {
    return (getInscriptionTotalDue(inscriptionId) -
            getInscriptionPaidAmount(inscriptionId))
        .clamp(0, double.infinity)
        .toDouble();
  }

  /// Calcul unifié des indicateurs clés de performance (KPI) financiers
  Map<String, dynamic> getFinancialKpis() {
    final deletedPaymentIds = getDeletedDocs('payments');
    final deletedInscIds = getDeletedDocs('inscriptions');
    final deletedUserIds = getDeletedDocs('users');
    final deletedUserEmails = getDeletedDocs('user_emails');

    final activeInscriptions = _inscriptions.where((i) {
      final email = (i.email ?? '').trim().toLowerCase();
      return !deletedInscIds.contains(i.id) &&
          !deletedUserIds.contains(i.etudiantId) &&
          !deletedUserIds.contains(i.id) &&
          (email.isEmpty || !deletedUserEmails.contains(email)) &&
          i.status != InscriptionStatus.rejetee;
    }).toList();

    final activePayments = _payments.where((p) {
      if (deletedPaymentIds.contains(p.id)) return false;
      if (deletedInscIds.contains(p.inscriptionId)) return false;
      if (deletedUserIds.contains(p.etudiantId)) return false;
      final user = getUserById(p.etudiantId);
      final email = (user?.email ?? '').trim().toLowerCase();
      if (email.isNotEmpty && deletedUserEmails.contains(email)) return false;
      return true;
    }).toList();

    final totalReceived = activePayments
        .where((p) => p.status == PaymentStatus.effectue)
        .fold<double>(0, (sum, p) => sum + p.montant);

    // Inscriptions comptabilisées : acceptées ou avec acompte/paiement
    final billableInscriptions = activeInscriptions.where((i) =>
        i.status == InscriptionStatus.acceptee ||
        getInscriptionPaidAmount(i.id) > 0).toList();

    final totalDue = billableInscriptions.fold<double>(
      0,
      (sum, ins) => sum + getInscriptionTotalDue(ins.id),
    );

    final totalBalance = billableInscriptions.fold<double>(
      0,
      (sum, ins) => sum + getInscriptionBalance(ins.id),
    );

    final totalDiscount = billableInscriptions.fold<double>(
      0,
      (sum, ins) => sum + getInscriptionDiscountTotal(ins.id),
    );

    final recoveryRate = totalDue > 0
        ? ((totalReceived / totalDue) * 100).clamp(0.0, 100.0)
        : 0.0;

    return {
      'totalReceived': totalReceived,
      'totalDue': totalDue,
      'totalBalance': totalBalance,
      'totalDiscount': totalDiscount,
      'recoveryRate': recoveryRate,
      'totalTransactions': activePayments.length,
      'effectueTransactions': activePayments.where((p) => p.status == PaymentStatus.effectue).length,
      'activeInscriptionsCount': activeInscriptions.length,
      'acceptedCount': activeInscriptions.where((i) => i.status == InscriptionStatus.acceptee).length,
      'pendingCount': activeInscriptions.where((i) => i.status == InscriptionStatus.enAttente).length,
      'debtorsCount': billableInscriptions.where((i) => getInscriptionBalance(i.id) > 0).length,
    };
  }

  /// Calcule la rentabilité financière par formation (Recettes vs Coûts Formateurs)
  List<Map<String, dynamic>> getFormationsProfitability() {
    final deletedInscIds = getDeletedDocs('inscriptions');
    final deletedUserIds = getDeletedDocs('users');
    final deletedUserEmails = getDeletedDocs('user_emails');

    final formations = getFormations();
    final trainers = getUsers().where((u) => u.role == UserRole.formateur).toList();
    final List<Map<String, dynamic>> result = [];

    for (final formation in formations) {
      final inscriptions = _inscriptions.where((i) {
        final email = (i.email ?? '').trim().toLowerCase();
        return i.formationId == formation.id &&
            !deletedInscIds.contains(i.id) &&
            !deletedUserIds.contains(i.etudiantId) &&
            !deletedUserIds.contains(i.id) &&
            (email.isEmpty || !deletedUserEmails.contains(email)) &&
            i.status != InscriptionStatus.rejetee;
      }).toList();

      double totalEncaisse = 0.0;
      double totalDu = 0.0;
      for (final ins in inscriptions) {
        totalEncaisse += getInscriptionPaidAmount(ins.id);
        totalDu += getInscriptionTotalDue(ins.id);
      }

      double coutFormateurs = 0.0;
      for (final trainer in trainers) {
        for (final a in trainer.assignedFormations) {
          if (a['formationId']?.toString() == formation.id) {
            final modules = a['modules'] as List<dynamic>? ?? [];
            for (final m in modules) {
              final doneH = (m['doneHours'] ?? m['assignedHours'] ?? 0) as num;
              final rate = (m['hourlyRate'] ?? 5000.0) as num;
              coutFormateurs += doneH.toDouble() * rate.toDouble();
            }
          }
        }
      }

      if (coutFormateurs == 0.0 && formation.formateurIds.isNotEmpty) {
        final totalHours = formation.dureeSemaines > 0 ? (formation.dureeSemaines * 4) : 20;
        coutFormateurs = totalHours * 5000.0;
      }

      final margeNette = totalEncaisse - coutFormateurs;
      final margePct = totalEncaisse > 0 ? ((margeNette / totalEncaisse) * 100).clamp(-100.0, 100.0) : (coutFormateurs > 0 ? -100.0 : 0.0);

      result.add({
        'formationId': formation.id,
        'formationTitre': formation.titre,
        'nbInscrits': inscriptions.length,
        'totalEncaisse': totalEncaisse,
        'totalDu': totalDu,
        'coutFormateurs': coutFormateurs,
        'margeNette': margeNette,
        'margePct': margePct,
        'estRentable': margeNette >= 0,
      });
    }

    result.sort((a, b) => (b['totalEncaisse'] as double).compareTo(a['totalEncaisse'] as double));
    return result;
  }

  Future<Payment> updatePayment(Payment payment) async {
    final index = _payments.indexWhere((item) => item.id == payment.id);
    if (index == -1) throw StateError('Paiement introuvable: ${payment.id}');
    _payments[index] = payment;
    _paymentsController.add(List.unmodifiable(_payments));
    _savePaymentsToStorage();
    await _syncDocToLocalApi('payments', payment.id, payment.toMap());
    await updateInscriptionPaymentStatus(
      payment.inscriptionId,
      getInscriptionPaidAmount(payment.inscriptionId) >=
          getInscriptionTotalDue(payment.inscriptionId),
    );
    return payment;
  }

  Future<void> updatePaymentStatus(String id, String statusStr) async {
    final index = _payments.indexWhere((p) => p.id == id);
    if (index == -1) return;

    final old = _payments[index];

    PaymentStatus newStatus = old.status;
    if (statusStr == 'valide' ||
        statusStr == 'effectue' ||
        statusStr == 'effectué') {
      newStatus = PaymentStatus.effectue;
    } else if (statusStr == 'incomplet' ||
        statusStr == 'echoue' ||
        statusStr == 'échoué') {
      newStatus = PaymentStatus.echoue;
    } else if (statusStr == 'en_attente' ||
        statusStr == 'enAttente') {
      newStatus = PaymentStatus.enAttente;
    }

    final updated = Payment(
      id: old.id,
      inscriptionId: old.inscriptionId,
      etudiantId: old.etudiantId,
      formationId: old.formationId,
      montant: old.montant,
      status: newStatus,
      methode: old.methode,
      dateCreation: old.dateCreation,
      dateEffectuation: newStatus == PaymentStatus.effectue
          ? (old.dateEffectuation ?? DateTime.now())
          : null,
      referenceTransaction:
          old.referenceTransaction ??
          'REF-${DateTime.now().millisecondsSinceEpoch}',
      motifEchec: old.motifEchec,
      motif: old.motif,
      moduleId: old.moduleId,
      trancheNumero: old.trancheNumero,
      nombreTranches: old.nombreTranches,
      remise: old.remise,
      dateEcheance: old.dateEcheance,
    );

    if (updated.status == PaymentStatus.effectue) {
      final hasSameInstallment = _payments.any(
        (payment) =>
            payment.id != updated.id &&
            payment.inscriptionId == updated.inscriptionId &&
            payment.status == PaymentStatus.effectue &&
            payment.trancheNumero == updated.trancheNumero,
      );
      if (hasSameInstallment) {
        throw StateError('Cette tranche a déjà été validée.');
      }
      final totalDue = getInscriptionTotalDue(updated.inscriptionId);
      final alreadyPaidWithoutThis = getPaymentsForInscription(updated.inscriptionId)
          .where((p) => p.id != updated.id && p.status == PaymentStatus.effectue)
          .fold<double>(0, (s, p) => s + p.montant);
      final proposedPaid = alreadyPaidWithoutThis + updated.montant;
      if (proposedPaid > totalDue) {
        throw StateError('La validation dépasse le solde de l’inscription.');
      }
    }

    _payments[index] = updated;
    _paymentsController.add(List.unmodifiable(_payments));
    _savePaymentsToStorage();
    await _syncDocToLocalApi('payments', updated.id, updated.toMap());

    if (updated.inscriptionId.isNotEmpty) {
      await updateInscriptionPaymentStatus(
        updated.inscriptionId,
        getInscriptionPaidAmount(updated.inscriptionId) >=
            getInscriptionTotalDue(updated.inscriptionId),
      );
    }
  }

  // --- NOTIFICATIONS ---
  Stream<List<AppNotification>> watchNotifications() async* {
    yield List.unmodifiable(_notifications);
    yield* _notificationsController.stream;
  }

  List<AppNotification> getNotifications() => List.unmodifiable(_notifications);

  Future<void> addNotification(AppNotification notif) async {
    _notifications.add(notif);
    _notificationsController.add(List.unmodifiable(_notifications));
    await _syncDocToLocalApi('notifications', notif.id, notif.toMap());
  }

  Future<void> markNotificationRead(String notifId, String userId) async {
    final index = _notifications.indexWhere((n) => n.id == notifId);
    if (index != -1) {
      final old = _notifications[index];
      if (!old.readBy.contains(userId)) {
        final updatedReadBy = List<String>.from(old.readBy)..add(userId);
        final updatedNotif = AppNotification(
          id: old.id,
          title: old.title,
          description: old.description,
          imageUrl: old.imageUrl,
          senderId: old.senderId,
          senderEmail: old.senderEmail,
          targetRoles: old.targetRoles,
          targetUserIds: old.targetUserIds,
          audience: old.audience,
          readBy: updatedReadBy,
          reminderCount: old.reminderCount,
          createdAt: old.createdAt,
          updatedAt: DateTime.now(),
        );
        _notifications[index] = updatedNotif;
        _notificationsController.add(List.unmodifiable(_notifications));
        await _syncDocToLocalApi(
          'notifications',
          updatedNotif.id,
          updatedNotif.toMap(),
        );
      }
    }
  }

  Future<void> updateNotification({
    required String notificationId,
    required String title,
    required String description,
    String? imageUrl,
    required List<String> targetRoles,
    required List<String> targetUserIds,
    required List<String> audience,
  }) async {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      final old = _notifications[index];
      final updatedNotif = AppNotification(
        id: old.id,
        title: title,
        description: description,
        imageUrl: imageUrl,
        senderId: old.senderId,
        senderEmail: old.senderEmail,
        targetRoles: targetRoles,
        targetUserIds: targetUserIds,
        audience: audience,
        readBy: old.readBy,
        reminderCount: old.reminderCount,
        createdAt: old.createdAt,
        updatedAt: DateTime.now(),
      );
      _notifications[index] = updatedNotif;
      _notificationsController.add(List.unmodifiable(_notifications));
      await _syncDocToLocalApi(
        'notifications',
        updatedNotif.id,
        updatedNotif.toMap(),
      );
    }
  }

  Future<void> incrementNotificationReminder(String notificationId) async {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      final old = _notifications[index];
      final updatedNotif = AppNotification(
        id: old.id,
        title: old.title,
        description: old.description,
        imageUrl: old.imageUrl,
        senderId: old.senderId,
        senderEmail: old.senderEmail,
        targetRoles: old.targetRoles,
        targetUserIds: old.targetUserIds,
        audience: old.audience,
        readBy: old.readBy,
        reminderCount: old.reminderCount + 1,
        createdAt: old.createdAt,
        updatedAt: DateTime.now(),
      );
      _notifications[index] = updatedNotif;
      _notificationsController.add(List.unmodifiable(_notifications));
      await _syncDocToLocalApi(
        'notifications',
        updatedNotif.id,
        updatedNotif.toMap(),
      );
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    _notifications.removeWhere((n) => n.id == notificationId);
    _notificationsController.add(List.unmodifiable(_notifications));
    try {
      await _deleteRemoteDoc('notifications', notificationId);
    } catch (_) {}
  }

  Future<void> _sendTrainerStudentAction(
    String action,
    String studentId,
    Map<String, dynamic> payload,
  ) async {
    if (!_hasLocalApi) return;
    final response = await http
        .post(
          _apiUri('trainer/students/${Uri.encodeComponent(studentId)}/$action'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 12));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Mise à jour refusée par le serveur (${response.statusCode}).');
    }
  }

  void _replaceCachedUser(User user) {
    final index = _users.indexWhere((item) => item.id == user.id);
    if (index == -1) return;
    _users[index] = user;
    _saveUsersToStorage();
    _usersController.add(List.unmodifiable(_users));
  }

  Future<void> updateModuleDoneHours(
    String userId,
    String formationId,
    String moduleTitle,
    int delta,
  ) async {
    final student = getUserById(userId);
    if (student == null) return;
    final assignments = student.assignedFormations
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final assignmentIndex = assignments.indexWhere(
      (item) => item['formationId'] == formationId,
    );
    if (assignmentIndex == -1) return;
    final modules =
        (assignments[assignmentIndex]['modules'] as List<dynamic>? ?? [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
    final moduleIndex = modules.indexWhere(
      (item) => item['title'] == moduleTitle,
    );
    if (moduleIndex == -1) return;
    final current = (modules[moduleIndex]['doneHours'] as num?)?.toInt() ?? 0;
    modules[moduleIndex]['doneHours'] = (current + delta).clamp(
      0,
      modules[moduleIndex]['assignedHours'] ?? current + delta,
    );
    assignments[assignmentIndex]['modules'] = modules;
    final updatedStudent = User(
        id: student.id,
        email: student.email,
        nom: student.nom,
        prenom: student.prenom,
        phone: student.phone,
        matricule: student.matricule,
        role: student.role,
        password: student.password,
        photoUrl: student.photoUrl,
        assignedFormations: assignments,
        sexe: student.sexe,
        estActif: student.estActif,
        dateCreation: student.dateCreation,
        dateModification: DateTime.now(),
      );
    await _sendTrainerStudentAction(
      'progress',
      userId,
      {'formationId': formationId, 'moduleTitle': moduleTitle, 'delta': delta},
    );
    _replaceCachedUser(updatedStudent);
    logAction(
      userNom: 'Formateur',
      userRole: 'formateur',
      action: 'Avancement heures',
      description: 'Progression de ${delta > 0 ? "+$delta" : "$delta"}h sur "$moduleTitle" pour ${student.prenom} ${student.nom}',
    );
  }

  Future<void> recordAttendance({
    required String userId,
    required String formationId,
    required String status,
    String? note,
  }) async {
    final student = getUserById(userId);
    if (student == null) throw StateError('Étudiant introuvable.');
    final assignments = student.assignedFormations
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final index = assignments.indexWhere(
      (item) => item['formationId'] == formationId,
    );
    if (index == -1) {
      throw StateError('Formation non attribuée à cet étudiant.');
    }
    final assignment = Map<String, dynamic>.from(assignments[index]);
    final history = (assignment['attendance'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    history.add({
      'date': DateTime.now().toIso8601String(),
      'status': status,
      'note': note?.trim() ?? '',
    });
    assignment['attendance'] = history;
    assignments[index] = assignment;
    final updatedStudent = User(
        id: student.id,
        email: student.email,
        nom: student.nom,
        prenom: student.prenom,
        phone: student.phone,
        matricule: student.matricule,
        role: student.role,
        password: student.password,
        photoUrl: student.photoUrl,
        assignedFormations: assignments,
        estActif: student.estActif,
        dateCreation: student.dateCreation,
        dateModification: DateTime.now(),
      );
    await _sendTrainerStudentAction(
      'attendance',
      userId,
      {'formationId': formationId, 'status': status, 'note': note?.trim() ?? ''},
    );
    _replaceCachedUser(updatedStudent);
    logAction(
      userNom: 'Formateur',
      userRole: 'formateur',
      action: 'Émargement présence',
      description: 'Présence "$status" enregistrée pour ${student.prenom} ${student.nom} ${note != null && note.isNotEmpty ? "($note)" : ""}',
    );
  }

  /// Marquer individuellement la formation d'un étudiant comme terminée (ou en cours) par l'administrateur
  Future<void> setStudentFormationCompletion({
    required String studentId,
    required String formationId,
    required bool isCompleted,
  }) async {
    final student = getUserById(studentId);
    if (student == null) throw StateError('Étudiant introuvable.');
    final assignments = student.assignedFormations
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final index = assignments.indexWhere(
      (item) => item['formationId'] == formationId,
    );
    if (index == -1) {
      assignments.add({
        'formationId': formationId,
        'isCompleted': isCompleted,
        'completedAt': isCompleted ? DateTime.now().toIso8601String() : null,
      });
    } else {
      final assignment = Map<String, dynamic>.from(assignments[index]);
      assignment['isCompleted'] = isCompleted;
      if (isCompleted) {
        assignment['completedAt'] = DateTime.now().toIso8601String();
      } else {
        assignment.remove('completedAt');
      }
      assignments[index] = assignment;
    }

    await addUser(
      User(
        id: student.id,
        email: student.email,
        nom: student.nom,
        prenom: student.prenom,
        phone: student.phone,
        matricule: student.matricule,
        role: student.role,
        password: student.password,
        photoUrl: student.photoUrl,
        specialite: student.specialite,
        sexe: student.sexe,
        assignedFormations: assignments,
        estActif: student.estActif,
        dateCreation: student.dateCreation,
        dateModification: DateTime.now(),
      ),
    );

    final formTitle = getFormationById(formationId)?.titre ?? 'Formation';
    logAction(
      userNom: 'Administration',
      userRole: 'admin',
      action: isCompleted ? 'Validation fin de formation' : 'Réouverture formation',
      description: '${isCompleted ? "Formation déclarée terminée" : "Formation remise en cours"} pour ${student.prenom} ${student.nom} - $formTitle',
    );
  }

  /// Vérifie si l'administrateur a marqué la formation de cet étudiant comme terminée
  bool isStudentFormationCompleted({
    required String studentId,
    required String formationId,
  }) {
    final student = getUserById(studentId);
    if (student == null) return false;
    final item = student.assignedFormations.where((a) => a['formationId'] == formationId).firstOrNull;
    if (item != null && item['isCompleted'] == true) return true;
    final form = getFormationById(formationId);
    if (form != null && form.status == FormationStatus.terminee) return true;
    return false;
  }

  /// Récupère la liste des étudiants inscrits à une formation donnée
  List<User> getStudentsForFormation(String formationId) {
    return _users.where((u) =>
      u.role == UserRole.apprenant &&
      u.assignedFormations.any((a) => a['formationId'] == formationId),
    ).toList();
  }

  /// Récupère le nom du groupe/cohorte pour un étudiant et une formation
  String? getStudentCohort({required String studentId, required String formationId}) {
    final student = getUserById(studentId);
    if (student == null) return null;
    final item = student.assignedFormations.where((a) => a['formationId'] == formationId).firstOrNull;
    return item?['groupe']?.toString();
  }

  /// Met à jour la cohorte/groupe d'un étudiant pour une formation
  Future<void> updateStudentCohort({
    required String studentId,
    required String formationId,
    required String? cohortName,
  }) async {
    final student = getUserById(studentId);
    if (student == null) return;

    final assignments = List<Map<String, dynamic>>.from(
      student.assignedFormations.map((a) => Map<String, dynamic>.from(a)),
    );
    final index = assignments.indexWhere((a) => a['formationId'] == formationId);

    if (index >= 0) {
      final assignment = Map<String, dynamic>.from(assignments[index]);
      if (cohortName == null || cohortName.trim().isEmpty) {
        assignment.remove('groupe');
      } else {
        assignment['groupe'] = cohortName.trim();
      }
      assignments[index] = assignment;
    } else if (cohortName != null && cohortName.trim().isNotEmpty) {
      assignments.add({
        'formationId': formationId,
        'groupe': cohortName.trim(),
      });
    }

    await addUser(
      User(
        id: student.id,
        email: student.email,
        nom: student.nom,
        prenom: student.prenom,
        phone: student.phone,
        matricule: student.matricule,
        role: student.role,
        password: student.password,
        photoUrl: student.photoUrl,
        specialite: student.specialite,
        sexe: student.sexe,
        assignedFormations: assignments,
        estActif: student.estActif,
        dateCreation: student.dateCreation,
        dateModification: DateTime.now(),
      ),
    );

    final formTitle = getFormationById(formationId)?.titre ?? 'Formation';
    logAction(
      userNom: 'Administration',
      userRole: 'admin',
      action: 'Affectation Cohorte/Groupe',
      description: 'Attribution de la cohorte « ${cohortName ?? "Non assigné"} » à ${student.prenom} ${student.nom} ($formTitle)',
    );
  }

  // --- SEANCES ---

  Stream<List<Seance>> watchSeances() async* {
    yield List.unmodifiable(_seances);
    yield* _seancesController.stream;
  }

  List<Seance> getSeances() => List.unmodifiable(_seances);

  List<Seance> getSeancesForFormateur(String formateurId) {
    final formations = getFormationsForFormateur(formateurId);
    final modulesParFormation = {
      for (final f in formations)
        f.id: getModulesForFormateur(f, formateurId).toSet(),
    };

    return _seances.where((s) {
      if (s.formateurId == formateurId) return true;
      final trainerModules = modulesParFormation[s.formationId];
      if (trainerModules == null || trainerModules.isEmpty) return false;
      if (s.moduleTitle != null && s.moduleTitle!.isNotEmpty) {
        return trainerModules.contains(s.moduleTitle);
      }
      return true;
    }).toList();
  }

  Stream<List<Seance>> watchSeancesForFormateur(String formateurId) async* {
    yield getSeancesForFormateur(formateurId);
    yield* _seancesController.stream.map((_) => getSeancesForFormateur(formateurId));
  }

  Future<void> addSeance(Seance seance) async {
    _seances.add(seance);
    _saveSeancesToStorage();
    _seancesController.add(List.unmodifiable(_seances));
    await _syncDocToLocalApi('seances', seance.id, seance.toMap());
  }

  Future<void> updateSeance(Seance seance) async {
    final index = _seances.indexWhere((s) => s.id == seance.id);
    if (index != -1) {
      _seances[index] = seance;
      _saveSeancesToStorage();
      _seancesController.add(List.unmodifiable(_seances));
      await _syncDocToLocalApi('seances', seance.id, seance.toMap());
    }
  }

  Future<void> publishSeance(String seanceId) async {
    final index = _seances.indexWhere((s) => s.id == seanceId);
    if (index != -1) {
      final old = _seances[index];
      final published = old.copyWith(
        statut: SeanceStatut.publie,
        datePublication: DateTime.now(),
      );
      _seances[index] = published;
      _saveSeancesToStorage();
      _seancesController.add(List.unmodifiable(_seances));
      await _syncDocToLocalApi('seances', published.id, published.toMap());
    }
  }

  Future<void> deleteSeance(String id) async {
    _seances.removeWhere((s) => s.id == id);
    _saveSeancesToStorage();
    _seancesController.add(List.unmodifiable(_seances));
    try {
      await _deleteRemoteDoc('seances', id);
    } catch (_) {}
  }

  void _saveAuditLogsToStorage() {
    try {
      _localStorage.setItem(
        'app_saved_audit_logs',
        jsonEncode(_auditLogs.map((a) => a.toMap()).toList()),
      );
    } catch (_) {}
  }

  Future<void> clearAuditLogs() async {
    _auditLogs.clear();
    _auditLogsController.add(const []);
    _localStorage.removeItem('app_saved_audit_logs');
    if (_hasLocalApi) {
      try {
        await http.delete(
          _apiUri('audit_logs/clear'),
          headers: const {'ngrok-skip-browser-warning': 'true'},
        ).timeout(const Duration(seconds: 5));
      } catch (_) {}
    }
  }
}

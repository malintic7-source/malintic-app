import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_formations/Services/pca_pra_service.dart';

void main() {
  group('PCA / PRA Multi-Node Architecture Suite', () {
    test('PraSnapshotInfo parses map correctly', () {
      final map = {
        'filename': 'pra_snapshot_1788134000_sfp5.json',
        'sizeBytes': 204850,
        'createdAt': '2026-08-31T10:00:00.000Z',
        'label': 'sfp5_inscriptions',
        'reason': 'Point avant clôture inscriptions SFP5',
        'counts': {
          'formations': 4,
          'inscriptions': 42,
          'users': 50,
          'payments': 35,
        },
      };

      final snap = PraSnapshotInfo.fromMap(map);
      expect(snap.filename, 'pra_snapshot_1788134000_sfp5.json');
      expect(snap.sizeBytes, 204850);
      expect(snap.label, 'sfp5_inscriptions');
      expect(snap.reason, 'Point avant clôture inscriptions SFP5');
      expect(snap.counts['formations'], 4);
      expect(snap.counts['inscriptions'], 42);
      expect(snap.counts['users'], 50);
      expect(snap.counts['payments'], 35);
    });

    test('NodeHealth structures multi-node statuses correctly', () {
      final now = DateTime.now();
      final docker = NodeHealth(
        name: 'Serveur Docker (LAN)',
        type: 'docker',
        isOnline: true,
        latencyMs: 12,
        details: 'Opérationnel (Uptime: 3600s, RAM: 45MB)',
        lastChecked: now,
      );

      final supabase = NodeHealth(
        name: 'Supabase Cloud (PG)',
        type: 'supabase',
        isOnline: true,
        latencyMs: 145,
        details: 'Connecté',
        lastChecked: now,
      );

      final vercel = NodeHealth(
        name: 'Vercel CDN',
        type: 'vercel',
        isOnline: true,
        latencyMs: null,
        details: 'Multi-utilisateurs',
        lastChecked: now,
      );

      final ngrok = NodeHealth(
        name: 'Ngrok Tunnel',
        type: 'ngrok',
        isOnline: true,
        latencyMs: null,
        details: 'Passerelle active',
        lastChecked: now,
      );

      final report = PcaPraReport(
        dockerNode: docker,
        supabaseNode: supabase,
        vercelNode: vercel,
        ngrokNode: ngrok,
        totalLocalDocuments: 150,
        pendingSyncQueue: 0,
        snapshots: [],
        timestamp: now,
      );

      expect(report.dockerNode.isOnline, isTrue);
      expect(report.supabaseNode.isOnline, isTrue);
      expect(report.vercelNode.isOnline, isTrue);
      expect(report.ngrokNode.isOnline, isTrue);
      expect(report.totalLocalDocuments, 150);
      expect(report.pendingSyncQueue, 0);
    });
  });
}

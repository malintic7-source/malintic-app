import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_formations/Models/audit_log.dart';

void main() {
  group('AuditLog.fromMap', () {
    test('applies the documented defaults when the payload is empty', () {
      final log = AuditLog.fromMap(const {});

      expect(log.id, '');
      expect(log.userNom, 'Système');
      expect(log.userRole, 'Admin');
      expect(log.action, 'ACTION');
      expect(log.description, '');
      expect(log.targetId, isNull);
      expect(log.targetType, isNull);
      expect(log.severity, AuditSeverity.info);
    });

    test('parses each severity name', () {
      expect(AuditLog.fromMap(const {'severity': 'warning'}).severity,
          AuditSeverity.warning);
      expect(AuditLog.fromMap(const {'severity': 'critical'}).severity,
          AuditSeverity.critical);
      expect(AuditLog.fromMap(const {'severity': 'info'}).severity,
          AuditSeverity.info);
    });

    test('falls back to info for an unknown severity', () {
      expect(AuditLog.fromMap(const {'severity': 'fatal'}).severity,
          AuditSeverity.info);
      expect(AuditLog.fromMap(const {'severity': null}).severity,
          AuditSeverity.info);
    });

    test('parses the timestamp from a string and a DateTime', () {
      expect(
        AuditLog.fromMap(const {'timestamp': '2024-05-01T12:30:00.000'}).timestamp,
        DateTime(2024, 5, 1, 12, 30),
      );
      expect(
        AuditLog.fromMap({'timestamp': DateTime(2024, 5, 2)}).timestamp,
        DateTime(2024, 5, 2),
      );
    });

    test('falls back to now for an unparsable timestamp', () {
      final before = DateTime.now().subtract(const Duration(seconds: 1));

      expect(
        AuditLog.fromMap(const {'timestamp': 'not-a-date'}).timestamp.isAfter(before),
        isTrue,
      );
      expect(AuditLog.fromMap(const {}).timestamp.isAfter(before), isTrue);
    });

    test('stringifies the structured target fields', () {
      final log = AuditLog.fromMap(const {'targetId': 42, 'targetType': 'user'});

      expect(log.targetId, '42');
      expect(log.targetType, 'user');
    });
  });

  test('toMap serializes the severity by name and the timestamp as ISO 8601', () {
    final log = AuditLog(
      id: 'log_1',
      userNom: 'Mamadou Toure',
      userRole: 'Admin',
      action: 'Validation Inscription',
      description: 'Inscription validée',
      timestamp: DateTime(2024, 6, 1, 9, 15),
      targetId: 'insc_1',
      targetType: 'inscription',
      severity: AuditSeverity.critical,
    );

    final data = log.toMap();

    expect(data['id'], 'log_1');
    expect(data['userNom'], 'Mamadou Toure');
    expect(data['action'], 'Validation Inscription');
    expect(data['targetId'], 'insc_1');
    expect(data['targetType'], 'inscription');
    expect(data['severity'], 'critical');
    expect(data['timestamp'], DateTime(2024, 6, 1, 9, 15).toIso8601String());
  });

  test('toMap round trips through fromMap', () {
    final log = AuditLog(
      id: 'log_2',
      userNom: 'Système SFP',
      userRole: 'Système',
      action: 'Paiement Enregistré',
      description: 'Acompte Orange Money reçu',
      timestamp: DateTime(2024, 6, 2, 10),
      severity: AuditSeverity.warning,
    );

    final restored = AuditLog.fromMap(log.toMap());

    expect(restored.id, log.id);
    expect(restored.userNom, log.userNom);
    expect(restored.userRole, log.userRole);
    expect(restored.action, log.action);
    expect(restored.description, log.description);
    expect(restored.timestamp, log.timestamp);
    expect(restored.severity, AuditSeverity.warning);
  });

  test('severity defaults to info in the constructor', () {
    final log = AuditLog(
      id: 'log_3',
      userNom: 'Admin',
      userRole: 'Admin',
      action: 'Connexion',
      description: 'Connexion réussie',
      timestamp: DateTime(2024, 6, 3),
    );

    expect(log.severity, AuditSeverity.info);
  });
}

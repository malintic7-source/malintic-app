import 'package:gestion_formations/utils/app_logger.dart';

/// Niveaux de sévérité pour le journal d'audit.
enum AuditSeverity { info, warning, critical }

class AuditLog {
  final String id;
  final String userNom;
  final String userRole;
  final String action;
  final String description;
  final DateTime timestamp;

  /// #20 — Champs structurés ajoutés pour faciliter le filtrage et les exports.
  final String? targetId;
  final String? targetType;
  final AuditSeverity severity;

  AuditLog({
    required this.id,
    required this.userNom,
    required this.userRole,
    required this.action,
    required this.description,
    required this.timestamp,
    this.targetId,
    this.targetType,
    this.severity = AuditSeverity.info,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userNom': userNom,
      'userRole': userRole,
      'action': action,
      'description': description,
      'timestamp': timestamp.toIso8601String(),
      'targetId': targetId,
      'targetType': targetType,
      'severity': severity.name,
    };
  }

  factory AuditLog.fromMap(Map<String, dynamic> map) {
    DateTime parseTimestamp(dynamic value) {
      if (value is DateTime) return value;
      if (value != null && value.runtimeType.toString().contains('Timestamp')) {
        try {
          return (value as dynamic).toDate() as DateTime;
        } catch (e, s) {
          logHandledError(
            'Horodatage du journal illisible, valeur de repli utilisée',
            e,
            s,
          );
        }
      }
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    AuditSeverity parseSeverity(dynamic value) {
      switch (value?.toString()) {
        case 'warning':
          return AuditSeverity.warning;
        case 'critical':
          return AuditSeverity.critical;
        default:
          return AuditSeverity.info;
      }
    }

    return AuditLog(
      id: map['id'] ?? '',
      userNom: map['userNom'] ?? 'Système',
      userRole: map['userRole'] ?? 'Admin',
      action: map['action'] ?? 'ACTION',
      description: map['description'] ?? '',
      timestamp: parseTimestamp(map['timestamp']),
      targetId: map['targetId']?.toString(),
      targetType: map['targetType']?.toString(),
      severity: parseSeverity(map['severity']),
    );
  }
}

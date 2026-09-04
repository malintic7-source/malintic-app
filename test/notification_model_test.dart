import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_formations/Models/notification.dart';

AppNotification buildNotification({
  List<String> readBy = const [],
  List<String> targetRoles = const [],
}) {
  final now = DateTime(2024, 1, 1);
  return AppNotification(
    id: 'notif_1',
    title: 'Titre',
    description: 'Description',
    senderId: 'admin_1',
    senderEmail: 'admin@example.com',
    targetRoles: targetRoles,
    targetUserIds: const [],
    audience: const [],
    readBy: readBy,
    reminderCount: 0,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('AppNotification.fromMap', () {
    test('applies defaults when the payload is empty', () {
      final notification = AppNotification.fromMap(const {}, 'notif_empty');

      expect(notification.id, 'notif_empty');
      expect(notification.title, '');
      expect(notification.description, '');
      expect(notification.imageUrl, isNull);
      expect(notification.senderId, '');
      expect(notification.senderEmail, '');
      expect(notification.targetRoles, isEmpty);
      expect(notification.targetUserIds, isEmpty);
      expect(notification.audience, isEmpty);
      expect(notification.readBy, isEmpty);
      expect(notification.reminderCount, 0);
    });

    test('accepts the legacy titre and message keys', () {
      final notification = AppNotification.fromMap(const {
        'titre': 'Ancien titre',
        'message': 'Ancien message',
      }, 'notif_legacy');

      expect(notification.title, 'Ancien titre');
      expect(notification.description, 'Ancien message');
    });

    test('prefers the modern title and description keys', () {
      final notification = AppNotification.fromMap(const {
        'title': 'Titre',
        'titre': 'Ancien titre',
        'description': 'Description',
        'message': 'Ancien message',
      }, 'notif_modern');

      expect(notification.title, 'Titre');
      expect(notification.description, 'Description');
    });

    test('drops empty entries from the string lists', () {
      final notification = AppNotification.fromMap(const {
        'targetRoles': ['UserRole.admin', '', null],
        'targetUserIds': ['user_1', ''],
        'audience': ['all', null],
        'readBy': ['user_1', ''],
      }, 'notif_lists');

      expect(notification.targetRoles, ['UserRole.admin']);
      expect(notification.targetUserIds, ['user_1']);
      expect(notification.audience, ['all']);
      expect(notification.readBy, ['user_1']);
    });

    test('reads createdAt from the legacy dateCreation key', () {
      final notification = AppNotification.fromMap(const {
        'dateCreation': '2024-03-01T08:00:00.000',
      }, 'notif_date');

      expect(notification.createdAt, DateTime(2024, 3, 1, 8));
    });

    test('defaults updatedAt to createdAt when it is missing', () {
      final notification = AppNotification.fromMap(const {
        'createdAt': '2024-03-02T08:00:00.000',
      }, 'notif_updated');

      expect(notification.updatedAt, notification.createdAt);
    });

    test('parses updatedAt from a DateTime value', () {
      final notification = AppNotification.fromMap({
        'createdAt': DateTime(2024, 3, 3),
        'updatedAt': DateTime(2024, 3, 4),
      }, 'notif_updated_2');

      expect(notification.createdAt, DateTime(2024, 3, 3));
      expect(notification.updatedAt, DateTime(2024, 3, 4));
    });
  });

  test('fromFirestore reads the id from the map payload', () {
    final notification = AppNotification.fromFirestore(<String, dynamic>{
      'id': 'notif_firestore',
      'title': 'Titre',
    });

    expect(notification.id, 'notif_firestore');
    expect(notification.title, 'Titre');
  });

  test('isReadBy only matches users in readBy', () {
    final notification = buildNotification(readBy: const ['user_1']);

    expect(notification.isReadBy('user_1'), isTrue);
    expect(notification.isReadBy('user_2'), isFalse);
  });

  test('toMap round trips through fromMap', () {
    final notification = AppNotification(
      id: 'notif_round',
      title: 'Titre',
      description: 'Description',
      imageUrl: 'https://example.com/image.png',
      senderId: 'admin_1',
      senderEmail: 'admin@example.com',
      targetRoles: const ['UserRole.apprenant'],
      targetUserIds: const ['user_1'],
      audience: const ['etudiants'],
      readBy: const ['user_2'],
      reminderCount: 3,
      createdAt: DateTime(2024, 4, 1),
      updatedAt: DateTime(2024, 4, 2),
    );

    final data = notification.toMap();
    final restored = AppNotification.fromMap(data, notification.id);

    expect(data['createdAt'], DateTime(2024, 4, 1).toIso8601String());
    expect(notification.toFirestore(), data);
    expect(restored.title, 'Titre');
    expect(restored.imageUrl, 'https://example.com/image.png');
    expect(restored.targetRoles, ['UserRole.apprenant']);
    expect(restored.targetUserIds, ['user_1']);
    expect(restored.audience, ['etudiants']);
    expect(restored.readBy, ['user_2']);
    expect(restored.reminderCount, 3);
    expect(restored.updatedAt, DateTime(2024, 4, 2));
  });
}

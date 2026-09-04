import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_formations/Models/notification.dart';
import 'package:gestion_formations/Services/db_services.dart';
import 'package:gestion_formations/Services/notifications_services.dart';

/// The service reads from the shared [LocalDataService] singleton, which is
/// seeded with demo data. Tests therefore create notifications under a unique
/// prefix and only assert on those.
void main() {
  final db = LocalDataService();
  final service = NotificationsService();
  int counter = 0;

  Future<AppNotification> seed({
    required String prefix,
    List<String> targetRoles = const [],
    List<String> targetUserIds = const [],
    List<String> audience = const [],
    List<String> readBy = const [],
    DateTime? createdAt,
  }) async {
    final id = '${prefix}_${counter++}';
    final date = createdAt ?? DateTime(2024, 1, 1);
    final notification = AppNotification(
      id: id,
      title: 'Titre $id',
      description: 'Description $id',
      senderId: 'admin_1',
      senderEmail: 'admin@example.com',
      targetRoles: targetRoles,
      targetUserIds: targetUserIds,
      audience: audience,
      readBy: readBy,
      reminderCount: 0,
      createdAt: date,
      updatedAt: date,
    );
    await db.addNotification(notification);
    return notification;
  }

  Future<List<String>> visibleIds({
    required String prefix,
    required String userId,
    required String userEmail,
    required String userRole,
  }) async {
    final notifications = await service
        .watchNotificationsForUser(
          userId: userId,
          userEmail: userEmail,
          userRole: userRole,
        )
        .first;
    return notifications
        .where((n) => n.id.startsWith(prefix))
        .map((n) => n.id)
        .toList();
  }

  group('watchNotificationsForUser', () {
    test('always shows notifications without any targeting', () async {
      const prefix = 'test_untargeted';
      final untargeted = await seed(prefix: prefix);

      final ids = await visibleIds(
        prefix: prefix,
        userId: 'user_1',
        userEmail: 'user1@example.com',
        userRole: 'UserRole.apprenant',
      );

      expect(ids, [untargeted.id]);
    });

    test('matches the user role ignoring the UserRole prefix and case', () async {
      const prefix = 'test_role';
      final targeted = await seed(prefix: prefix, targetRoles: ['UserRole.Formateur']);
      await seed(prefix: prefix, targetRoles: const ['UserRole.admin']);

      final ids = await visibleIds(
        prefix: prefix,
        userId: 'formateur_1',
        userEmail: 'formateur@example.com',
        userRole: 'UserRole.formateur',
      );

      expect(ids, [targeted.id]);
    });

    test('treats the all and tous roles as broadcast', () async {
      const prefix = 'test_broadcast_role';
      final all = await seed(prefix: prefix, targetRoles: const ['all']);
      final tous = await seed(prefix: prefix, targetRoles: const ['tous']);

      final ids = await visibleIds(
        prefix: prefix,
        userId: 'user_2',
        userEmail: 'user2@example.com',
        userRole: 'UserRole.apprenant',
      );

      expect(ids.toSet(), {all.id, tous.id});
    });

    test('matches an explicitly targeted user id', () async {
      const prefix = 'test_user_id';
      final mine = await seed(prefix: prefix, targetUserIds: const ['user_3']);
      await seed(prefix: prefix, targetUserIds: const ['user_other']);

      final ids = await visibleIds(
        prefix: prefix,
        userId: 'user_3',
        userEmail: 'user3@example.com',
        userRole: 'UserRole.apprenant',
      );

      expect(ids, [mine.id]);
    });

    test('matches the audience by email, case insensitively', () async {
      const prefix = 'test_audience_email';
      final mine = await seed(prefix: prefix, audience: const ['User4@Example.com']);
      await seed(prefix: prefix, audience: const ['someone.else@example.com']);

      final ids = await visibleIds(
        prefix: prefix,
        userId: 'user_4',
        userEmail: 'user4@example.com',
        userRole: 'UserRole.apprenant',
      );

      expect(ids, [mine.id]);
    });

    test('maps the etudiant role to its audience aliases', () async {
      const prefix = 'test_audience_etudiant';
      final etudiants = await seed(prefix: prefix, audience: const ['etudiants']);
      final users = await seed(prefix: prefix, audience: const ['user']);
      final apprenants = await seed(prefix: prefix, audience: const ['apprenant']);
      await seed(prefix: prefix, audience: const ['formateurs']);

      final ids = await visibleIds(
        prefix: prefix,
        userId: 'user_5',
        userEmail: 'user5@example.com',
        userRole: 'UserRole.etudiant',
      );

      expect(ids.toSet(), {etudiants.id, users.id, apprenants.id});
    });

    test('maps the admin and formateur roles to their audiences', () async {
      const prefix = 'test_audience_staff';
      final adminAudience = await seed(prefix: prefix, audience: const ['admin']);
      final formateurAudience = await seed(prefix: prefix, audience: const ['formateur']);

      final adminIds = await visibleIds(
        prefix: prefix,
        userId: 'admin_1',
        userEmail: 'admin1@example.com',
        userRole: 'UserRole.admin',
      );
      final formateurIds = await visibleIds(
        prefix: prefix,
        userId: 'formateur_2',
        userEmail: 'formateur2@example.com',
        userRole: 'UserRole.formateur',
      );

      expect(adminIds, [adminAudience.id]);
      expect(formateurIds, [formateurAudience.id]);
    });

    test('hides notifications targeted at someone else', () async {
      const prefix = 'test_hidden';
      await seed(
        prefix: prefix,
        targetRoles: const ['UserRole.admin'],
        targetUserIds: const ['admin_9'],
        audience: const ['admin9@example.com'],
      );

      final ids = await visibleIds(
        prefix: prefix,
        userId: 'user_6',
        userEmail: 'user6@example.com',
        userRole: 'UserRole.apprenant',
      );

      expect(ids, isEmpty);
    });

    test('returns the most recent notifications first', () async {
      const prefix = 'test_sort';
      final oldest = await seed(prefix: prefix, createdAt: DateTime(2024, 1, 1));
      final newest = await seed(prefix: prefix, createdAt: DateTime(2024, 3, 1));
      final middle = await seed(prefix: prefix, createdAt: DateTime(2024, 2, 1));

      final ids = await visibleIds(
        prefix: prefix,
        userId: 'user_7',
        userEmail: 'user7@example.com',
        userRole: 'UserRole.apprenant',
      );

      expect(ids, [newest.id, middle.id, oldest.id]);
    });
  });

  test('watchUnreadCountForUser counts only visible unread notifications', () async {
    const prefix = 'test_unread';
    const userId = 'user_unread';
    await seed(prefix: prefix, targetUserIds: const [userId]);
    await seed(prefix: prefix, targetUserIds: const [userId]);
    await seed(prefix: prefix, targetUserIds: const [userId], readBy: const [userId]);
    await seed(prefix: prefix, targetUserIds: const ['someone_else']);

    final visibleUnread = await service
        .watchNotificationsForUser(
          userId: userId,
          userEmail: 'unread@example.com',
          userRole: 'UserRole.apprenant',
        )
        .first;
    final totalUnread = await service
        .watchUnreadCountForUser(
          userId: userId,
          userEmail: 'unread@example.com',
          userRole: 'UserRole.apprenant',
        )
        .first;
    final ownUnread = visibleUnread
        .where((n) => n.id.startsWith(prefix) && !n.readBy.contains(userId))
        .length;

    expect(ownUnread, 2);
    expect(totalUnread, greaterThanOrEqualTo(ownUnread));
  });

  test('markAllAsReadForUser only marks the notifications the user can see', () async {
    const prefix = 'test_mark_all';
    const userId = 'user_mark';
    final mine = await seed(prefix: prefix, targetUserIds: const [userId]);
    final broadcast = await seed(prefix: prefix, targetRoles: const ['tous']);
    final other = await seed(prefix: prefix, targetUserIds: const ['someone_else']);

    await service.markAllAsReadForUser(
      userId: userId,
      userEmail: 'mark@example.com',
      userRole: 'UserRole.apprenant',
    );

    AppNotification reload(String id) =>
        db.getNotifications().firstWhere((n) => n.id == id);

    expect(reload(mine.id).isReadBy(userId), isTrue);
    expect(reload(broadcast.id).isReadBy(userId), isTrue);
    expect(reload(other.id).isReadBy(userId), isFalse);
  });

  test('watchAllNotifications sorts every notification by recency', () async {
    const prefix = 'test_watch_all';
    final older = await seed(prefix: prefix, createdAt: DateTime(2023, 1, 1));
    final newer = await seed(prefix: prefix, createdAt: DateTime(2023, 6, 1));

    final all = await service.watchAllNotifications().first;
    final ids = all
        .where((n) => n.id.startsWith(prefix))
        .map((n) => n.id)
        .toList();

    expect(ids, [newer.id, older.id]);
    for (var i = 1; i < all.length; i++) {
      expect(all[i - 1].createdAt.isBefore(all[i].createdAt), isFalse);
    }
  });

  test('createNotification stores an unread notification with its targets', () async {
    const title = 'Nouvelle session SFP';
    await service.createNotification(
      title: title,
      description: 'Les inscriptions sont ouvertes',
      imageUrl: 'https://example.com/affiche.png',
      senderId: 'admin_1',
      senderEmail: 'admin@example.com',
      targetRoles: const ['UserRole.apprenant'],
      targetUserIds: const ['user_created'],
      audience: const ['etudiants'],
    );

    final created =
        db.getNotifications().firstWhere((n) => n.title == title);

    expect(created.description, 'Les inscriptions sont ouvertes');
    expect(created.imageUrl, 'https://example.com/affiche.png');
    expect(created.senderId, 'admin_1');
    expect(created.targetRoles, ['UserRole.apprenant']);
    expect(created.targetUserIds, ['user_created']);
    expect(created.audience, ['etudiants']);
    expect(created.readBy, isEmpty);
    expect(created.reminderCount, 0);
  });

  test('updateNotification rewrites the content and the targets', () async {
    final notification = await seed(prefix: 'test_update');

    await service.updateNotification(
      notificationId: notification.id,
      title: 'Titre modifié',
      description: 'Description modifiée',
      imageUrl: null,
      targetRoles: const ['UserRole.formateur'],
      targetUserIds: const ['formateur_1'],
      audience: const ['formateurs'],
    );

    final updated =
        db.getNotifications().firstWhere((n) => n.id == notification.id);

    expect(updated.title, 'Titre modifié');
    expect(updated.description, 'Description modifiée');
    expect(updated.targetRoles, ['UserRole.formateur']);
    expect(updated.targetUserIds, ['formateur_1']);
    expect(updated.audience, ['formateurs']);
  });

  test('remindNotification increments the reminder counter', () async {
    final notification = await seed(prefix: 'test_remind');

    await service.remindNotification(
      notificationId: notification.id,
      targetUserIds: const ['user_remind'],
    );

    expect(
      db.getNotifications().firstWhere((n) => n.id == notification.id).reminderCount,
      1,
    );
  });

  test('markNotificationRead adds the user once to readBy', () async {
    final notification = await seed(prefix: 'test_read');

    await service.markNotificationRead(
      notificationId: notification.id,
      userId: 'user_read',
    );
    await service.markNotificationRead(
      notificationId: notification.id,
      userId: 'user_read',
    );

    final updated =
        db.getNotifications().firstWhere((n) => n.id == notification.id);

    expect(updated.readBy.where((id) => id == 'user_read'), hasLength(1));
    expect(updated.isReadBy('user_read'), isTrue);
  });

  test('deleteNotification removes the notification', () async {
    final notification = await seed(prefix: 'test_delete');

    await service.deleteNotification(notification.id);

    expect(
      db.getNotifications().any((n) => n.id == notification.id),
      isFalse,
    );
  });
}

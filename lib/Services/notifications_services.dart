import 'package:flutter/foundation.dart';
import 'package:gestion_formations/Models/notification.dart';
import 'package:gestion_formations/Services/db_services.dart';

class NotificationsService {
  final LocalDataService _db = LocalDataService();

  Stream<List<AppNotification>> watchNotificationsForUser({
    required String userId,
    required String userEmail,
    required String userRole,
  }) {
    final normalizedRole = userRole.replaceAll('UserRole.', '').toLowerCase().trim();
    final emailLower = userEmail.toLowerCase().trim();

    return _db.watchNotifications().map((notifications) {
      return notifications.where((notification) {
        final targetRolesLower = notification.targetRoles
            .map((r) => r.replaceAll('UserRole.', '').toLowerCase().trim())
            .toSet();
        final targetUserIds = notification.targetUserIds.toSet();
        final audienceLower = notification.audience
            .map((a) => a.toLowerCase().trim())
            .toSet();

        final roleMatch = targetRolesLower.contains(normalizedRole) ||
            targetRolesLower.contains('all') ||
            targetRolesLower.contains('tous');
        final userMatch = targetUserIds.contains(userId);
        final audienceMatch = audienceLower.contains(emailLower) ||
            audienceLower.contains('all') ||
            audienceLower.contains('tous') ||
            (normalizedRole == 'apprenant' &&
                (audienceLower.contains('etudiants') || audienceLower.contains('user') || audienceLower.contains('apprenant'))) ||
            (normalizedRole == 'admin' && audienceLower.contains('admin')) ||
            (normalizedRole == 'formateur' && audienceLower.contains('formateur')) ||
            (normalizedRole == 'assistant' && audienceLower.contains('assistant')) ||
            (normalizedRole == 'dg' && audienceLower.contains('dg'));

        final isTargeted = notification.targetRoles.isNotEmpty ||
            notification.targetUserIds.isNotEmpty ||
            notification.audience.isNotEmpty;

        final shouldShow = !isTargeted || roleMatch || userMatch || audienceMatch;
        return shouldShow;
      }).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    });
  }

  Stream<int> watchUnreadCountForUser({
    required String userId,
    required String userEmail,
    required String userRole,
  }) {
    return watchNotificationsForUser(
      userId: userId,
      userEmail: userEmail,
      userRole: userRole,
    ).map((list) => list.where((n) => !n.readBy.contains(userId)).length);
  }

  Future<void> markAllAsReadForUser({
    required String userId,
    required String userEmail,
    required String userRole,
  }) async {
    final notifications = _db.getNotifications();
    final normalizedRole = userRole.replaceAll('UserRole.', '').toLowerCase().trim();
    final emailLower = userEmail.toLowerCase().trim();

    for (final notification in notifications) {
      if (notification.readBy.contains(userId)) continue;

      final targetRolesLower = notification.targetRoles
          .map((r) => r.replaceAll('UserRole.', '').toLowerCase().trim())
          .toSet();
      final targetUserIds = notification.targetUserIds.toSet();
      final audienceLower = notification.audience
          .map((a) => a.toLowerCase().trim())
          .toSet();

      final roleMatch = targetRolesLower.contains(normalizedRole) ||
          targetRolesLower.contains('all') ||
          targetRolesLower.contains('tous');
      final userMatch = targetUserIds.contains(userId);
      final audienceMatch = audienceLower.contains(emailLower) ||
          audienceLower.contains('all') ||
          audienceLower.contains('tous');

      final isTargeted = notification.targetRoles.isNotEmpty ||
          notification.targetUserIds.isNotEmpty ||
          notification.audience.isNotEmpty;

      if (!isTargeted || roleMatch || userMatch || audienceMatch) {
        await _db.markNotificationRead(notification.id, userId);
      }
    }
  }

  Stream<List<AppNotification>> watchAllNotifications() {
    return _db.watchNotifications().map((notifications) {
      final list = List<AppNotification>.from(notifications);
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Future<void> createNotification({
    required String title,
    required String description,
    String? imageUrl,
    required String senderId,
    required String senderEmail,
    required List<String> targetRoles,
    required List<String> targetUserIds,
    required List<String> audience,
  }) async {
    final now = DateTime.now();
    final notification = AppNotification(
      id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      description: description,
      imageUrl: imageUrl,
      senderId: senderId,
      senderEmail: senderEmail,
      targetRoles: targetRoles,
      targetUserIds: targetUserIds,
      audience: audience,
      readBy: [],
      reminderCount: 0,
      createdAt: now,
      updatedAt: now,
    );
    await _db.addNotification(notification);
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
    await _db.updateNotification(
      notificationId: notificationId,
      title: title,
      description: description,
      imageUrl: imageUrl,
      targetRoles: targetRoles,
      targetUserIds: targetUserIds,
      audience: audience,
    );
    debugPrint('Notification mise à jour: $notificationId');
  }

  Future<void> remindNotification({
    required String notificationId,
    required List<String> targetUserIds,
  }) async {
    await _db.incrementNotificationReminder(notificationId);
    debugPrint('Relance notification envoyée pour: $notificationId');
  }

  Future<void> markNotificationRead({
    required String notificationId,
    required String userId,
  }) async {
    await _db.markNotificationRead(notificationId, userId);
  }

  Future<void> deleteNotification(String notificationId) async {
    await _db.deleteNotification(notificationId);
    debugPrint('Notification supprimée: $notificationId');
  }
}

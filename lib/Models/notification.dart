// Removed Firestore import (migrating off Firebase)
import 'package:gestion_formations/utils/date_parsing.dart';

class AppNotification {
  final String id;
  final String title;
  final String description;
  final String? imageUrl;
  final String senderId;
  final String senderEmail;
  final List<String> targetRoles;
  final List<String> targetUserIds;
  final List<String> audience;
  final List<String> readBy;
  final int reminderCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  AppNotification({
    required this.id,
    required this.title,
    required this.description,
    this.imageUrl,
    required this.senderId,
    required this.senderEmail,
    required this.targetRoles,
    required this.targetUserIds,
    required this.audience,
    required this.readBy,
    required this.reminderCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AppNotification.fromMap(Map<String, dynamic> data, String id) {
    final createdAtValue = parseDynamicDate(data['createdAt'] ?? data['dateCreation']);

    return AppNotification(
      id: id,
      title: data['title'] ?? data['titre'] ?? '',
      description: data['description'] ?? data['message'] ?? '',
      imageUrl: data['imageUrl'],
      senderId: data['senderId'] ?? '',
      senderEmail: data['senderEmail'] ?? '',
      targetRoles: (data['targetRoles'] as List<dynamic>?)
              ?.map((e) => e?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .toList() ??
          [],
      targetUserIds: (data['targetUserIds'] as List<dynamic>?)
              ?.map((e) => e?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .toList() ??
          [],
      audience: (data['audience'] as List<dynamic>?)
              ?.map((e) => e?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .toList() ??
          [],
      readBy: (data['readBy'] as List<dynamic>?)
              ?.map((e) => e?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .toList() ??
          [],
      reminderCount: (data['reminderCount'] ?? 0) as int,
      createdAt: createdAtValue,
      updatedAt: data['updatedAt'] != null ? parseDynamicDate(data['updatedAt']) : createdAtValue,
    );
  }

  factory AppNotification.fromFirestore(dynamic doc) {
    if (doc is Map<String, dynamic>) {
      return AppNotification.fromMap(doc, doc['id'] ?? '');
    }
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AppNotification.fromMap(data, doc.id ?? '');
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'senderId': senderId,
      'senderEmail': senderEmail,
      'targetRoles': targetRoles,
      'targetUserIds': targetUserIds,
      'audience': audience,
      'readBy': readBy,
      'reminderCount': reminderCount,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toFirestore() => toMap();

  bool isReadBy(String userId) => readBy.contains(userId);
}

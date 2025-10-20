import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:ai/features/camera/interview_models.dart';

class InterviewFolder {
  InterviewFolder({
    required this.id,
    required this.category,
    required this.defaultName,
    this.customName,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final JobCategory category;
  final String defaultName;
  final String? customName;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get displayName {
    final name = customName;
    if (name != null && name.trim().isNotEmpty) {
      return name.trim();
    }
    return defaultName;
  }

  factory InterviewFolder.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    final rawCategory = data['category'] as Map<String, dynamic>?;
    final created = data['createdAt'];
    final updated = data['updatedAt'];

    DateTime createdAt;
    if (created is Timestamp) {
      createdAt = created.toDate();
    } else if (created is DateTime) {
      createdAt = created;
    } else {
      createdAt = DateTime.now();
    }

    DateTime updatedAt;
    if (updated is Timestamp) {
      updatedAt = updated.toDate();
    } else if (updated is DateTime) {
      updatedAt = updated;
    } else {
      updatedAt = createdAt;
    }

    return InterviewFolder(
      id: doc.id,
      category: JobCategory.fromMap(rawCategory),
      defaultName: data['defaultName'] as String? ?? '폴더',
      customName: data['customName'] as String?,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

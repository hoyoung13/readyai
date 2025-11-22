import 'package:cloud_firestore/cloud_firestore.dart';

class CommunityComment {
  const CommunityComment({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorEmail,
    required this.content,
    required this.createdAt,
    required this.likeCount,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String? authorEmail;
  final String content;
  final DateTime? createdAt;
  final int likeCount;

  factory CommunityComment.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return CommunityComment(
      id: doc.id,
      authorId: data['authorId'] as String? ?? '',
      authorName: data['authorName'] as String? ?? '익명',
      authorEmail: data['authorEmail'] as String?,
      content: data['content'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      likeCount: data['likeCount'] as int? ?? 0,
    );
  }
}

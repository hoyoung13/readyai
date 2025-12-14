import 'package:cloud_firestore/cloud_firestore.dart';

class CommunityPost {
  const CommunityPost({
    required this.id,
    required this.category,
    required this.title,
    required this.content,
    required this.authorId,
    required this.authorName,
    required this.authorEmail,
    required this.visible,
    required this.isNotice,
    required this.blockedReason,
    required this.deletedByAdmin,
    required this.createdAt,
    required this.updatedAt,
    required this.likeCount,
    required this.commentCount,
    required this.reportCount,
  });

  final String id;
  final String category;
  final String title;
  final String content;
  final String authorId;
  final String authorName;
  final String? authorEmail;
  final bool visible;
  final bool isNotice;
  final String blockedReason;
  final bool deletedByAdmin;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int likeCount;
  final int commentCount;
  final int reportCount;

  factory CommunityPost.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return CommunityPost(
      id: doc.id,
      category: data['category'] as String? ?? '기타',
      title: data['title'] as String? ?? '제목 없음',
      content: data['content'] as String? ?? '',
      authorId: data['authorId'] as String? ?? '',
      authorName: data['authorName'] as String? ?? '익명',
      authorEmail: data['authorEmail'] as String?,
      visible: data['visible'] != false,
      isNotice: data['isNotice'] == true,
      blockedReason: data['blockedReason'] as String? ?? '',
      deletedByAdmin: data['deletedByAdmin'] == true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      likeCount: data['likeCount'] as int? ?? 0,
      commentCount: data['commentCount'] as int? ?? 0,
      reportCount: data['reportCount'] as int? ?? 0,
    );
  }
}

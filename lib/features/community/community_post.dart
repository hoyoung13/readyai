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
    required this.createdAt,
    required this.likeCount,
    required this.commentCount,
  });

  final String id;
  final String category;
  final String title;
  final String content;
  final String authorId;
  final String authorName;
  final String? authorEmail;
  final DateTime? createdAt;
  final int likeCount;
  final int commentCount;

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
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      likeCount: data['likeCount'] as int? ?? 0,
      commentCount: data['commentCount'] as int? ?? 0,
    );
  }
}

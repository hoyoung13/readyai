import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'community_post.dart';

class CommunityPostService {
  CommunityPostService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('communityPosts');

  Stream<List<CommunityPost>> watchPosts({String? category, int limit = 50}) {
    Query<Map<String, dynamic>> query =
        _collection.where('visible', isEqualTo: true).limit(limit);
    if (category != null && category.isNotEmpty) {
      query = query.where('category', isEqualTo: category);
    }
    return query.snapshots().map((snapshot) {
      final posts = snapshot.docs.map(CommunityPost.fromDoc).toList();
      posts.sort((a, b) {
        final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
      return posts.take(limit).toList(growable: false);
    });
  }

  Stream<List<CommunityPost>> watchHiddenPosts(String authorId) {
    return _collection
        .where('authorId', isEqualTo: authorId)
        .where('visible', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
      final posts = snapshot.docs.map(CommunityPost.fromDoc).toList();
      posts.sort((a, b) {
        final aDate = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
      return posts;
    });
  }

  Stream<List<CommunityPost>> watchAllPosts({int limit = 50}) {
    return _collection
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map(CommunityPost.fromDoc).toList(growable: false));
  }

  Stream<List<CommunityPost>> watchPopularPosts({int limit = 5}) {
    return _collection
        .where('visible', isEqualTo: true)
        .limit(limit * 3)
        .snapshots()
        .map(
      (snapshot) {
        final posts = snapshot.docs.map(CommunityPost.fromDoc).toList();
        posts.sort(
          (a, b) {
            final likeDiff = b.likeCount.compareTo(a.likeCount);
            if (likeDiff != 0) {
              return likeDiff;
            }
            final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bDate.compareTo(aDate);
          },
        );
        return posts.take(limit).toList(growable: false);
      },
    );
  }

  Future<void> createPost({
    required String category,
    required String title,
    required String content,
    required User author,
  }) async {
    final payload = <String, dynamic>{
      'category': category,
      'title': title,
      'content': content,
      'authorId': author.uid,
      'authorName': author.displayName?.trim().isNotEmpty == true
          ? author.displayName!.trim()
          : (author.email ?? '익명'),
      'authorEmail': author.email,
      'likeCount': 0,
      'commentCount': 0,
      'visible': true,
      'blockedReason': '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await _collection.add(payload);
  }

  Future<void> setVisibility({
    required String postId,
    required bool visible,
    String blockedReason = '',
  }) async {
    await _collection.doc(postId).update({
      'visible': visible,
      'blockedReason': blockedReason,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

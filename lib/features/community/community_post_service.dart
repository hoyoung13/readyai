import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'community_comment.dart';
import 'community_post.dart';

class CommunityPostService {
  CommunityPostService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('communityPosts');

  Stream<List<CommunityPost>> watchPosts({
    String? category,
    bool onlyNotices = false,
    int limit = 50,
  }) {
    Query<Map<String, dynamic>> query =
        _collection.where('visible', isEqualTo: true);
    if (category != null && category.isNotEmpty) {
      query = query.where('category', isEqualTo: category);
    }
    if (onlyNotices) {
      query = query.where('isNotice', isEqualTo: true);
    }
    return query
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map(CommunityPost.fromDoc).toList(growable: false));
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

  Stream<CommunityPost?> watchPost(String postId) {
    return _collection.doc(postId).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return null;
      }
      return CommunityPost.fromDoc(snapshot);
    });
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
      'isNotice': false,
      'deletedByAdmin': false,
      'visible': true,
      'blockedReason': '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await _collection.add(payload);
  }

  Future<void> updatePost({
    required CommunityPost post,
    required User editor,
    required String category,
    required String title,
    required String content,
  }) async {
    if (post.authorId != editor.uid) {
      throw FirebaseException(
        plugin: 'communityPosts',
        message: '본인이 작성한 게시글만 수정할 수 있습니다.',
      );
    }

    await _collection.doc(post.id).update({
      'category': category,
      'title': title,
      'content': content,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setVisibility({
    required String postId,
    required bool visible,
    String blockedReason = '',
    bool deletedByAdmin = false,
  }) async {
    await _collection.doc(postId).update({
      'visible': visible,
      'blockedReason': blockedReason,
      'deletedByAdmin': deletedByAdmin,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<CommunityComment>> watchComments(String postId) {
    return _collection
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map(CommunityComment.fromDoc)
            .toList(growable: false));
  }

  Future<void> addComment({
    required String postId,
    required User author,
    required String content,
  }) async {
    final postRef = _collection.doc(postId);
    await _firestore.runTransaction((transaction) async {
      final commentRef = postRef.collection('comments').doc();
      transaction.set(commentRef, {
        'authorId': author.uid,
        'authorName': author.displayName?.trim().isNotEmpty == true
            ? author.displayName!.trim()
            : (author.email ?? '익명'),
        'authorEmail': author.email,
        'content': content,
        'createdAt': FieldValue.serverTimestamp(),
        'likeCount': 0,
      });

      transaction.update(postRef, {
        'commentCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<bool> togglePostLike({
    required String postId,
    required String userId,
  }) async {
    final postRef = _collection.doc(postId);
    final likeRef = postRef.collection('likes').doc(userId);

    return _firestore.runTransaction((transaction) async {
      final likeSnapshot = await transaction.get(likeRef);
      final exists = likeSnapshot.exists;

      transaction.update(postRef, {
        'likeCount': FieldValue.increment(exists ? -1 : 1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (exists) {
        transaction.delete(likeRef);
        return false;
      }

      transaction.set(likeRef, {
        'userId': userId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    });
  }

  Future<bool> toggleCommentLike({
    required String postId,
    required String commentId,
    required String userId,
  }) async {
    final commentRef =
        _collection.doc(postId).collection('comments').doc(commentId);
    final likeRef = commentRef.collection('likes').doc(userId);

    return _firestore.runTransaction((transaction) async {
      final likeSnapshot = await transaction.get(likeRef);
      final exists = likeSnapshot.exists;

      transaction.update(commentRef, {
        'likeCount': FieldValue.increment(exists ? -1 : 1),
      });

      if (exists) {
        transaction.delete(likeRef);
        return false;
      }

      transaction.set(likeRef, {
        'userId': userId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    });
  }

  Stream<bool> watchPostLiked(String postId, String userId) {
    return _collection
        .doc(postId)
        .collection('likes')
        .doc(userId)
        .snapshots()
        .map((snapshot) => snapshot.exists);
  }

  Stream<bool> watchCommentLiked({
    required String postId,
    required String commentId,
    required String userId,
  }) {
    return _collection
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .collection('likes')
        .doc(userId)
        .snapshots()
        .map((snapshot) => snapshot.exists);
  }
}

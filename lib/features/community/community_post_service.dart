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
    final normalizedCategory =
        category != null && category.isNotEmpty && category != '전체'
            ? category
            : null;

    return _collection
        .where('visible', isEqualTo: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      final posts = snapshot.docs.map(CommunityPost.fromDoc).where((post) {
        if (onlyNotices && !post.isNotice) return false;
        if (normalizedCategory != null && post.category != normalizedCategory) {
          return false;
        }
        return true;
      }).toList(growable: false);

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

  Stream<List<ReportedCommunityPost>> watchReportedPosts({int limit = 50}) {
    return _firestore
        .collectionGroup('reports')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .asyncMap((snapshot) async {
      if (snapshot.docs.isEmpty) {
        return const <ReportedCommunityPost>[];
      }

      final Map<String, int> reportCounts = {};
      for (final doc in snapshot.docs) {
        final postId = doc.data()['postId'] as String?;
        if (postId == null || postId.isEmpty) continue;
        reportCounts.update(postId, (value) => value + 1, ifAbsent: () => 1);
      }

      final postsById = await _fetchPostsByIds(reportCounts.keys);
      final reportedPosts = <ReportedCommunityPost>[];
      for (final entry in postsById.entries) {
        reportedPosts.add(
          ReportedCommunityPost(
            post: entry.value,
            reportCount: reportCounts[entry.key] ?? 0,
          ),
        );
      }

      reportedPosts.sort((a, b) {
        final countDiff = b.reportCount.compareTo(a.reportCount);
        if (countDiff != 0) return countDiff;

        final aDate = a.post.updatedAt ??
            a.post.createdAt ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.post.updatedAt ??
            b.post.createdAt ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });

      return reportedPosts;
    });
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
    bool isAdmin = false,
  }) async {
    if (category == '공지' && !isAdmin) {
      throw FirebaseException(
        plugin: 'communityPosts',
        message: '공지 글은 관리자만 작성할 수 있습니다.',
      );
    }

    final isNotice = category == '공지';
    final authorName = await _resolveAuthorName(author);
    final payload = <String, dynamic>{
      'category': category,
      'title': title,
      'content': content,
      'authorId': author.uid,
      'authorName': authorName,
      'authorEmail': author.email,
      'likeCount': 0,
      'commentCount': 0,
      'isNotice': isNotice,
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
    bool isAdmin = false,
  }) async {
    if (post.authorId != editor.uid) {
      throw FirebaseException(
        plugin: 'communityPosts',
        message: '본인이 작성한 게시글만 수정할 수 있습니다.',
      );
    }

    if (category == '공지' && !isAdmin) {
      throw FirebaseException(
        plugin: 'communityPosts',
        message: '공지 글은 관리자만 작성할 수 있습니다.',
      );
    }

    final isNotice = category == '공지';

    await _collection.doc(post.id).update({
      'category': category,
      'title': title,
      'content': content,
      'isNotice': isNotice,
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
    final authorName = await _resolveAuthorName(author);
    final postRef = _collection.doc(postId);
    await _firestore.runTransaction((transaction) async {
      final commentRef = postRef.collection('comments').doc();
      transaction.set(commentRef, {
        'authorId': author.uid,
        'authorName': authorName,
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

  Future<String> _resolveAuthorName(User author) async {
    try {
      final userDoc =
          await _firestore.collection('users').doc(author.uid).get();
      final nickname = userDoc.data()?['nickname'] as String?;
      if (nickname != null && nickname.trim().isNotEmpty) {
        return nickname.trim();
      }
    } catch (_) {
      // Firestore 조회 실패 시 auth 정보로 fallback
    }

    final displayName = author.displayName;
    if (displayName != null && displayName.trim().isNotEmpty) {
      return displayName.trim();
    }
    return author.email ?? '익명';
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

  Future<void> reportPost({
    required CommunityPost post,
    required User reporter,
    required String reason,
  }) async {
    final reportRef =
        _collection.doc(post.id).collection('reports').doc(reporter.uid);

    await reportRef.set({
      'postId': post.id,
      'postAuthorId': post.authorId,
      'reporterId': reporter.uid,
      'reporterEmail': reporter.email,
      'reason': reason,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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

  Future<Map<String, CommunityPost>> _fetchPostsByIds(
    Iterable<String> postIds,
  ) async {
    final ids = postIds.where((id) => id.isNotEmpty).toSet();
    if (ids.isEmpty) {
      return {};
    }

    final Map<String, CommunityPost> posts = {};
    final chunks = <List<String>>[];
    var current = <String>[];
    for (final id in ids) {
      current.add(id);
      if (current.length == 10) {
        chunks.add(current);
        current = <String>[];
      }
    }
    if (current.isNotEmpty) {
      chunks.add(current);
    }

    for (final chunk in chunks) {
      final snapshot =
          await _collection.where(FieldPath.documentId, whereIn: chunk).get();
      for (final doc in snapshot.docs) {
        posts[doc.id] = CommunityPost.fromDoc(doc);
      }
    }

    return posts;
  }
}

class ReportedCommunityPost {
  const ReportedCommunityPost({
    required this.post,
    required this.reportCount,
  });

  final CommunityPost post;
  final int reportCount;
}

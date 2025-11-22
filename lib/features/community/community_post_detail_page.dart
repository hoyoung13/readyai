import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../tabs/tabs_shared.dart';
import 'community_comment.dart';
import 'community_post.dart';
import 'community_post_service.dart';

class CommunityPostDetailPage extends StatefulWidget {
  const CommunityPostDetailPage({super.key, required this.postId});

  final String postId;

  @override
  State<CommunityPostDetailPage> createState() =>
      _CommunityPostDetailPageState();
}

class _CommunityPostDetailPageState extends State<CommunityPostDetailPage> {
  final CommunityPostService _service = CommunityPostService();
  final TextEditingController _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        final user = authSnapshot.data;
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.black),
            title: const Text(
              '게시글 상세',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          body: StreamBuilder<CommunityPost?>(
            stream: _service.watchPost(widget.postId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final post = snapshot.data;
              if (post == null) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('게시글을 찾을 수 없습니다.'),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => context.pop(),
                        child: const Text('뒤로가기'),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _PostHeader(post: post),
                        const SizedBox(height: 12),
                        Text(
                          post.title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          post.content,
                          style: const TextStyle(fontSize: 15, height: 1.5),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _LikeButton(
                              service: _service,
                              post: post,
                              userId: user?.uid,
                            ),
                            const SizedBox(width: 12),
                            Row(
                              children: [
                                const Icon(Icons.chat_bubble_outline,
                                    size: 16, color: AppColors.subtext),
                                const SizedBox(width: 4),
                                Text('${post.commentCount}',
                                    style: const TextStyle(
                                        color: AppColors.subtext)),
                              ],
                            ),
                            const Spacer(),
                            Text(
                              _formatTime(post.createdAt),
                              style: const TextStyle(
                                color: AppColors.subtext,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 12),
                        const Text(
                          '댓글',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _CommentList(
                          service: _service,
                          postId: post.id,
                          currentUserId: user?.uid,
                        ),
                      ],
                    ),
                  ),
                  _CommentComposer(
                    controller: _commentController,
                    enabled: user != null,
                    onSubmit: (value) => _submitComment(user, value),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _submitComment(User? user, String value) async {
    final content = value.trim();
    if (content.isEmpty) return;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인 후 댓글을 남길 수 있어요.')),
      );
      return;
    }

    try {
      await _service.addComment(
        postId: widget.postId,
        author: user,
        content: content,
      );
      _commentController.clear();
    } on FirebaseException catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('댓글 작성에 실패했습니다: ${error.message}')),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('댓글 작성에 실패했습니다: $error')),
      );
    }
  }
}

class _PostHeader extends StatelessWidget {
  const _PostHeader({required this.post});

  final CommunityPost post;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.mint.withOpacity(0.16),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            post.category,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (post.isNotice) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              '공지',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              post.authorName,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.subtext,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              post.authorEmail ?? '익명',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.subtext,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CommentList extends StatelessWidget {
  const _CommentList({
    required this.service,
    required this.postId,
    this.currentUserId,
  });

  final CommunityPostService service;
  final String postId;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CommunityComment>>(
      stream: service.watchComments(postId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final comments = snapshot.data ?? const <CommunityComment>[];
        if (comments.isEmpty) {
          return const Text('첫 댓글을 남겨보세요!');
        }

        return Column(
          children: [
            for (final comment in comments) ...[
              _CommentTile(
                comment: comment,
                postId: postId,
                service: service,
                currentUserId: currentUserId,
              ),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.postId,
    required this.service,
    this.currentUserId,
  });

  final CommunityComment comment;
  final String postId;
  final CommunityPostService service;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comment.authorName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      comment.authorEmail ?? '익명',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.subtext,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _formatTime(comment.createdAt),
                style: const TextStyle(fontSize: 12, color: AppColors.subtext),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(comment.content),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: _CommentLikeButton(
              service: service,
              postId: postId,
              comment: comment,
              currentUserId: currentUserId,
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentLikeButton extends StatefulWidget {
  const _CommentLikeButton({
    required this.service,
    required this.postId,
    required this.comment,
    this.currentUserId,
  });

  final CommunityPostService service;
  final String postId;
  final CommunityComment comment;
  final String? currentUserId;

  @override
  State<_CommentLikeButton> createState() => _CommentLikeButtonState();
}

class _CommentLikeButtonState extends State<_CommentLikeButton> {
  bool _pending = false;

  @override
  Widget build(BuildContext context) {
    final userId = widget.currentUserId;
    if (userId == null) {
      return _LikeChip(
          liked: false,
          count: widget.comment.likeCount,
          onPressed: _showLoginRequired);
    }

    return StreamBuilder<bool>(
      stream: widget.service.watchCommentLiked(
        postId: widget.postId,
        commentId: widget.comment.id,
        userId: userId,
      ),
      builder: (context, snapshot) {
        final liked = snapshot.data ?? false;
        return _LikeChip(
          liked: liked,
          count: widget.comment.likeCount,
          onPressed: _pending ? null : () => _toggle(liked, userId),
        );
      },
    );
  }

  Future<void> _toggle(bool liked, String userId) async {
    setState(() => _pending = true);
    try {
      await widget.service.toggleCommentLike(
        postId: widget.postId,
        commentId: widget.comment.id,
        userId: userId,
      );
    } finally {
      if (mounted) {
        setState(() => _pending = false);
      }
    }
  }

  void _showLoginRequired() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('로그인 후 좋아요를 누를 수 있어요.')),
    );
  }
}

class _LikeButton extends StatefulWidget {
  const _LikeButton({
    required this.service,
    required this.post,
    this.userId,
  });

  final CommunityPostService service;
  final CommunityPost post;
  final String? userId;

  @override
  State<_LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<_LikeButton> {
  bool _pending = false;

  @override
  Widget build(BuildContext context) {
    final userId = widget.userId;
    if (userId == null) {
      return _LikeChip(
        liked: false,
        count: widget.post.likeCount,
        onPressed: _showLoginRequired,
      );
    }

    return StreamBuilder<bool>(
      stream: widget.service.watchPostLiked(widget.post.id, userId),
      builder: (context, snapshot) {
        final liked = snapshot.data ?? false;
        return _LikeChip(
          liked: liked,
          count: widget.post.likeCount,
          onPressed: _pending ? null : () => _toggle(liked, userId),
        );
      },
    );
  }

  Future<void> _toggle(bool liked, String userId) async {
    setState(() => _pending = true);
    try {
      await widget.service.togglePostLike(
        postId: widget.post.id,
        userId: userId,
      );
    } finally {
      if (mounted) {
        setState(() => _pending = false);
      }
    }
  }

  void _showLoginRequired() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('로그인 후 좋아요를 누를 수 있어요.')),
    );
  }
}

class _LikeChip extends StatelessWidget {
  const _LikeChip({
    required this.liked,
    required this.count,
    this.onPressed,
  });

  final bool liked;
  final int count;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: liked ? Colors.red : AppColors.subtext,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: Icon(liked ? Icons.favorite : Icons.favorite_border),
      label: Text('$count'),
    );
  }
}

class _CommentComposer extends StatelessWidget {
  const _CommentComposer({
    required this.controller,
    required this.enabled,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String> onSubmit;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                decoration: InputDecoration(
                  hintText: enabled ? '댓글을 입력하세요' : '로그인 후 댓글 작성 가능',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                minLines: 1,
                maxLines: 3,
                onSubmitted: (value) {
                  onSubmit(value);
                  controller.clear();
                },
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: enabled
                  ? () {
                      onSubmit(controller.text);
                      controller.clear();
                    }
                  : null,
              child: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatTime(DateTime? createdAt) {
  if (createdAt == null) {
    return '방금 전';
  }
  final now = DateTime.now();
  final diff = now.difference(createdAt);
  if (diff.inMinutes < 1) return '방금 전';
  if (diff.inHours < 1) return '${diff.inMinutes}분 전';
  if (diff.inDays < 1) return '${diff.inHours}시간 전';
  if (diff.inDays < 7) return '${diff.inDays}일 전';
  final month = createdAt.month.toString().padLeft(2, '0');
  final day = createdAt.day.toString().padLeft(2, '0');
  return '${createdAt.year}.$month.$day';
}

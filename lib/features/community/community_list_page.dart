import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../tabs/tabs_shared.dart';
import 'community_post.dart';
import 'community_post_service.dart';

class CommunityListPage extends StatefulWidget {
  const CommunityListPage({super.key, this.initialCategory});

  final String? initialCategory;

  @override
  State<CommunityListPage> createState() => _CommunityListPageState();
}

class _CommunityListPageState extends State<CommunityListPage> {
  final CommunityPostService _service = CommunityPostService();
  late String? _category;

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory;
  }

  @override
  Widget build(BuildContext context) {
    final title = _category?.isNotEmpty == true ? _category! : '전체 게시글';
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black),
          title: Text(
            title,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w800,
            ),
          ),
          bottom: const TabBar(
            labelColor: Colors.black,
            indicatorColor: AppColors.mint,
            tabs: [
              Tab(text: '전체글'),
              Tab(text: '공지글'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _PostList(
              service: _service,
              category: _category,
              onlyNotices: false,
              onTap: _openPost,
            ),
            _PostList(
              service: _service,
              category: _category,
              onlyNotices: true,
              onTap: _openPost,
            ),
          ],
        ),
      ),
    );
  }

  void _openPost(CommunityPost post) {
    context.push('/community/posts/${post.id}', extra: post);
  }
}

class _PostList extends StatelessWidget {
  const _PostList({
    required this.service,
    required this.onTap,
    this.category,
    this.onlyNotices = false,
  });

  final CommunityPostService service;
  final void Function(CommunityPost) onTap;
  final String? category;
  final bool onlyNotices;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CommunityPost>>(
      stream: service.watchPosts(
          category: category, onlyNotices: onlyNotices, limit: 100),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final posts = snapshot.data ?? const <CommunityPost>[];
        if (posts.isEmpty) {
          return Center(
            child: Text(onlyNotices ? '등록된 공지글이 없습니다.' : '아직 게시글이 없습니다.'),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: posts.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final post = posts[index];
            return _PostTile(post: post, onTap: () => onTap(post));
          },
        );
      },
    );
  }
}

class _PostTile extends StatelessWidget {
  const _PostTile({required this.post, required this.onTap});

  final CommunityPost post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.06),
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
                Text(
                  post.authorName,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.subtext,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              post.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              post.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.subtext),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _StatChip(
                    icon: Icons.thumb_up_alt_outlined, value: post.likeCount),
                const SizedBox(width: 8),
                _StatChip(
                    icon: Icons.chat_bubble_outline, value: post.commentCount),
                const Spacer(),
                Text(
                  _formatTime(post.createdAt),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.subtext,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.value});

  final IconData icon;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.subtext),
        const SizedBox(width: 4),
        Text(
          '$value',
          style: const TextStyle(color: AppColors.subtext),
        ),
      ],
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

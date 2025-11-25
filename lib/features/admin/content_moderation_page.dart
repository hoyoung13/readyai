import 'package:flutter/material.dart';
import '../community/community_post.dart';
import '../community/community_post_service.dart';
import '../jobs/job_posting_service.dart';
import 'admin_guard.dart';

class ContentModerationPage extends StatefulWidget {
  const ContentModerationPage({super.key});

  @override
  State<ContentModerationPage> createState() => _ContentModerationPageState();
}

class _ContentModerationPageState extends State<ContentModerationPage>
    with SingleTickerProviderStateMixin {
  late final TabController _controller;
  final CommunityPostService _communityService = CommunityPostService();
  final JobPostingService _jobPostingService = JobPostingService();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _controller = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminRouteGuard(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('게시물 · 채용공고 관리'),
          bottom: TabBar(
            controller: _controller,
            tabs: const [
              Tab(text: '커뮤니티'),
              Tab(text: '채용공고'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _controller,
          children: [
            _buildCommunityTab(),
            _buildJobsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildCommunityTab() {
    return StreamBuilder<List<ReportedCommunityPost>>(
      stream: _communityService.watchReportedPosts(limit: 100),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final reportedPosts = snapshot.data ?? const <ReportedCommunityPost>[];
        if (reportedPosts.isEmpty) {
          return const Center(child: Text('신고된 게시글이 없습니다.'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: reportedPosts.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final reported = reportedPosts[index];
            final post = reported.post;
            return Card(
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            post.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Chip(
                          backgroundColor: Colors.red.shade50,
                          label: Text(
                            '신고 ${reported.reportCount}',
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        _StatusChip(visible: post.visible),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${post.category} · ${post.authorName}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    if (post.blockedReason.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        '사유: ${post.blockedReason}',
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _updateCommunityVisibility(
                                    post.id,
                                    false,
                                    '관리자 숨김 처리',
                                  ),
                          icon: const Icon(Icons.visibility_off_outlined),
                          label: const Text('숨김'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _updateCommunityVisibility(
                                    post.id,
                                    false,
                                    '삭제 처리',
                                  ),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('삭제'),
                        ),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.red.shade600,
                          ),
                          onPressed: _busy
                              ? null
                              : () => _promptBlindReason(
                                    onSubmit: (reason) =>
                                        _updateCommunityVisibility(
                                      post.id,
                                      false,
                                      reason,
                                    ),
                                  ),
                          icon: const Icon(Icons.shield_outlined),
                          label: const Text('블라인드'),
                        ),
                        if (!post.visible)
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => _updateCommunityVisibility(
                                      post.id,
                                      true,
                                      '',
                                    ),
                            child: const Text('가시화'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildJobsTab() {
    return StreamBuilder<List<JobPostRecord>>(
      stream: _jobPostingService.streamAllPosts(limit: 100),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final posts = snapshot.data ?? const <JobPostRecord>[];
        if (posts.isEmpty) {
          return const Center(child: Text('등록된 채용공고가 없습니다.'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: posts.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final post = posts[index];
            return Card(
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            post.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        _StatusChip(visible: post.visible),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${post.company} · ${post.region}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    if (post.blockedReason.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        '사유: ${post.blockedReason}',
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _updateJobVisibility(
                                    post.id,
                                    false,
                                    '관리자 숨김 처리',
                                  ),
                          icon: const Icon(Icons.visibility_off_outlined),
                          label: const Text('숨김'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _updateJobVisibility(
                                    post.id,
                                    false,
                                    '삭제 처리',
                                  ),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('삭제'),
                        ),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.red.shade600,
                          ),
                          onPressed: _busy
                              ? null
                              : () => _promptBlindReason(
                                    onSubmit: (reason) => _updateJobVisibility(
                                      post.id,
                                      false,
                                      reason,
                                    ),
                                  ),
                          icon: const Icon(Icons.shield_outlined),
                          label: const Text('블라인드'),
                        ),
                        if (!post.visible)
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => _updateJobVisibility(
                                      post.id,
                                      true,
                                      '',
                                    ),
                            child: const Text('가시화'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _updateCommunityVisibility(
    String postId,
    bool visible,
    String reason,
  ) async {
    setState(() => _busy = true);
    try {
      await _communityService.setVisibility(
        postId: postId,
        visible: visible,
        blockedReason: reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            visible ? '게시글을 다시 노출했습니다.' : '게시글 상태가 업데이트되었습니다.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('처리 중 오류가 발생했습니다. $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _updateJobVisibility(
    String postId,
    bool visible,
    String reason,
  ) async {
    setState(() => _busy = true);
    try {
      await _jobPostingService.setVisibility(
        jobPostId: postId,
        visible: visible,
        blockedReason: reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            visible ? '공고를 다시 노출했습니다.' : '공고 상태가 업데이트되었습니다.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('처리 중 오류가 발생했습니다. $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _promptBlindReason({
    required ValueChanged<String> onSubmit,
  }) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('블라인드 사유 작성'),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: '신고/운영정책 위반 내용 등을 입력하세요.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('저장'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && controller.text.trim().isNotEmpty) {
      onSubmit(controller.text.trim());
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    return Chip(
      backgroundColor: visible ? Colors.green.shade100 : Colors.red.shade100,
      label: Text(
        visible ? '노출 중' : '차단됨',
        style: TextStyle(
          color: visible ? Colors.green.shade800 : Colors.red.shade800,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

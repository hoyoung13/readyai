import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ai/features/jobs/job_posting_service.dart';
import 'package:ai/features/tabs/tabs_shared.dart';

class CompanyJobListPage extends StatelessWidget {
  CompanyJobListPage({super.key});

  final JobPostingService _service = JobPostingService();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('로그인 후 이용해 주세요.')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('나의 공고'),
        centerTitle: false,
      ),
      backgroundColor: AppColors.bg,
      body: StreamBuilder<List<JobPostRecord>>(
        stream: _service.streamOwnerPosts(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final posts = snapshot.data ?? const <JobPostRecord>[];
          if (posts.isEmpty) {
            return const _EmptyState(
              message: '등록된 채용 공고가 없습니다. 첫 공고를 등록해 보세요!',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemBuilder: (context, index) {
              final post = posts[index];
              final summary = '${post.experienceLevel} · ${post.education} · '
                  '${post.region} · ${post.employmentType}';
              return _JobCard(
                company: post.company,
                title: post.title,
                summary: summary,
                visible: post.visible,
                blockedReason: post.blockedReason,
                onViewApplicants: () => context.go('/company/applicants'),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemCount: posts.length,
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: FilledButton(
            onPressed: () => context.push('/company/post-job'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('신규 공고 등록'),
          ),
        ),
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({
    required this.company,
    required this.title,
    required this.summary,
    required this.onViewApplicants,
    required this.visible,
    required this.blockedReason,
  });

  final String company;
  final String title;
  final String summary;
  final VoidCallback onViewApplicants;
  final bool visible;
  final String blockedReason;

  @override
  Widget build(BuildContext context) {
    final badgeColor =
        visible ? const Color(0xFFEEF8ED) : const Color(0xFFFFF2F2);
    final badgeTextColor =
        visible ? const Color(0xFF2E7D32) : const Color(0xFFB71C1C);
    final badgeLabel = visible ? '게시 중' : '숨김';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$company / $title',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badgeLabel,
                  style: TextStyle(
                    color: badgeTextColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!visible && blockedReason.trim().isNotEmpty) ...[
            Text(
              blockedReason,
              style: const TextStyle(
                color: Color(0xFFB71C1C),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: Text(
                  summary,
                  style: const TextStyle(color: AppColors.subtext),
                ),
              ),
              TextButton(
                onPressed: onViewApplicants,
                child: const Text('지원현황 보기'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.work_outline, size: 56, color: AppColors.subtext),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ai/features/jobs/job_posting_service.dart';
import 'package:ai/features/tabs/tabs_shared.dart';

class CompanyApplicantOverviewPage extends StatefulWidget {
  const CompanyApplicantOverviewPage({super.key});

  @override
  State<CompanyApplicantOverviewPage> createState() =>
      _CompanyApplicantOverviewPageState();
}

class _CompanyApplicantOverviewPageState
    extends State<CompanyApplicantOverviewPage> {
  final JobPostingService _service = JobPostingService();
  JobPostRecord? _selectedJob;

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
        title: const Text('지원 현황 보기'),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              children: const [
                Text(
                  '본인이 등록한 채용공고를 선택하면 지원 내역이 표시돼요.',
                  style: TextStyle(color: AppColors.subtext),
                ),
              ],
            ),
          ),
        ),
      ),
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          _JobPicker(
            service: _service,
            ownerUid: user.uid,
            selectedJob: _selectedJob,
            onSelected: (job) => setState(() => _selectedJob = job),
          ),
          Expanded(
            child: _ApplicantList(
              service: _service,
              ownerUid: user.uid,
              selectedJob: _selectedJob,
            ),
          ),
        ],
      ),
    );
  }
}

class _JobPicker extends StatelessWidget {
  const _JobPicker({
    required this.service,
    required this.ownerUid,
    required this.selectedJob,
    required this.onSelected,
  });

  final JobPostingService service;
  final String ownerUid;
  final JobPostRecord? selectedJob;
  final ValueChanged<JobPostRecord> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: StreamBuilder<List<JobPostRecord>>(
        stream: service.streamOwnerPosts(ownerUid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final posts = snapshot.data ?? const <JobPostRecord>[];
          if (posts.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('등록한 채용공고가 없습니다. 공고를 먼저 등록해주세요.'),
              ),
            );
          }

          final currentSelection = selectedJob;
          if (currentSelection == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              onSelected(posts.first);
            });
          }

          final controller = PageController(viewportFraction: 0.9);

          return PageView.builder(
            controller: controller,
            itemCount: posts.length,
            padEnds: false,
            itemBuilder: (context, index) {
              final post = posts[index];
              final isSelected = post.id == selectedJob?.id;
              return Padding(
                  padding: EdgeInsets.only(
                    left: index == 0 ? 16 : 10,
                    right: index == posts.length - 1 ? 16 : 10,
                    top: 14,
                    bottom: 10,
                  ),
                  child: _JobCard(
                    post: post,
                    selected: isSelected,
                    service: service,
                    onTap: () => onSelected(post),
                  ));
            },
            onPageChanged: (page) {
              final post = posts[page];
              if (post.id != selectedJob?.id) {
                onSelected(post);
              }
            },
          );
        },
      ),
    );
  }
}

class _ApplicantList extends StatelessWidget {
  const _ApplicantList({
    required this.service,
    required this.ownerUid,
    required this.selectedJob,
  });

  final JobPostingService service;
  final String ownerUid;
  final JobPostRecord? selectedJob;

  @override
  Widget build(BuildContext context) {
    if (selectedJob == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('확인할 채용공고를 선택해 주세요.'),
        ),
      );
    }

    return StreamBuilder<List<JobApplicationRecord>>(
      stream: service.streamApplicationsForOwner(
        ownerUid,
        jobPostId: selectedJob!.id,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final applications =
            List<JobApplicationRecord>.from(snapshot.data ?? const []);
        applications.sort(
          (a, b) => b.appliedAt.compareTo(a.appliedAt),
        );
        if (applications.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('해당 공고에 접수된 지원 내역이 없습니다.'),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          child: Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 4,
            shadowColor: Colors.black26.withOpacity(0.05),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '지원 내역 보기',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (selectedJob != null)
                        Flexible(
                          child: Text(
                            selectedJob!.title,
                            style: const TextStyle(color: AppColors.subtext),
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                          ),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(12),
                    ),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      itemBuilder: (context, index) {
                        final application = applications[index];
                        return _ApplicantEntry(
                          application: application,
                          onOpenInterview: () =>
                              _showInterviewResult(application, context),
                        );
                      },
                      separatorBuilder: (_, __) => const Divider(height: 24),
                      itemCount: applications.length,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({
    required this.post,
    required this.selected,
    required this.onTap,
    required this.service,
  });

  final JobPostRecord post;
  final bool selected;
  final VoidCallback onTap;
  final JobPostingService service;

  @override
  Widget build(BuildContext context) {
    final badgeColor = selected ? AppColors.mint : Colors.white;
    final textColor = selected ? Colors.black : AppColors.text;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 260,
        decoration: BoxDecoration(
          color: badgeColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : const Color(0xFFE5E5E5),
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 6),
            )
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              post.company,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              post.title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Row(
              children: [
                const Icon(Icons.people_outline, size: 18),
                const SizedBox(width: 6),
                StreamBuilder<int>(
                  stream: service.watchApplicationCount(post.id),
                  builder: (context, snapshot) {
                    final count = snapshot.data ?? post.applicantCount;
                    return Text('지원자 $count명');
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ApplicantEntry extends StatelessWidget {
  const _ApplicantEntry({
    required this.application,
    required this.onOpenInterview,
  });

  final JobApplicationRecord application;
  final VoidCallback onOpenInterview;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                application.applicantName,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
            Text(
              _formatDate(application.appliedAt),
              style: const TextStyle(color: AppColors.subtext),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _ActionButton(
              label: '이력서 다운로드',
              onPressed: application.resumeUrl == null
                  ? null
                  : () => _launchUrl(application.resumeUrl!),
            ),
            _ActionButton(
              label: '자기소개서 다운로드',
              onPressed: application.coverLetterUrl == null
                  ? null
                  : () => _launchUrl(application.coverLetterUrl!),
            ),
            _ActionButton(
              label: '면접 결과 보기',
              onPressed: onOpenInterview,
            ),
            _ActionButton(
              label: '최종 평가 보기',
              onPressed: onOpenInterview,
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SizedBox(
        height: 36,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF6C4CFF),
            minimumSize: const Size(70, 36),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          onPressed: onPressed,
          child: Text(label),
        ),
      ),
    );
  }
}

Future<void> _launchUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  if (!await canLaunchUrl(uri)) {
    return;
  }
  await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
}

void _showInterviewResult(
  JobApplicationRecord application,
  BuildContext context,
) {
  final videoUrl = application.interviewVideoUrl;
  final hasSummary = application.interviewSummary?.isNotEmpty ?? false;
  if (videoUrl == null && !hasSummary) {
    return;
  }

  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.insights_outlined, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${application.applicantName}님의 면접 결과',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (hasSummary) ...[
              const Text(
                'AI 요약',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                application.interviewSummary!,
                style: const TextStyle(color: AppColors.subtext),
              ),
              const SizedBox(height: 14),
            ],
            if (videoUrl != null)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _launchUrl(videoUrl),
                  icon: const Icon(Icons.play_circle_outline),
                  label: const Text('녹화 영상 열기'),
                ),
              ),
          ],
        ),
      );
    },
  );
}

String _formatDate(DateTime date) {
  return '${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

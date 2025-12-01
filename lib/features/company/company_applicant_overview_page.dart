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
      height: 170,
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

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            scrollDirection: Axis.horizontal,
            itemBuilder: (context, index) {
              final post = posts[index];
              final isSelected = post.id == selectedJob?.id;
              return _JobCard(
                post: post,
                selected: isSelected,
                service: service,
                onTap: () => onSelected(post),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemCount: posts.length,
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

        final applications = snapshot.data ?? const <JobApplicationRecord>[];
        if (applications.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('해당 공고에 접수된 지원 내역이 없습니다.'),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          itemBuilder: (context, index) {
            final application = applications[index];
            return _ApplicantTile(application: application);
          },
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemCount: applications.length,
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

class _ApplicantTile extends StatelessWidget {
  const _ApplicantTile({required this.application});

  final JobApplicationRecord application;

  @override
  Widget build(BuildContext context) {
    final statusLabel =
        JobApplicationStatus.labels[application.status] ?? application.status;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE9E9E9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
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
              _StatusPill(label: statusLabel),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${_formatDate(application.appliedAt)} · ${application.jobTitle.isNotEmpty ? application.jobTitle : '공고 확인'}',
            style: const TextStyle(color: AppColors.subtext),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _ActionChip(
                icon: Icons.description_outlined,
                label: '이력서/포트폴리오',
                onTap: application.resumeUrl == null
                    ? null
                    : () => _launchUrl(application.resumeUrl!, context),
              ),
              const SizedBox(width: 10),
              _ActionChip(
                icon: Icons.chat_bubble_outline,
                label: 'AI 질문 & 답변',
                onTap: application.memo?.isNotEmpty == true
                    ? () => _showMemo(context, application.memo!)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showMemo(BuildContext context, String memo) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('지원자 답변/메모'),
        content: Text(memo),
      ),
    );
  }

  Future<void> _launchUrl(String url, BuildContext context) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (!await canLaunchUrl(uri)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('링크를 열 수 없습니다.')),
        );
      }
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFFF3ECFF) : const Color(0xFFF5F5F7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: enabled ? const Color(0xFFB486FF) : const Color(0xFFE3E3E3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 18, color: enabled ? Colors.black : AppColors.subtext),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: enabled ? Colors.black : AppColors.subtext,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE7DDFF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF5B3AB2),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
}

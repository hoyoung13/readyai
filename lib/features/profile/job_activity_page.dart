import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../tabs/tabs_shared.dart';
import '../jobs/job_activity.dart';
import '../jobs/job_activity_service.dart';

class JobActivityPage extends StatelessWidget {
  const JobActivityPage({super.key});

  static final JobActivityService _service = JobActivityService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('스크랩/지원 내역'),
      ),
      backgroundColor: AppColors.bg,
      body: StreamBuilder<List<JobActivity>>(
        stream: _service.watchAll(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final activities = snapshot.data ?? const <JobActivity>[];
          if (activities.isEmpty) {
            return const _EmptyState();
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            itemBuilder: (context, index) {
              final activity = activities[index];
              return _JobActivityTile(activity: activity);
            },
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemCount: activities.length,
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: const [
            Icon(Icons.bookmark_border, size: 48, color: AppColors.subtext),
            SizedBox(height: 12),
            Text(
              '저장된 채용 공고가 없습니다.',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              '관심 있는 공고를 스크랩하거나 지원하면 이곳에서 확인할 수 있어요.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.subtext),
            ),
          ],
        ),
      ),
    );
  }
}

class _JobActivityTile extends StatelessWidget {
  const _JobActivityTile({required this.activity});

  final JobActivity activity;

  @override
  Widget build(BuildContext context) {
    final registration = activity.registrationDateLabel;
    final deadline = activity.applicationDeadlineLabel;
    final appliedAt = activity.appliedAtLabel;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.company,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.subtext,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      activity.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _launchUrl(context, activity.url),
                icon: const Icon(Icons.open_in_new, color: AppColors.subtext),
                tooltip: '상세 보기',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusChip(
                icon: Icons.place_outlined,
                label: activity.region,
                backgroundColor: const Color(0xFFF3F3F8),
                foregroundColor: AppColors.subtext,
              ),
              if (registration != null)
                _StatusChip(
                  icon: Icons.event_available_outlined,
                  label: '등록일 $registration',
                  backgroundColor: const Color(0xFFF3F3F8),
                  foregroundColor: AppColors.subtext,
                ),
              if (deadline != null)
                _StatusChip(
                  icon: Icons.hourglass_bottom,
                  label: '마감 $deadline',
                  backgroundColor: const Color(0xFFFDF3E3),
                  foregroundColor: const Color(0xFFB9782D),
                ),
              if (activity.scrapped)
                const _StatusChip(
                  icon: Icons.star,
                  label: '스크랩',
                  backgroundColor: Color(0xFFFFF3CD),
                  foregroundColor: Color(0xFF8F6B00),
                ),
              if (activity.applied)
                _StatusChip(
                  icon: Icons.task_alt,
                  label: appliedAt != null ? '지원 $appliedAt' : '지원 완료',
                  backgroundColor: const Color(0xFFE7F7EE),
                  foregroundColor: const Color(0xFF26734D),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _launchUrl(BuildContext context, String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('상세 링크가 제공되지 않았습니다.')),
      );
      return;
    }

    final launched =
        await launchUrlString(trimmed, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('상세 페이지를 열 수 없습니다.')),
      );
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foregroundColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: foregroundColor,
            ),
          ),
        ],
      ),
    );
  }
}
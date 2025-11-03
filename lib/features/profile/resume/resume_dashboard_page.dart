import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:ai/features/tabs/tabs_shared.dart';

class ResumeDashboardPage extends StatelessWidget {
  const ResumeDashboardPage({super.key});

  static const _profileSummary = ResumeProfileSummary(
    name: '부천대',
    description: '남자, 2025년생',
  );

  static final List<_ResumePreview> _samples = [
    _ResumePreview(
      title: '백엔드 지원 전용',
      status: ResumeCompletionStatus.completed,
      lastUpdated: DateTime(2024, 9, 26),
      isPublic: true,
    ),
    _ResumePreview(
      title: '이번에는 합격하자',
      status: ResumeCompletionStatus.inProgress,
      lastUpdated: DateTime(2024, 9, 23),
      isPublic: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('이력서'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.text,
        elevation: 0.5,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          ResumeProfileHeaderCard(summary: _profileSummary),
          const SizedBox(height: 18),
          ..._samples.map(
            (resume) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ResumePreviewTile(resume: resume),
            ),
          ),
          const SizedBox(height: 8),
          _ResumeActions(
            onCreate: () => context.push(
              '/profile/resume/new',
              extra: _profileSummary,
            ),
            onTemplates: () {},
          ),
        ],
      ),
    );
  }
}

class ResumeProfileSummary {
  const ResumeProfileSummary({
    required this.name,
    required this.description,
  });

  final String name;
  final String description;
}

enum ResumeCompletionStatus { completed, inProgress }

class _ResumePreview {
  const _ResumePreview({
    required this.title,
    required this.status,
    required this.lastUpdated,
    required this.isPublic,
  });

  final String title;
  final ResumeCompletionStatus status;
  final DateTime lastUpdated;
  final bool isPublic;

  String get formattedDate =>
      '${lastUpdated.month.toString().padLeft(2, '0')}-${lastUpdated.day.toString().padLeft(2, '0')}';
}

class ResumeProfileHeaderCard extends StatelessWidget {
  const ResumeProfileHeaderCard({required this.summary, super.key});

  final ResumeProfileSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF9B748), Color(0xFFED4C92)],
              ),
            ),
            child: const Icon(
              Icons.person_outline,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summary.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  summary.description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.subtext,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResumePreviewTile extends StatelessWidget {
  const _ResumePreviewTile({required this.resume});

  final _ResumePreview resume;

  @override
  Widget build(BuildContext context) {
    final statusLabel = resume.status == ResumeCompletionStatus.completed
        ? '작성 완료'
        : '작성 미완료';
    final statusColor = resume.status == ResumeCompletionStatus.completed
        ? const Color(0xFF6D5CFF)
        : AppColors.subtext;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE1E1E5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  resume.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 12,
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '수정일자 ${resume.formattedDate}',
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
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                '공개 여부',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.subtext,
                ),
              ),
              const SizedBox(height: 6),
              Icon(
                resume.isPublic
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: resume.isPublic ? const Color(0xFF6D5CFF) : AppColors.subtext,
                size: 20,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResumeActions extends StatelessWidget {
  const _ResumeActions({
    required this.onCreate,
    required this.onTemplates,
  });

  final VoidCallback onCreate;
  final VoidCallback onTemplates;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE1E1E5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('새 이력서 작성'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onTemplates,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF6D5CFF),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text('이력서 양식 보러가기'),
          ),
        ],
      ),
    );
  }
}
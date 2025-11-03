import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ai/features/profile/resume/data/resume_repository.dart';
import 'package:ai/features/profile/resume/models/resume.dart';
import 'package:ai/features/tabs/tabs_shared.dart';

class ResumeDashboardPage extends StatefulWidget {
  const ResumeDashboardPage({super.key});

  @override
  State<ResumeDashboardPage> createState() => _ResumeDashboardPageState();
}

class _ResumeDashboardPageState extends State<ResumeDashboardPage> {
  static const _profileSummary = ResumeProfileSummary(
    name: '부천대',
    description: '남자, 2025년생',
  );

  List<Resume> _resumes = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadResumes();
  }

  Future<void> _loadResumes() async {
    final repository = await ResumeRepository.instance();
    final resumes = await repository.fetchAll();
    if (!mounted) {
      return;
    }
    setState(() {
      _resumes = resumes;
      _isLoading = false;
    });
  }

  Future<void> _handleCreateResume() async {
    final saved = await context.push<bool>(
      '/profile/resume/new',
      extra: _profileSummary,
    );

    if (saved == true && mounted) {
      await _loadResumes();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이력서가 저장되었습니다.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget resumeListContent;
    if (_isLoading) {
      resumeListContent = const Center(child: CircularProgressIndicator());
    } else if (_resumes.isEmpty) {
      resumeListContent = const _ResumeEmptyState();
    } else {
      resumeListContent = Column(
        children: _resumes
            .map(
              (resume) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ResumePreviewTile(resume: resume),
              ),
            )
            .toList(),
      );
    }
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
          const ResumeProfileHeaderCard(summary: _profileSummary),
          const SizedBox(height: 18),
          resumeListContent,
          const SizedBox(height: 8),
          _ResumeActions(
            onCreate: _handleCreateResume,
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

  final Resume resume;

  @override
  Widget build(BuildContext context) {
    final statusLabel =
        resume.completionStatus == ResumeCompletionStatus.completed
            ? '작성 완료'
            : '작성 미완료';
    final statusColor =
        resume.completionStatus == ResumeCompletionStatus.completed
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
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
                const SizedBox(height: 8),
                if (resume.name.isNotEmpty || resume.phone.isNotEmpty)
                  Text(
                    '${resume.name}${resume.name.isNotEmpty && resume.phone.isNotEmpty ? ' · ' : ''}${resume.phone}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.subtext,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (resume.email.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      resume.email,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.subtext,
                      ),
                    ),
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
                color: resume.isPublic
                    ? const Color(0xFF6D5CFF)
                    : AppColors.subtext,
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

class _ResumeEmptyState extends StatelessWidget {
  const _ResumeEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE1E1E5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(
            Icons.description_outlined,
            color: AppColors.subtext,
            size: 40,
          ),
          SizedBox(height: 16),
          Text(
            '아직 등록된 이력서가 없어요.',
            style: TextStyle(
              fontSize: 15,
              color: AppColors.subtext,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../tabs/tabs_shared.dart';
import 'job_interview_question_service.dart';
import 'job_posting.dart';
import '../camera/interview_flow_launcher.dart';
import '../camera/interview_models.dart';
import '../camera/interview_question_bank.dart';

class JobDetailPage extends StatelessWidget {
  const JobDetailPage({required this.job, super.key});

  final JobPosting job;

  static final JobInterviewQuestionService _questionService =
      JobInterviewQuestionService();
  static const InterviewFlowLauncher _interviewLauncher =
      InterviewFlowLauncher();

  @override
  Widget build(BuildContext context) {
    final trimmedDescription = job.description.trim();
    final trimmedNotice = job.notice.trim();
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('채용공고 상세'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              job.companyLabel,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.subtext,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              job.title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoTag(
                  icon: Icons.place_outlined,
                  label: job.regionLabel,
                ),
                if (job.prettyPostedDate != null)
                  _InfoTag(
                    icon: Icons.event_note,
                    label: '${job.prettyPostedDate} 등록',
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _launchDetail(job.url, context),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('입사지원'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _handleStartInterview(context),
                    icon: const Icon(Icons.smart_toy_outlined),
                    label: const Text('면접 연습'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            _InfoBlock(
              title: '기본 정보',
              children: [
                _InfoRow(label: '기업명', value: job.companyLabel),
                _InfoRow(label: '근무지', value: job.regionLabel),
                _InfoRow(
                  label: '등록일',
                  value: job.prettyPostedDate ?? '정보 없음',
                ),
                _InfoRow(
                  label: '상세 링크',
                  value: job.hasUrl ? job.url : '제공되지 않음',
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (job.summaryItems.isNotEmpty)
              _InfoBlock(
                title: '채용 요약',
                children: job.summaryItems
                    .map(
                      (item) => _InfoRow(
                        label: item.label,
                        value: item.value,
                      ),
                    )
                    .toList(growable: false),
              ),
            if (job.summaryItems.isNotEmpty) const SizedBox(height: 20),
            if (trimmedDescription.isNotEmpty)
              _InfoBlock(
                title: '상세 설명',
                children: [
                  Text(
                    trimmedDescription,
                    style: const TextStyle(height: 1.5),
                  ),
                ],
              ),
            if (trimmedDescription.isNotEmpty) const SizedBox(height: 20),
            if (job.detailRows.isNotEmpty)
              _InfoBlock(
                title: '상세 정보',
                children: job.detailRows
                    .map(
                      (row) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              row.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              row.description,
                              style: const TextStyle(height: 1.5),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            if (job.detailRows.isNotEmpty) const SizedBox(height: 20),
            _InfoBlock(
              title: '안내',
              children: [
                Text(
                  trimmedNotice.isNotEmpty
                      ? trimmedNotice
                      : '본 정보는 공공데이터포털 "기획재정부_공공기관 채용정보 조회서비스"를 통해 수집되었습니다.',
                  style: const TextStyle(height: 1.5),
                ),
                if (trimmedNotice.isNotEmpty) const SizedBox(height: 8),
                if (trimmedNotice.isNotEmpty)
                  const Text(
                    '본 정보는 공공데이터포털 "기획재정부_공공기관 채용정보 조회서비스"를 통해 수집되었습니다.',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleStartInterview(BuildContext context) async {
    final category = JobCategory(
      title: job.companyLabel,
      subtitle: job.title,
    );

    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);
    var dialogOpen = true;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return const Center(child: CircularProgressIndicator());
      },
    );

    List<String> questions;
    try {
      questions = await _questionService.generateQuestions(job);
    } on JobInterviewQuestionException catch (error) {
      questions = InterviewQuestionBank.getQuestions(
        category: category,
        mode: InterviewMode.ai,
      );
      messenger
        ..removeCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('${error.message} 기본 질문으로 진행할게요.'),
          ),
        );
    } catch (_) {
      questions = InterviewQuestionBank.getQuestions(
        category: category,
        mode: InterviewMode.ai,
      );
      messenger
        ..removeCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('맞춤 질문을 준비하지 못했습니다. 기본 질문으로 진행할게요.'),
          ),
        );
    } finally {
      if (dialogOpen && rootNavigator.mounted) {
        rootNavigator.pop();
        dialogOpen = false;
      }
    }

    if (!context.mounted) {
      return;
    }

    await _interviewLauncher.launch(
      context: context,
      category: category,
      mode: InterviewMode.ai,
      questions: questions,
    );
  }

  void _launchDetail(String url, BuildContext context) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('상세 링크가 제공되지 않았습니다.')),
      );
      return;
    }

    final launched =
        await launchUrlString(trimmed, mode: LaunchMode.externalApplication);
    if (!launched) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('상세 페이지를 열 수 없습니다.')),
      );
    }
  }
}

class _InfoTag extends StatelessWidget {
  const _InfoTag({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.subtext),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.subtext,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

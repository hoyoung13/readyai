import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:ai/features/profile/resume/ai/resume_ai_models.dart';
import 'package:ai/features/profile/resume/models/resume.dart';
import 'package:ai/features/profile/resume/resume_ai_summary_page.dart';
import 'package:ai/features/profile/resume/cover_letter_proofread_page.dart';
import 'package:ai/features/tabs/tabs_shared.dart';

class ResumeAiReportPage extends StatelessWidget {
  const ResumeAiReportPage({
    required this.resume,
    required this.docKind,
    required this.report,
    required this.improvedVersion,
    this.extractedText,
    this.evaluatedAt,
    super.key,
  });

  final ResumeFile resume;
  final ResumeDocKind docKind;
  final EvaluationReport report;
  final String improvedVersion;
  final String? extractedText;
  final DateTime? evaluatedAt;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 평가 결과'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
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
                        resume.filename,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (evaluatedAt != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          '평가일: ${evaluatedAt!.toLocal()}',
                          style: const TextStyle(color: AppColors.subtext),
                        ),
                      ],
                    ],
                  ),
                ),
                _OverallScoreBadge(score: report.overallScore),
              ],
            ),
            const SizedBox(height: 16),
            _RubricGrid(scores: report.rubricScores),
            const SizedBox(height: 16),
            _SectionCard(
              title: '강점',
              child: _BulletList(items: report.strengths),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: '보완 필요',
              child: _BulletList(items: report.weaknesses),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: '액션 아이템',
              child: Column(
                children: report.actionableEdits
                    .map(
                      (e) => ListTile(
                        dense: true,
                        title: Text(e.section),
                        subtitle: Text('${e.issue}\n→ ${e.suggestion}'),
                      ),
                    )
                    .toList(),
              ),
            ),
            if (report.redFlags.isNotEmpty) ...[
              const SizedBox(height: 12),
              _SectionCard(
                title: '리스크',
                child: _BulletList(items: report.redFlags),
              ),
            ],
            const SizedBox(height: 12),
            _SectionCard(
              title: '요약',
              child: Text(
                report.summary,
                style: const TextStyle(fontSize: 15, height: 1.5),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                if (extractedText == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('요약을 위해 문서를 다시 불러옵니다.')),
                  );
                }
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ResumeAiSummaryPage(
                      resume: resume,
                      docKind: docKind,
                      extractedText: extractedText,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.summarize),
              label: const Text('자동 요약 보기'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: improvedVersion));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('개선본이 복사되었습니다.')),
                );
              },
              icon: const Icon(Icons.copy_all),
              label: const Text('개선본 보기/복사'),
            ),
            const SizedBox(height: 12),
            if (docKind == ResumeDocKind.coverLetter)
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CoverLetterProofreadPage(
                        resume: resume,
                        docKind: docKind,
                        extractedText: extractedText,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.edit_note_outlined),
                label: const Text('자기소개서 첨삭'),
              ),
            const SizedBox(height: 24),
            _SectionCard(
              title: '개선본',
              child: Text(
                improvedVersion,
                style: const TextStyle(fontSize: 15, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverallScoreBadge extends StatelessWidget {
  const _OverallScoreBadge({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Text('총점',
              style: TextStyle(fontSize: 12, color: AppColors.subtext)),
          const SizedBox(height: 4),
          Text(
            '$score',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _RubricGrid extends StatelessWidget {
  const _RubricGrid({required this.scores});

  final RubricScores scores;

  @override
  Widget build(BuildContext context) {
    final data = [
      ('가독성', scores.readability),
      ('임팩트', scores.impact),
      ('구조', scores.structure),
      ('구체성', scores.specificity),
      ('직무 적합성', scores.roleFit),
    ];
    return GridView.builder(
      shrinkWrap: true,
      itemCount: data.length,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 78,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (_, idx) =>
          _RubricCard(title: data[idx].$1, score: data[idx].$2),
    );
  }
}

class _RubricCard extends StatelessWidget {
  const _RubricCard({required this.title, required this.score});

  final String title;
  final int score;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          Text(
            '$score',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _BulletList extends StatelessWidget {
  const _BulletList({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Text('해당 사항이 없습니다.',
          style: TextStyle(color: AppColors.subtext));
    }
    return Column(
      children: items
          .map(
            (e) => Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• '),
                Expanded(
                  child: Text(
                    e,
                    style: const TextStyle(height: 1.4),
                  ),
                ),
              ],
            ),
          )
          .toList(),
    );
  }
}

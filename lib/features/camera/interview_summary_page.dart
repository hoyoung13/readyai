import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:printing/printing.dart';
import 'package:ai/features/camera/interview_models.dart';
import 'package:ai/features/tabs/tabs_shared.dart';

enum InterviewSummaryResult { none, retry }

class InterviewSummaryPageArgs {
  const InterviewSummaryPageArgs({
    required this.result,
    required this.category,
    required this.mode,
  });

  final InterviewRecordingResult result;
  final JobCategory category;
  final InterviewMode mode;
}

class InterviewSummaryPage extends StatefulWidget {
  const InterviewSummaryPage({super.key, required this.args});

  final InterviewSummaryPageArgs args;

  @override
  State<InterviewSummaryPage> createState() => _InterviewSummaryPageState();
}

class _InterviewSummaryPageState extends State<InterviewSummaryPage> {
  bool _isSavingPdf = false;

  @override
  Widget build(BuildContext context) {
    final result = widget.args.result;
    final score = result.score;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('면접 결과 리포트'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.text,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 140),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SummaryHeader(
                category: widget.args.category,
                mode: widget.args.mode,
                score: score,
                filePath: result.filePath,
              ),
              if (result.hasTranscriptionError || result.hasEvaluationError)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: _ErrorBanner(result: result),
                ),
              if (score != null)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: _ScoreBreakdown(score: score),
                ),
              if (score == null && result.evaluationError == null)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: _PlaceholderCard(
                    title: '평가 결과를 불러오지 못했습니다.',
                    description: '다시 시도하면 결과를 확인할 수 있습니다.',
                  ),
                ),
              if (result.transcript != null &&
                  result.transcript!.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: _TranscriptSection(
                    transcript: result.transcript!,
                    confidence: result.transcriptConfidence,
                  ),
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(24),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.mint,
                  foregroundColor: AppColors.text,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16),
                ),
                onPressed: () =>
                    Navigator.of(context).pop(InterviewSummaryResult.retry),
                child: const Text('다시 연습'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: AppColors.mint, width: 1.4),
                  foregroundColor: AppColors.text,
                  textStyle: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16),
                ),
                onPressed: _isSavingPdf ? null : _handleSavePdf,
                child: _isSavingPdf
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      )
                    : const Text('PDF 저장'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSavePdf() async {
    setState(() => _isSavingPdf = true);

    try {
      final result = widget.args.result;
      final score = result.score;

      final doc = pw.Document();
      final fontRegular = await PdfGoogleFonts.notoSansKRRegular();
      final fontBold = await PdfGoogleFonts.notoSansKRBold();

      doc.addPage(
        pw.MultiPage(
          pageTheme: pw.PageTheme(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(32),
            theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
          ),
          build: (context) {
            return [
              pw.Text(
                '면접 결과 리포트',
                style:
                    pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 12),
              pw.Text('직무 카테고리: ${widget.args.category.title}'),
              pw.Text('면접 유형: ${widget.args.mode.title}'),
              pw.Text('녹화 파일: ${result.filePath}'),
              pw.SizedBox(height: 16),
              if (score != null) ...[
                pw.Text(
                  '종합 점수: ${score.overallScore.toStringAsFixed(1)}점',
                  style: pw.TextStyle(
                      fontSize: 18, fontWeight: pw.FontWeight.bold),
                ),
                if (score.perQuestionFeedback.isNotEmpty) ...[
                  pw.SizedBox(height: 12),
                  pw.Text('문항별 피드백',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 6),
                  ...score.perQuestionFeedback.map((feedback) {
                    return pw.Container(
                      margin: const pw.EdgeInsets.only(bottom: 10),
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        border:
                            pw.Border.all(color: PdfColors.grey400, width: 0.8),
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          if (feedback.question.trim().isNotEmpty)
                            pw.Text(
                              feedback.question,
                              style:
                                  pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            ),
                          if (feedback.score != null)
                            pw.Text(
                                '점수: ${feedback.score!.toStringAsFixed(1)}점'),
                          if (feedback.feedback.trim().isNotEmpty) ...[
                            pw.SizedBox(height: 4),
                            pw.Text(feedback.feedback),
                          ],
                        ],
                      ),
                    );
                  }),
                ],
              ] else if (result.evaluationError != null) ...[
                pw.Text(
                  '평가 결과 오류',
                  style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.red),
                ),
                pw.SizedBox(height: 4),
                pw.Text(result.evaluationError!),
              ],
              if (result.transcriptionError != null) ...[
                pw.SizedBox(height: 16),
                pw.Text(
                  '전사 오류',
                  style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.red),
                ),
                pw.SizedBox(height: 4),
                pw.Text(result.transcriptionError!),
              ],
              if (result.transcript != null &&
                  result.transcript!.trim().isNotEmpty) ...[
                pw.SizedBox(height: 16),
                pw.Text(
                  '전사 내용',
                  style: pw.TextStyle(
                      fontSize: 18, fontWeight: pw.FontWeight.bold),
                ),
                if (result.transcriptConfidence != null)
                  pw.Text(
                    '신뢰도: ${(result.transcriptConfidence!.clamp(0, 1) * 100).toStringAsFixed(0)}%',
                  ),
                pw.SizedBox(height: 6),
                pw.Text(result.transcript!),
              ],
            ];
          },
        ),
      );

      final now = DateTime.now();
      final timestamp =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';

      final bytes = await doc.save();
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'interview-report-$timestamp.pdf',
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('PDF 저장 중 오류가 발생했습니다. 다시 시도해 주세요.'),
          ),
        );
    } finally {
      if (!mounted) return;
      setState(() => _isSavingPdf = false);
    }
  }
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({
    required this.category,
    required this.mode,
    required this.filePath,
    this.score,
  });

  final JobCategory category;
  final InterviewMode mode;
  final InterviewScore? score;
  final String filePath;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '총점',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.subtext,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            score != null
                ? '${score!.overallScore.toStringAsFixed(1)}점'
                : '평가 대기 중',
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _InfoPill(label: '카테고리', value: category.title),
              _InfoPill(label: '면접 유형', value: mode.title),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 16),
          const Text(
            '녹화 파일 위치',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          SelectableText(
            filePath,
            style: const TextStyle(fontSize: 13, color: AppColors.subtext),
          ),
        ],
      ),
    );
  }
}

class _ScoreBreakdown extends StatelessWidget {
  const _ScoreBreakdown({required this.score});

  final InterviewScore score;

  @override
  Widget build(BuildContext context) {
    if (score.perQuestionFeedback.isEmpty) {
      return _PlaceholderCard(
        title: '문항별 피드백이 제공되지 않았습니다.',
        description: '조금 뒤에 다시 확인해 보거나 재평가를 시도해 보세요.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '문항별 피드백',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 16),
        ...score.perQuestionFeedback.map(
          (feedback) {
            final scoreValue = (feedback.score ?? 0).clamp(0, 100);
            final normalized = (scoreValue / 100).toDouble();
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (feedback.question.trim().isNotEmpty)
                    Text(
                      feedback.question,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  if (feedback.score != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: normalized,
                              minHeight: 8,
                              backgroundColor: const Color(0xFFEAEAEA),
                              valueColor:
                                  const AlwaysStoppedAnimation(AppColors.mint),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text('${feedback.score!.toStringAsFixed(1)}점'),
                      ],
                    ),
                  ],
                  if (feedback.feedback.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      feedback.feedback,
                      style: const TextStyle(height: 1.4),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _TranscriptSection extends StatelessWidget {
  const _TranscriptSection({required this.transcript, this.confidence});

  final String transcript;
  final double? confidence;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '전사 내용',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        if (confidence != null) ...[
          const SizedBox(height: 8),
          Text(
            '신뢰도: ${(confidence!.clamp(0, 1) * 100).toStringAsFixed(0)}%',
            style: const TextStyle(color: AppColors.subtext, fontSize: 13),
          ),
        ],
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: SelectableText(
            transcript,
            style: const TextStyle(height: 1.5),
          ),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.result});

  final InterviewRecordingResult result;

  @override
  Widget build(BuildContext context) {
    final errors = [
      if (result.transcriptionError != null) result.transcriptionError!,
      if (result.evaluationError != null) result.evaluationError!,
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFC4C0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.error_outline, color: Colors.redAccent),
              SizedBox(width: 8),
              Text(
                '확인이 필요한 항목이 있어요',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.redAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...errors.map(
            (message) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                message,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(999),
      ),
      child: RichText(
        text: TextSpan(
          text: '$label  ',
          style: const TextStyle(color: AppColors.subtext, fontSize: 13),
          children: [
            TextSpan(
              text: value,
              style: const TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderCard extends StatelessWidget {
  const _PlaceholderCard({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
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
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(color: AppColors.subtext, height: 1.4),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:ai/features/camera/services/azure_face_service.dart';
import 'package:ai/features/camera/services/interview_video_storage_service.dart';
import 'package:printing/printing.dart';
import 'package:ai/features/camera/interview_models.dart';
import 'package:ai/features/profile/interview_video_page.dart';
import 'package:ai/features/tabs/tabs_shared.dart';
import 'package:ai/features/profile/models/interview_folder.dart';
import 'package:ai/features/profile/models/interview_record.dart';

enum InterviewSummaryResult { none, retry }

class InterviewSummaryPageArgs {
  const InterviewSummaryPageArgs({
    required this.result,
    required this.category,
    required this.mode,
    this.questions = const [],
    this.recordId,
    this.shouldPersist = true,
    this.practiceName,
    this.comparisonRecord,
  });

  final InterviewRecordingResult result;
  final JobCategory category;
  final InterviewMode mode;
  final List<String> questions;
  final String? recordId;
  final bool shouldPersist;
  final String? practiceName;
  final InterviewRecord? comparisonRecord;
}

class InterviewSummaryPage extends StatefulWidget {
  const InterviewSummaryPage({super.key, required this.args});

  final InterviewSummaryPageArgs args;

  @override
  State<InterviewSummaryPage> createState() => _InterviewSummaryPageState();
}

class _InterviewSummaryPageState extends State<InterviewSummaryPage> {
  bool _isSavingPdf = false;
  late InterviewRecordingResult _result;
  final InterviewVideoStorageService _videoStorageService =
      InterviewVideoStorageService();
  InterviewFolder? _selectedFolder;
  String? _practiceName;
  bool _isPersistingResult = false;
  @override
  void initState() {
    super.initState();
    _result = widget.args.result;
    _practiceName = widget.args.practiceName;
  }

  Future<void> _persistResultIfNeeded() async {
    if (!widget.args.shouldPersist || _isPersistingResult) {
      return;
    }
    _updatePersistingState(true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _updatePersistingState(false);

      return;
    }

    final interviewsCollection = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('interviews');
    final categoryKey = buildCategoryKey(widget.args.category);
    var resultToPersist = _result;

    if (_result.videoUrl == null && _result.filePath.isNotEmpty) {
      try {
        final uploaded = await _videoStorageService.uploadVideo(
          localFilePath: _result.filePath,
          userId: user.uid,
          categoryKey: categoryKey,
        );
        resultToPersist = resultToPersist.copyWith(
          videoUrl: uploaded.downloadUrl,
          videoStoragePath: uploaded.storagePath,
        );
      } on InterviewVideoUploadException catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..removeCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text(error.message)),
            );
        }
      }
    }

    final userDoc = interviewsCollection.parent;
    if (userDoc == null) {
      _updatePersistingState(false);

      return;
    }
    final selection = await _selectFolderAndName(userDoc);
    if (selection == null) {
      _updatePersistingState(false);

      return;
    }

    final folder = selection.folder;
    final folderRef = userDoc.collection('interviewFolders').doc(folder.id);
    final folderDoc = await folderRef.get();
    if (!folderDoc.exists) {
      await folderRef.set({
        'categoryKey': categoryKey,
        'category': widget.args.category.toMap(),
        'defaultName': folder.defaultName,
        'customName': folder.customName,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await folderRef.update({
        'category': widget.args.category.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    final payload = {
      'category': widget.args.category.toMap(),
      'mode': widget.args.mode.name,
      'questions': widget.args.questions,
      'categoryKey': categoryKey,
      'folderId': folder.id,
      'practiceName': selection.practiceName,
      'result': resultToPersist.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      await interviewsCollection.add(payload);
      if (mounted) {
        setState(() {
          _result = resultToPersist;
          _selectedFolder = folder;
          _practiceName = selection.practiceName;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('면접 결과를 저장하지 못했습니다. 네트워크를 확인해 주세요.'),
            ),
          );
      }
    } finally {
      _updatePersistingState(false);
    }
  }

  void _updatePersistingState(bool value) {
    if (!mounted) {
      _isPersistingResult = value;
      return;
    }
    setState(() {
      _isPersistingResult = value;
    });
  }

  Future<_FolderSelectionResult?> _selectFolderAndName(
    DocumentReference<Map<String, dynamic>> userDoc,
  ) async {
    final folderCollection = userDoc.collection('interviewFolders');
    final snapshot =
        await folderCollection.orderBy('updatedAt', descending: true).get();
    final folders = snapshot.docs.map(InterviewFolder.fromDoc).toList();

    if (!mounted) {
      return null;
    }

    return showModalBottomSheet<_FolderSelectionResult>(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      isDismissible: false,
      builder: (context) {
        return _FolderSelectionSheet(
          initialFolders: folders,
          initialFolderId: _selectedFolder?.id ??
              (folders.isNotEmpty ? folders.first.id : null),
          initialPracticeName:
              _practiceName ?? '${widget.args.category.title} 연습',
          onCreateFolder: (name) async {
            final newFolderRef = folderCollection.doc();
            await newFolderRef.set({
              'categoryKey': buildCategoryKey(widget.args.category),
              'category': widget.args.category.toMap(),
              'defaultName': name,
              'customName': null,
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
            return InterviewFolder(
              id: newFolderRef.id,
              category: widget.args.category,
              defaultName: name,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
          },
        );
      },
    );
  }

  List<String> _buildComparisonStrengths(InterviewRecord previous) {
    return _buildComparisonMessages(previous, isImprovement: true);
  }

  List<String> _buildComparisonFocusPoints(InterviewRecord previous) {
    return _buildComparisonMessages(previous, isImprovement: false);
  }

  List<String> _buildComparisonMessages(
    InterviewRecord previous, {
    required bool isImprovement,
  }) {
    final current = _result;
    final messages = <String>[];
    final currentScore = current.score?.overallScore;
    final previousScore = previous.result.score?.overallScore;

    if (currentScore != null && previousScore != null) {
      final diff = currentScore - previousScore;
      if (isImprovement) {
        if (diff > 0.2) {
          messages.add(
            '총점이 ${previousScore.toStringAsFixed(1)}점에서 '
            '${currentScore.toStringAsFixed(1)}점으로 ${diff.toStringAsFixed(1)}점 상승했어요.',
          );
        } else if (diff.abs() <= 0.2) {
          messages.add(
            '총점이 ${currentScore.toStringAsFixed(1)}점으로 안정적으로 유지되고 있어요.',
          );
        }
      } else if (diff < -0.2) {
        messages.add(
          '총점이 ${previousScore.toStringAsFixed(1)}점에서 '
          '${currentScore.toStringAsFixed(1)}점으로 ${diff.abs().toStringAsFixed(1)}점 낮아졌어요.',
        );
      }
    } else if (isImprovement && currentScore != null) {
      messages.add('이번 면접 총점은 ${currentScore.toStringAsFixed(1)}점이에요.');
    }

    final currentFeedbacks =
        current.score?.perQuestionFeedback ?? const <QuestionFeedback>[];
    final previousFeedbacks = previous.result.score?.perQuestionFeedback ??
        const <QuestionFeedback>[];
    final previousByQuestion = {
      for (final feedback in previousFeedbacks)
        if (feedback.question.isNotEmpty && feedback.score != null)
          feedback.question: feedback.score!
    };

    final diffs = <_QuestionDiff>[];
    for (final feedback in currentFeedbacks) {
      if (feedback.question.isEmpty || feedback.score == null) {
        continue;
      }
      final prevScore = previousByQuestion[feedback.question];
      if (prevScore == null) {
        continue;
      }
      final diff = feedback.score! - prevScore;
      if (isImprovement && diff > 0.3) {
        diffs.add(
          _QuestionDiff(
            question: feedback.question,
            difference: diff,
            score: feedback.score!,
            feedback: feedback.feedback,
          ),
        );
      } else if (!isImprovement && diff < -0.3) {
        diffs.add(
          _QuestionDiff(
            question: feedback.question,
            difference: diff,
            score: feedback.score!,
            feedback: feedback.feedback,
          ),
        );
      }
    }

    if (isImprovement) {
      diffs.sort((a, b) => b.difference.compareTo(a.difference));
      if (diffs.isNotEmpty) {
        final top = diffs.first;
        messages.add(
          '"${top.question}" 질문에서 ${top.difference.toStringAsFixed(1)}점 향상되어 '
          '${top.score.toStringAsFixed(1)}점을 기록했어요.',
        );
        if (top.feedback.trim().isNotEmpty) {
          messages.add('피드백: ${top.feedback}');
        }
      } else {
        final sorted = currentFeedbacks
            .where((element) => element.score != null)
            .toList()
          ..sort((a, b) => b.score!.compareTo(a.score!));
        if (sorted.isNotEmpty) {
          final best = sorted.first;
          messages.add(
            '"${best.question}" 질문은 ${best.score!.toStringAsFixed(1)}점으로 안정적이에요.',
          );
          if (best.feedback.trim().isNotEmpty) {
            messages.add('피드백: ${best.feedback}');
          }
        }
      }
    } else {
      diffs.sort((a, b) => a.difference.compareTo(b.difference));
      if (diffs.isNotEmpty) {
        final weakest = diffs.first;
        messages.add(
          '"${weakest.question}" 질문은 ${weakest.difference.abs().toStringAsFixed(1)}점 낮아져 '
          '${weakest.score.toStringAsFixed(1)}점이에요.',
        );
        if (weakest.feedback.trim().isNotEmpty) {
          messages.add('피드백: ${weakest.feedback}');
        }
      } else if (currentFeedbacks.isNotEmpty) {
        final lowest = currentFeedbacks
            .where((element) => element.score != null)
            .toList()
          ..sort((a, b) => a.score!.compareTo(b.score!));
        if (lowest.isNotEmpty) {
          final weakest = lowest.first;
          messages.add(
            '"${weakest.question}" 질문은 ${weakest.score!.toStringAsFixed(1)}점으로 추가 연습이 필요해요.',
          );
          if (weakest.feedback.trim().isNotEmpty) {
            messages.add('피드백: ${weakest.feedback}');
          }
        }
      }
    }
    if (messages.isEmpty) {
      messages.add(
        isImprovement
            ? '아직 비교할 데이터가 부족해요. 다음 연습에서도 기록을 남겨 보세요.'
            : '감소한 항목이 없어요. 현재 흐름을 유지해 보세요.',
      );
    }

    return messages;
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final score = result.score;
    final practiceName = _practiceName;
    final comparisonRecord = widget.args.comparisonRecord;

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
                result: result,
                practiceName: practiceName,
              ),
              if (widget.args.questions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: _QuestionListSection(
                    questions: widget.args.questions,
                  ),
                ),
              if (result.hasError)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: _ErrorBanner(result: result),
                ),
              if (score != null)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: _ScoreBreakdown(score: score),
                ),
              if (comparisonRecord != null)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: _ComparisonSection(
                    previousRecord: comparisonRecord,
                    currentResult: result,
                    strengths: _buildComparisonStrengths(comparisonRecord),
                    focusPoints: _buildComparisonFocusPoints(comparisonRecord),
                  ),
                ),
              if (score == null && result.evaluationError == null)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: _PlaceholderCard(
                    title: '평가 결과를 불러오지 못했습니다.',
                    description: '다시 시도하면 결과를 확인할 수 있습니다.',
                  ),
                ),
              if (result.faceAnalysis != null)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: _FaceAnalysisSection(result: result.faceAnalysis!),
                ),
              if (result.faceAnalysis == null &&
                  result.faceAnalysisError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: _PlaceholderCard(
                    title: '시선·표정 분석 결과를 확인할 수 없어요.',
                    description: result.faceAnalysisError!,
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.args.shouldPersist) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.mint,
                    foregroundColor: AppColors.text,
                    disabledBackgroundColor: AppColors.mint.withOpacity(0.4),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  onPressed: (_isPersistingResult || _selectedFolder != null)
                      ? null
                      : () {
                          unawaited(_persistResultIfNeeded());
                        },
                  child: _isPersistingResult
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        )
                      : Text(_selectedFolder != null ? '저장 완료' : '결과 저장'),
                ),
              ),
              if (_selectedFolder != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${_selectedFolder!.displayName}에 저장됨',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
            ],
            Row(
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
              if (_practiceName != null && _practiceName!.trim().isNotEmpty)
                pw.Text('연습 이름: ${_practiceName!.trim()}'),
              pw.Text('녹화 파일: ${result.filePath}'),
              pw.SizedBox(height: 16),
              if (widget.args.questions.isNotEmpty) ...[
                pw.Text(
                  '면접 질문',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 6),
                ...widget.args.questions.asMap().entries.map(
                      (entry) => pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 4),
                        child: pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('${entry.key + 1}. ',
                                style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold)),
                            pw.Expanded(child: pw.Text(entry.value)),
                          ],
                        ),
                      ),
                    ),
                pw.SizedBox(height: 12),
              ],
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
              if (result.faceAnalysis != null) ...[
                pw.SizedBox(height: 16),
                pw.Text(
                  '시선 분석',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(result.faceAnalysis!.feedback),
              ] else if (result.faceAnalysisError != null) ...[
                pw.SizedBox(height: 16),
                pw.Text(
                  '시선 분석 오류',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.red,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(result.faceAnalysisError!),
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
    required this.result,
    this.score,
    this.practiceName,
  });

  final JobCategory category;
  final InterviewMode mode;
  final InterviewScore? score;
  final InterviewRecordingResult result;
  final String? practiceName;

  @override
  Widget build(BuildContext context) {
    final videoUrl = result.videoUrl;
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
              if (category.subtitle.trim().isNotEmpty)
                _InfoPill(label: '지원 직무', value: category.subtitle),
              _InfoPill(label: '면접 유형', value: mode.title),
              if (practiceName != null && practiceName!.trim().isNotEmpty)
                _InfoPill(label: '연습 이름', value: practiceName!.trim()),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 16),
          /*const Text(
            '녹화 파일 위치',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          SelectableText(
            filePath,
            style: const TextStyle(fontSize: 13, color: AppColors.subtext),
          ),*/
          if (videoUrl != null)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  context.push(
                    '/profile/history/video',
                    extra: InterviewVideoPageArgs(
                      videoUrl: videoUrl,
                      title: '${category.title} · ${mode.title}',
                    ),
                  );
                },
                icon: const Icon(Icons.play_circle_outline),
                label: const Text('녹화 영상 보기'),
              ),
            ),
        ],
      ),
    );
  }
}

class _ComparisonSection extends StatelessWidget {
  const _ComparisonSection({
    required this.previousRecord,
    required this.currentResult,
    required this.strengths,
    required this.focusPoints,
  });

  final InterviewRecord previousRecord;
  final InterviewRecordingResult currentResult;
  final List<String> strengths;
  final List<String> focusPoints;

  @override
  Widget build(BuildContext context) {
    final previousScore = previousRecord.result.score?.overallScore;
    final currentScore = currentResult.score?.overallScore;

    if (previousScore == null || currentScore == null) {
      return _PlaceholderCard(
        title: '비교 결과를 계산할 수 없어요.',
        description: '두 기록 모두 평가가 완료된 후 다시 시도해 주세요.',
      );
    }

    final diff = currentScore - previousScore;
    final diffLabel = diff >= 0
        ? '+${diff.toStringAsFixed(1)}점'
        : '${diff.toStringAsFixed(1)}점';
    final previousName = (previousRecord.practiceName != null &&
            previousRecord.practiceName!.trim().isNotEmpty)
        ? previousRecord.practiceName!
        : '${previousRecord.category.title} · '
            '${_formatRecordDate(previousRecord.createdAt)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '선택한 기록과 비교',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                previousName,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '총점 ${previousScore.toStringAsFixed(1)}점 → '
                '${currentScore.toStringAsFixed(1)}점 ($diffLabel)',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        if (strengths.isNotEmpty)
          _ComparisonListCard(
            title: '좋아진 점',
            items: strengths,
            icon: Icons.trending_up,
            color: AppColors.mint,
          ),
        if (focusPoints.isNotEmpty)
          _ComparisonListCard(
            title: '보완할 점',
            items: focusPoints,
            icon: Icons.flag_outlined,
            color: const Color(0xFFFF7A7A),
          ),
      ],
    );
  }
}

class _ComparisonListCard extends StatelessWidget {
  const _ComparisonListCard({
    required this.title,
    required this.items,
    required this.icon,
    required this.color,
  });

  final String title;
  final List<String> items;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
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
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map(
            (message) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '• $message',
                style: const TextStyle(height: 1.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FolderSelectionResult {
  const _FolderSelectionResult({
    required this.folder,
    required this.practiceName,
  });

  final InterviewFolder folder;
  final String practiceName;
}

class _FolderSelectionSheet extends StatefulWidget {
  const _FolderSelectionSheet({
    required this.initialFolders,
    required this.onCreateFolder,
    this.initialFolderId,
    this.initialPracticeName,
  });

  final List<InterviewFolder> initialFolders;
  final Future<InterviewFolder> Function(String name) onCreateFolder;
  final String? initialFolderId;
  final String? initialPracticeName;

  @override
  State<_FolderSelectionSheet> createState() => _FolderSelectionSheetState();
}

class _FolderSelectionSheetState extends State<_FolderSelectionSheet> {
  late final TextEditingController _practiceNameController;
  late List<InterviewFolder> _folders;
  String? _selectedFolderId;
  bool _isCreatingFolder = false;

  @override
  void initState() {
    super.initState();
    _folders = List.of(widget.initialFolders);
    _selectedFolderId = widget.initialFolderId ??
        (widget.initialFolders.isNotEmpty
            ? widget.initialFolders.first.id
            : null);
    _practiceNameController =
        TextEditingController(text: widget.initialPracticeName ?? '');
  }

  @override
  void dispose() {
    _practiceNameController.dispose();
    super.dispose();
  }

  bool get _canConfirm {
    final practiceName = _practiceNameController.text.trim();
    return !_isCreatingFolder &&
        practiceName.isNotEmpty &&
        _selectedFolderId != null &&
        _folders.any((folder) => folder.id == _selectedFolderId);
  }

  Future<void> _handleCreateFolder() async {
    final controller = TextEditingController();
    final newName = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('새 폴더 만들기'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: '폴더 이름을 입력하세요.'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('만들기'),
            ),
          ],
        );
      },
    );
    controller.dispose();

    if (newName == null || newName.trim().isEmpty) {
      return;
    }

    setState(() => _isCreatingFolder = true);
    try {
      final folder = await widget.onCreateFolder(newName.trim());
      if (!mounted) {
        return;
      }
      setState(() {
        _folders.insert(0, folder);
        _selectedFolderId = folder.id;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('폴더를 만들지 못했습니다. 다시 시도해 주세요.')),
        );
    } finally {
      if (mounted) {
        setState(() => _isCreatingFolder = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return FractionallySizedBox(
      heightFactor: 0.9,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: media.viewInsets.bottom + 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '폴더 선택',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('나중에'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _folders.isEmpty
                    ? const Center(
                        child: Text(
                          '아직 폴더가 없습니다. 아래 버튼으로 새 폴더를 만들어 주세요.',
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.builder(
                        itemCount: _folders.length,
                        itemBuilder: (context, index) {
                          final folder = _folders[index];
                          return RadioListTile<String>(
                            value: folder.id,
                            groupValue: _selectedFolderId,
                            onChanged: (value) {
                              setState(() => _selectedFolderId = value);
                            },
                            title: Text(folder.displayName),
                            subtitle: Text(folder.category.title),
                          );
                        },
                      ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _isCreatingFolder ? null : _handleCreateFolder,
                  icon: const Icon(Icons.create_new_folder_outlined),
                  label: const Text('새 폴더 만들기'),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _practiceNameController,
                decoration: const InputDecoration(
                  labelText: '이번 연습 이름',
                  hintText: '예: 3차 실전 대비',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _canConfirm
                      ? () {
                          final folder = _folders.firstWhere(
                              (element) => element.id == _selectedFolderId);
                          Navigator.of(context).pop(
                            _FolderSelectionResult(
                              folder: folder,
                              practiceName: _practiceNameController.text.trim(),
                            ),
                          );
                        }
                      : null,
                  child: const Text('저장하기'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuestionDiff {
  _QuestionDiff({
    required this.question,
    required this.difference,
    required this.score,
    required this.feedback,
  });

  final String question;
  final double difference;
  final double score;
  final String feedback;
}

String _formatRecordDate(DateTime date) {
  final y = date.year.toString();
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  final hh = date.hour.toString().padLeft(2, '0');
  final mm = date.minute.toString().padLeft(2, '0');
  return '$y.$m.$d $hh:$mm';
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

class _QuestionListSection extends StatelessWidget {
  const _QuestionListSection({required this.questions});

  final List<String> questions;

  @override
  Widget build(BuildContext context) {
    if (questions.isEmpty) {
      return const SizedBox.shrink();
    }

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
          const Text(
            '면접 질문',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(questions.length, (index) {
            final question = questions[index];
            return Padding(
              padding: EdgeInsets.only(
                  bottom: index == questions.length - 1 ? 0 : 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${index + 1}.',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.mint,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      question,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _FaceAnalysisSection extends StatelessWidget {
  const _FaceAnalysisSection({required this.result});

  final FaceAnalysisResult result;

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
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '시선 분석',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.visibility_outlined, color: AppColors.mint),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  result.feedback,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
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
      if (result.faceAnalysisError != null) result.faceAnalysisError!,
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

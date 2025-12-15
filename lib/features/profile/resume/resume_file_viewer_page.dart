import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdfx/pdfx.dart';
import 'package:ai/features/profile/resume/ai/resume_ai_models.dart';
import 'package:ai/features/profile/resume/data/resume_repository.dart';
import 'package:ai/features/profile/resume/models/resume.dart';
import 'package:ai/features/profile/resume/resume_ai_report_page.dart';
import 'package:ai/features/tabs/tabs_shared.dart';

class ResumeFileViewerPage extends StatefulWidget {
  const ResumeFileViewerPage({required this.resume, super.key});

  final ResumeFile resume;

  @override
  State<ResumeFileViewerPage> createState() => _ResumeFileViewerPageState();
}

class _ResumeFileViewerPageState extends State<ResumeFileViewerPage> {
  final _repository = ResumeRepository.instance();
  PdfControllerPinch? _controller;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isEvaluating = false;
  ProcessedDocumentResult? _processed;
  ResumeAiMetadata? _aiMetadata;
  late ResumeDocKind _docKind;

  @override
  void initState() {
    super.initState();
    _docKind = widget.resume.docKind;
    _aiMetadata = widget.resume.ai;
    if (widget.resume.fileType == ResumeFileType.pdf) {
      _loadPdf();
    } else {
      _isLoading = false;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _loadPdf() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.get(Uri.parse(widget.resume.url));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        throw Exception('파일을 불러오지 못했습니다.');
      }
      final document = PdfDocument.openData(response.bodyBytes);
      _controller?.dispose();
      _controller = PdfControllerPinch(document: document);
    } catch (_) {
      _errorMessage = '파일을 불러오지 못했습니다';
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _openExistingReport() {
    final ai = _aiMetadata;
    if (ai == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResumeAiReportPage(
          resume: widget.resume,
          docKind: _docKind,
          report: EvaluationReport.fromJson(ai.reportJson),
          improvedVersion: ai.improvedVersion,
          evaluatedAt: ai.evaluatedAt,
          extractedText: _processed?.extractedText,
        ),
      ),
    );
  }

  Future<void> _evaluate() async {
    if (_isEvaluating) return;
    setState(() => _isEvaluating = true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final processed = await _repository.processDocument(
        resume: widget.resume,
        docKind: _docKind,
        language: 'ko',
      );
      _processed = processed;
      final evaluation = await _repository.evaluate(
        extractedText: processed.extractedText,
        resume: widget.resume,
        docKind: _docKind,
        language: 'ko',
      );
      _aiMetadata = ResumeAiMetadata(
        evaluatedAt: DateTime.now(),
        overallScore: evaluation.report.overallScore,
        reportJson: evaluation.report.toJson(),
        improvedVersion: evaluation.improvedVersion,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ResumeAiReportPage(
            resume: widget.resume,
            docKind: _docKind,
            report: evaluation.report,
            improvedVersion: evaluation.improvedVersion,
            extractedText: processed.extractedText,
            evaluatedAt: _aiMetadata?.evaluatedAt,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI 평가에 실패했습니다: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isEvaluating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.resume.filename),
      ),
      body: _buildBody(),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _isEvaluating ? null : _evaluate,
                    child: const Text('AI 평가 받기'),
                  ),
                ),
                if (_aiMetadata != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _openExistingReport,
                      child: const Text('최근 평가 결과 보기'),
                    ),
                  ),
                ],
              ],
            ),
            if (_processed?.pdfUrl != null &&
                widget.resume.fileType == ResumeFileType.hwp) ...[
              const SizedBox(height: 8),
              const Text(
                '변환된 PDF가 감지되었습니다. 새로고침하여 미리보기 할 수 있습니다.',
                style: TextStyle(color: AppColors.subtext, fontSize: 12),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final header = Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Text('문서 유형:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 12),
          DropdownButton<ResumeDocKind>(
            value: _docKind,
            onChanged: (value) async {
              if (value == null) return;
              setState(() => _docKind = value);
              await _repository.updateDocKind(
                  resumeId: widget.resume.id, docKind: value);
            },
            items: const [
              DropdownMenuItem(
                value: ResumeDocKind.resume,
                child: Text('이력서'),
              ),
              DropdownMenuItem(
                value: ResumeDocKind.coverLetter,
                child: Text('자기소개서'),
              ),
            ],
          ),
        ],
      ),
    );
    if (widget.resume.fileType == ResumeFileType.hwp) {
      return Column(
        children: [
          header,
          const Expanded(
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Preview not supported — Convert to PDF to enable preview',
                  style: TextStyle(color: AppColors.subtext),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (_isLoading) {
      return Column(
        children: [
          header,
          const Expanded(child: Center(child: CircularProgressIndicator()))
        ],
      );
    }

    if (_controller == null) {
      return Column(
        children: [
          header,
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _errorMessage ?? '파일을 불러오지 못했습니다',
                    style: const TextStyle(color: AppColors.subtext),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _loadPdf,
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        header,
        Expanded(
          child: PdfViewPinch(
            controller: _controller!,
            backgroundDecoration: const BoxDecoration(color: Colors.white),
          ),
        ),
      ],
    );
  }
}

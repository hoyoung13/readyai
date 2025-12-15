import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:pdfx/pdfx.dart';

import 'package:ai/features/profile/resume/data/resume_repository.dart';
import 'package:ai/features/profile/resume/models/resume.dart';
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

  @override
  void initState() {
    super.initState();
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

  Future<void> _evaluate() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final result = await _repository.evaluateResume(widget.resume.url);

    if (!mounted) return;
    Navigator.of(context).pop();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _EvaluationResultPage(result: result),
      ),
    );
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
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _evaluate,
            child: const Text('AI 평가 받기'),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (widget.resume.fileType == ResumeFileType.hwp) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Preview not supported — Convert to PDF to enable preview',
            style: TextStyle(color: AppColors.subtext),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_controller == null) {
      return Center(
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
      );
    }

    return PdfViewPinch(
      controller: _controller!,
      backgroundDecoration: const BoxDecoration(color: Colors.white),
    );
  }
}

class _EvaluationResultPage extends StatelessWidget {
  const _EvaluationResultPage({required this.result});

  final String result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 평가 결과'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          result,
          style: const TextStyle(fontSize: 16, height: 1.5),
        ),
      ),
    );
  }
}

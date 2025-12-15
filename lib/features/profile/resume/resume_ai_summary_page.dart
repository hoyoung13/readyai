import 'package:flutter/material.dart';

import 'package:ai/features/profile/resume/ai/resume_ai_models.dart';
import 'package:ai/features/profile/resume/data/resume_repository.dart';
import 'package:ai/features/profile/resume/models/resume.dart';

class ResumeAiSummaryPage extends StatefulWidget {
  const ResumeAiSummaryPage({
    required this.resume,
    required this.docKind,
    this.extractedText,
    super.key,
  });

  final ResumeFile resume;
  final ResumeDocKind docKind;
  final String? extractedText;

  @override
  State<ResumeAiSummaryPage> createState() => _ResumeAiSummaryPageState();
}

class _ResumeAiSummaryPageState extends State<ResumeAiSummaryPage> {
  final _repository = ResumeRepository.instance();
  SummaryResult? _summary;
  String? _text;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _text = widget.extractedText;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final extracted = _text ??
          (await _repository.processDocument(
            resume: widget.resume,
            docKind: widget.docKind,
            language: 'ko',
          ))
              .extractedText;
      final summary = await _repository.summarize(
        extractedText: extracted,
        language: 'ko',
      );
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _text = extracted;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('자동 요약')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('다시 시도')),
          ],
        ),
      );
    }
    final summary = _summary;
    if (summary == null) {
      return const Center(child: Text('요약 결과가 없습니다.'));
    }
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(summary.oneLiner,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Text('요약', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...summary.bulletSummary.map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• '),
                    Expanded(child: Text(e)),
                  ],
                ),
              )),
          const SizedBox(height: 16),
          const Text('키워드', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: summary.keywords
                .map(
                  (e) => Chip(
                    label: Text(e),
                    backgroundColor: const Color(0xFFF2F4F7),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

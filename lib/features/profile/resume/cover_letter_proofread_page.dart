import 'package:flutter/material.dart';

import 'package:ai/features/profile/resume/ai/resume_ai_models.dart';
import 'package:ai/features/profile/resume/data/resume_repository.dart';
import 'package:ai/features/profile/resume/models/resume.dart';

class CoverLetterProofreadPage extends StatefulWidget {
  const CoverLetterProofreadPage({
    required this.resume,
    required this.docKind,
    this.extractedText,
    super.key,
  });

  final ResumeFile resume;
  final ResumeDocKind docKind;
  final String? extractedText;

  @override
  State<CoverLetterProofreadPage> createState() =>
      _CoverLetterProofreadPageState();
}

class _CoverLetterProofreadPageState extends State<CoverLetterProofreadPage> {
  final _repository = ResumeRepository.instance();
  ProofreadResult? _result;
  String? _text;
  bool _isLoading = true;
  String? _error;
  final _roleController = TextEditingController();

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
      final result = await _repository.proofread(
        extractedText: extracted,
        language: 'ko',
        targetRole:
            _roleController.text.isNotEmpty ? _roleController.text : null,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
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
      appBar: AppBar(title: const Text('자기소개서 첨삭')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _roleController,
          decoration: const InputDecoration(
            labelText: '목표 직무 (선택)',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _load(),
        ),
        const SizedBox(height: 12),
        if (_isLoading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_error != null)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _load, child: const Text('다시 시도')),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: _result == null
                ? const Center(child: Text('첨삭 결과가 없습니다.'))
                : ListView(
                    children: [
                      const Text('교정본',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE6E7EC)),
                        ),
                        child: Text(
                          _result!.correctedText,
                          style: const TextStyle(height: 1.5),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('댓글',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ..._result!.comments.map(
                        (c) => Card(
                          child: ListTile(
                            title: Text(c.lineOrSection),
                            subtitle: Text(c.comment),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                        label: const Text('다시 실행'),
                      ),
                    ],
                  ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _roleController.dispose();
    super.dispose();
  }
}

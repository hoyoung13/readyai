import 'package:flutter/material.dart';

import '../tabs/tabs_shared.dart';

const communityCategories = [
  '공지',
  '자유',
  'Q&A',
  '면접 후기',
  '스터디 구인',
  '취업 정보',
];

class CommunityPostComposer extends StatefulWidget {
  const CommunityPostComposer({
    required this.onSubmit,
    this.initialCategory,
    this.initialTitle,
    this.initialContent,
    this.submitLabel,
    super.key,
  });

  final Future<void> Function(String category, String title, String content)
      onSubmit;
  final String? initialCategory;
  final String? initialTitle;
  final String? initialContent;
  final String? submitLabel;

  @override
  State<CommunityPostComposer> createState() => _CommunityPostComposerState();
}

class _CommunityPostComposerState extends State<CommunityPostComposer> {
  final _formKey = GlobalKey<FormState>();
  late String _category;
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _category = communityCategories.first;
    if (widget.initialCategory != null &&
        communityCategories.contains(widget.initialCategory)) {
      _category = widget.initialCategory!;
    }
    if (widget.initialTitle != null) {
      _titleController.text = widget.initialTitle!;
    }
    if (widget.initialContent != null) {
      _contentController.text = widget.initialContent!;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing =
        widget.initialTitle != null || widget.initialContent != null;
    final submitLabel = widget.submitLabel ?? (isEditing ? '수정하기' : '등록하기');
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  isEditing ? '게시글 수정' : '새 글 작성',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _submitting
                      ? null
                      : () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _category,
              items: [
                for (final item in communityCategories)
                  DropdownMenuItem(value: item, child: Text(item)),
              ],
              onChanged: _submitting
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() => _category = value);
                      }
                    },
              decoration: const InputDecoration(
                labelText: '카테고리',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _titleController,
              enabled: !_submitting,
              decoration: const InputDecoration(
                labelText: '제목',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '제목을 입력해 주세요.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _contentController,
              enabled: !_submitting,
              decoration: const InputDecoration(
                labelText: '내용',
                border: OutlineInputBorder(),
              ),
              minLines: 5,
              maxLines: 8,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '내용을 입력해 주세요.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitting ? null : _handleSubmit,
                child: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(submitLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    try {
      await widget.onSubmit(
        _category,
        _titleController.text.trim(),
        _contentController.text.trim(),
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('처리 중 문제가 발생했습니다: $error')),
      );
    } finally {
      if (!mounted) return;
      setState(() => _submitting = false);
    }
  }
}

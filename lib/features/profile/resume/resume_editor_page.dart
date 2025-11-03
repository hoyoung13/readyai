import 'package:flutter/material.dart';

import 'package:ai/features/profile/resume/resume_dashboard_page.dart';
import 'package:ai/features/tabs/tabs_shared.dart';

class ResumeEditorPage extends StatefulWidget {
  const ResumeEditorPage({
    super.key,
    this.summary,
  });

  final ResumeProfileSummary? summary;

  @override
  State<ResumeEditorPage> createState() => _ResumeEditorPageState();
}

class _ResumeEditorPageState extends State<ResumeEditorPage> {
  late final TextEditingController _educationController;
  late final TextEditingController _experienceController;
  late final TextEditingController _certificateController;
  late final TextEditingController _preferenceController;
  late final TextEditingController _coverLetterController;
  late final TextEditingController _portfolioController;
  late final TextEditingController _titleController;

  bool _isPublic = true;

  @override
  void initState() {
    super.initState();
    _educationController = TextEditingController();
    _experienceController = TextEditingController();
    _certificateController = TextEditingController();
    _preferenceController = TextEditingController();
    _coverLetterController = TextEditingController();
    _portfolioController = TextEditingController();
    _titleController = TextEditingController();
  }

  @override
  void dispose() {
    _educationController.dispose();
    _experienceController.dispose();
    _certificateController.dispose();
    _preferenceController.dispose();
    _coverLetterController.dispose();
    _portfolioController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary ??
        const ResumeProfileSummary(name: '부천대', description: '남자, 2025년생');

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('이력서 작성'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.text,
        elevation: 0.5,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          ResumeProfileHeaderCard(summary: summary),
          const SizedBox(height: 20),
          _ResumeField(
            label: '학력',
            required: true,
            hint: '나의 최종학력을 입력해보세요.',
            controller: _educationController,
            actionLabel: '학력추가',
          ),
          const SizedBox(height: 16),
          _ResumeField(
            label: '경력',
            required: true,
            hint: '나의 경력을 입력해보세요.',
            controller: _experienceController,
            actionLabel: '경력추가',
          ),
          const SizedBox(height: 16),
          _ResumeField(
            label: '자격증',
            hint: '나의 자격증을 입력해보세요.',
            controller: _certificateController,
            actionLabel: '자격증추가',
          ),
          const SizedBox(height: 16),
          _ResumeField(
            label: '희망 근무 조건',
            hint: '나의 희망 근무 조건을 입력해보세요.',
            controller: _preferenceController,
            actionLabel: '근무 조건추가',
          ),
          const SizedBox(height: 16),
          _ResumeField(
            label: '자소서',
            hint: '나의 자소서파일을 추가해보세요.',
            controller: _coverLetterController,
            actionLabel: '파일 첨부',
            actionStyle: _ResumeFieldActionStyle.filled,
          ),
          const SizedBox(height: 16),
          _ResumeField(
            label: '포트폴리오',
            hint: '나의 포트폴리오를 추가해보세요.',
            controller: _portfolioController,
            actionLabel: '파일 첨부',
            actionStyle: _ResumeFieldActionStyle.filled,
          ),
          const SizedBox(height: 16),
          _ResumeField(
            label: '이력서 명',
            required: true,
            hint: '나의 이력서에 이름을 지어주세요.',
            controller: _titleController,
            actionLabel: '이름 작성',
            multiline: false,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '공개 여부',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                children: [
                  Text(
                    _isPublic ? 'O' : 'X',
                    style: TextStyle(
                      fontSize: 14,
                      color: _isPublic ? const Color(0xFF6D5CFF) : AppColors.subtext,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: _isPublic,
                    activeColor: const Color(0xFF6D5CFF),
                    onChanged: (value) {
                      setState(() {
                        _isPublic = value;
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {},
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF6D5CFF),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              '저장하기',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _ResumeFieldActionStyle { text, filled }

class _ResumeField extends StatelessWidget {
  const _ResumeField({
    required this.label,
    required this.controller,
    this.hint,
    this.required = false,
    this.actionLabel,
    this.multiline = true,
    this.actionStyle = _ResumeFieldActionStyle.text,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool required;
  final String? actionLabel;
  final bool multiline;
  final _ResumeFieldActionStyle actionStyle;

  @override
  Widget build(BuildContext context) {
    final accentColor = const Color(0xFF6D5CFF);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE1E1E5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (required) ...[
                const SizedBox(width: 6),
                const Text(
                  '필수',
                  style: TextStyle(
                    color: Color(0xFFEA4E4E),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const Spacer(),
              if (actionLabel != null)
                actionStyle == _ResumeFieldActionStyle.text
                    ? TextButton(
                        onPressed: () {},
                        style: TextButton.styleFrom(
                          foregroundColor: accentColor,
                        ),
                        child: Text(actionLabel!),
                      )
                    : OutlinedButton(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          foregroundColor: accentColor,
                          side: BorderSide(
                            color: accentColor.withOpacity(0.4),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                        child: Text(
                          actionLabel!,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            maxLines: multiline ? 4 : 1,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: AppColors.subtext),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE1E1E5)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE1E1E5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: accentColor),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}
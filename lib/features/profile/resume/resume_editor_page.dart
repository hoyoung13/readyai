import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:ai/features/profile/resume/data/resume_repository.dart';
import 'package:ai/features/profile/resume/models/resume.dart';
import 'package:ai/features/profile/resume/resume_dashboard_page.dart';
import 'package:ai/features/tabs/tabs_shared.dart';

class ResumeEditorPage extends StatefulWidget {
  const ResumeEditorPage({
    super.key,
    this.summary,
    this.initialResume,
  });

  final ResumeProfileSummary? summary;
  final Resume? initialResume;

  @override
  State<ResumeEditorPage> createState() => _ResumeEditorPageState();
}

class _ResumeEditorPageState extends State<ResumeEditorPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  late final TextEditingController _summaryController;
  late final TextEditingController _educationController;
  late final TextEditingController _experienceController;
  late final TextEditingController _certificateController;
  late final TextEditingController _skillsController;
  late final TextEditingController _projectsController;
  late final TextEditingController _additionalController;
  late final TextEditingController _titleController;

  bool _isPublic = true;
  bool _isSaving = false;
  bool _isExportingPdf = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _addressController = TextEditingController();
    _summaryController = TextEditingController();
    _educationController = TextEditingController();
    _experienceController = TextEditingController();
    _certificateController = TextEditingController();
    _skillsController = TextEditingController();
    _projectsController = TextEditingController();
    _additionalController = TextEditingController();
    _titleController = TextEditingController();

    _applyInitialResume();
  }

  bool get _isEditing => widget.initialResume != null;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _summaryController.dispose();
    _educationController.dispose();
    _experienceController.dispose();
    _certificateController.dispose();
    _skillsController.dispose();
    _projectsController.dispose();
    _additionalController.dispose();
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
        title: Text(_isEditing ? '이력서 수정' : '이력서 작성'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.text,
        elevation: 0.5,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          ResumeProfileHeaderCard(summary: summary),
          const SizedBox(height: 20),
          _ResumeBasicInfoSection(
            nameController: _nameController,
            phoneController: _phoneController,
            emailController: _emailController,
            addressController: _addressController,
          ),
          const SizedBox(height: 16),
          _ResumeField(
            label: '간단한 소개 또는 목표',
            hint: '원하는 포지션이나 커리어 목표를 적어보세요.',
            controller: _summaryController,
          ),
          const SizedBox(height: 16),
          _ResumeField(
            label: '학력',
            required: true,
            hint: '학교명, 전공, 재학 기간, 학위를 입력해보세요.',
            controller: _educationController,
            actionLabel: '학력추가',
          ),
          const SizedBox(height: 16),
          _ResumeField(
            label: '경력',
            required: true,
            hint: '회사명, 직무, 기간, 성과를 정리해보세요.',
            controller: _experienceController,
            actionLabel: '경력추가',
          ),
          const SizedBox(height: 16),
          _ResumeField(
            label: '자격증·수상 내역',
            hint: '보유한 자격증이나 수상 내역을 입력해보세요.',
            controller: _certificateController,
            actionLabel: '자격증추가',
          ),
          const SizedBox(height: 16),
          _ResumeField(
            label: '보유 기술',
            hint: '사용 가능한 기술이나 도구를 입력해보세요.',
            controller: _skillsController,
            actionLabel: '기술추가',
          ),
          const SizedBox(height: 16),
          _ResumeField(
            label: '프로젝트나 활동',
            hint: '프로젝트명, 역할, 기간, 사용 기술, 성과 등을 정리해보세요.',
            controller: _projectsController,
            actionLabel: '프로젝트추가',
          ),
          const SizedBox(height: 16),
          _ResumeField(
            label: '기타',
            hint: '추가로 알리고 싶은 내용을 입력해보세요.',
            controller: _additionalController,
            actionLabel: '내용추가',
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
          OutlinedButton.icon(
            onPressed: _showPreview,
            icon: const Icon(Icons.text_snippet_outlined),
            label: const Text('이력서 텍스트 보기'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _showPdfPreview,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('PDF 미리보기'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _isExportingPdf ? null : _handleExportPdf,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF4C49FF),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: _isExportingPdf
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : const Icon(Icons.picture_as_pdf_outlined),
            label:
                Text(_isExportingPdf ? 'PDF 저장 중...' : 'PDF로 저장하기'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _isSaving ? null : _handleSave,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF6D5CFF),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              _isEditing ? '수정 내용 저장' : '저장하기',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _applyInitialResume() {
    final resume = widget.initialResume;
    if (resume == null) {
      return;
    }

    _titleController.text = resume.title;
    _nameController.text = resume.name;
    _phoneController.text = resume.phone;
    _emailController.text = resume.email;
    _addressController.text = resume.address ?? '';
    _summaryController.text = resume.summary ?? '';
    _educationController.text = resume.education;
    _experienceController.text = resume.experience;
    _certificateController.text = resume.certificates ?? '';
    _skillsController.text = resume.skills ?? '';
    _projectsController.text = resume.projects ?? '';
    _additionalController.text = resume.additional ?? '';
    _isPublic = resume.isPublic;
  }

  bool _validateRequiredFields() {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    final education = _educationController.text.trim();
    final experience = _experienceController.text.trim();
    final title = _titleController.text.trim();

    if (name.isEmpty || phone.isEmpty || email.isEmpty ||
        education.isEmpty || experience.isEmpty || title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('기본 정보(이름, 연락처, 이메일)와 학력, 경력, 이력서 명은 필수 입력 항목입니다.'),
        ),
      );
      return false;
    }

    return true;
  }

  Future<void> _showPreview() async {
    if (!_validateRequiredFields()) {
      return;
    }

    final resume = _createResumeModel(
      id: 'preview',
      updatedAt: DateTime.now(),
    );

    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.9,
          child: _ResumePreviewSheet(content: resume.formattedContent),
        );
      },
    );
  }

  Future<void> _handleSave() async {
    if (!_validateRequiredFields()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final now = DateTime.now();
    final resume = _createResumeModel(
      id: widget.initialResume?.id ?? now.millisecondsSinceEpoch.toString(),
      updatedAt: now,
    );

    final repository = await ResumeRepository.instance();
    await repository.save(resume);

    if (!mounted) {
      return;
    }

    setState(() {
      _isSaving = false;
    });

    Navigator.of(context).pop(true);
  }

  Future<void> _handleExportPdf() async {
    if (!_validateRequiredFields()) {
      return;
    }

    setState(() => _isExportingPdf = true);

    try {
      final now = DateTime.now();
      final resume = _createResumeModel(id: 'preview', updatedAt: now);
      final bytes = await _buildResumePdf(resume: resume, generatedAt: now);
      final timestamp =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';

      await Printing.sharePdf(
        bytes: bytes,
        filename: 'resume-$timestamp.pdf',
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('PDF 저장을 위한 공유 시트를 열었습니다.'),
          ),
        );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('PDF 저장 중 오류가 발생했습니다. 다시 시도해 주세요.\n오류: $error'),
          ),
        );
    } finally {
      if (!mounted) {
        return;
      }

      setState(() => _isExportingPdf = false);
    }
  }

  Future<void> _showPdfPreview() async {
    if (!_validateRequiredFields()) {
      return;
    }

    final now = DateTime.now();
    final resume = _createResumeModel(id: 'preview', updatedAt: now);

    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.92,
          child: _ResumePdfPreviewSheet(
            resume: resume,
            generatedAt: now,
            buildPdf: _buildResumePdf,
          ),
        );
      },
    );
  }

  Future<Uint8List> _buildResumePdf({
    required Resume resume,
    required DateTime generatedAt,
  }) async {
    final doc = pw.Document();
    final fontRegular = await PdfGoogleFonts.notoSansKRRegular();
    final fontBold = await PdfGoogleFonts.notoSansKRBold();

    pw.TableRow infoRow(String label, String value) {
      return pw.TableRow(
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 4),
            child: pw.Text(
              label,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 4),
            child: pw.Text(value),
          ),
        ],
      );
    }

    List<pw.Widget> buildSection(String title, String? content) {
      if (content == null || content.trim().isEmpty) {
        return <pw.Widget>[];
      }

      final trimmed = content.trim();

      return [
        pw.SizedBox(height: 20),
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          trimmed,
          style: pw.TextStyle(height: 1.4),
        ),
      ];
    }

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        ),
        build: (context) {
          final widgets = <pw.Widget>[
            pw.Text(
              resume.title,
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              resume.name,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              '기본 정보',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Table(
              columnWidths: {
                0: const pw.IntrinsicColumnWidth(),
                1: const pw.FlexColumnWidth(),
              },
              border: null,
              children: [
                infoRow('이름', resume.name),
                infoRow('연락처', resume.phone),
                infoRow('이메일', resume.email),
                if (resume.address != null &&
                    resume.address!.trim().isNotEmpty)
                  infoRow('주소', resume.address!.trim()),
              ],
            ),
            ...buildSection('간단 소개/목표', resume.summary),
            ...buildSection('학력', resume.education),
            ...buildSection('경력', resume.experience),
            ...buildSection('자격증·수상 내역', resume.certificates),
            ...buildSection('보유 기술', resume.skills),
            ...buildSection('프로젝트·활동', resume.projects),
            ...buildSection('기타', resume.additional),
          ];

          widgets.add(
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 24),
              child: pw.Text(
                '생성 일시: ${generatedAt.toLocal()}',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ),
          );

          return widgets;
        },
      ),
    );

    return doc.save();
  }

  Resume _createResumeModel({required String id, required DateTime updatedAt}) {
    String? toNullable(TextEditingController controller) {
      final value = controller.text.trim();
      return value.isEmpty ? null : value;
    }

    return Resume(
      id: id,
      title: _titleController.text.trim(),
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      address: toNullable(_addressController),
      summary: toNullable(_summaryController),
      education: _educationController.text.trim(),
      experience: _experienceController.text.trim(),
      certificates: toNullable(_certificateController),
      skills: toNullable(_skillsController),
      projects: toNullable(_projectsController),
      additional: toNullable(_additionalController),
      isPublic: _isPublic,
      updatedAt: updatedAt,
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
    const accentColor = Color(0xFF6D5CFF);

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
                borderSide: const BorderSide(color: accentColor),
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

class _ResumeBasicInfoSection extends StatelessWidget {
  const _ResumeBasicInfoSection({
    required this.nameController,
    required this.phoneController,
    required this.emailController,
    required this.addressController,
  });

  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController emailController;
  final TextEditingController addressController;

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFF6D5CFF);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE1E1E5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Text(
                '기본 정보',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(width: 6),
              Text(
                '필수',
                style: TextStyle(
                  color: Color(0xFFEA4E4E),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _BasicInfoTextField(
            controller: nameController,
            label: '이름',
            hint: '이름을 입력해주세요.',
            keyboardType: TextInputType.name,
          ),
          const SizedBox(height: 12),
          _BasicInfoTextField(
            controller: phoneController,
            label: '연락처',
            hint: '전화번호를 입력해주세요.',
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          _BasicInfoTextField(
            controller: emailController,
            label: '이메일',
            hint: '이메일을 입력해주세요.',
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          _BasicInfoTextField(
            controller: addressController,
            label: '주소 (선택)',
            hint: '주소를 입력하거나 비워둘 수 있어요.',
            keyboardType: TextInputType.streetAddress,
            required: false,
          ),
        ],
      ),
    );
  }
}

class _BasicInfoTextField extends StatelessWidget {
  const _BasicInfoTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.keyboardType,
    this.required = true,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType keyboardType;
  final bool required;

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFF6D5CFF);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (required) ...[
              const SizedBox(width: 4),
              const Text(
                '*',
                style: TextStyle(
                  color: Color(0xFFEA4E4E),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
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
              borderSide: const BorderSide(color: accentColor),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
}

class _ResumePreviewSheet extends StatelessWidget {
  const _ResumePreviewSheet({required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          24,
          20,
          20 + MediaQuery.of(context).viewPadding.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '이력서 텍스트 미리보기',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              '아래 내용을 복사하여 워드프로세서에 붙여 넣은 뒤 PDF/HWP로 저장할 수 있어요.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.subtext,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE1E1E5)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(
                    content,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: content));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('이력서 내용이 복사되었습니다.')),
                    );
                  }
                },
                icon: const Icon(Icons.copy_all_outlined),
                label: const Text('내용 복사하기'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF6D5CFF),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResumePdfPreviewSheet extends StatelessWidget {
  const _ResumePdfPreviewSheet({
    required this.resume,
    required this.generatedAt,
    required this.buildPdf,
  });

  final Resume resume;
  final DateTime generatedAt;
  final Future<Uint8List> Function({
    required Resume resume,
    required DateTime generatedAt,
  }) buildPdf;

  @override
  Widget build(BuildContext context) {
    final timestamp = generatedAt.toLocal().toString().split('.').first;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          24,
          20,
          20 + MediaQuery.of(context).viewPadding.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'PDF 미리보기',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '생성 일시 $timestamp 기준으로 PDF 레이아웃을 확인할 수 있어요.',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.subtext,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE1E1E5)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: PdfPreview(
                    maxPageWidth: 900,
                    canDebug: false,
                    canChangeOrientation: false,
                    canChangePageFormat: false,
                    build: (format) => buildPdf(
                      resume: resume,
                      generatedAt: generatedAt,
                    ),
                    loadingWidget: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'PDF는 공유 시트에서 저장하거나 전송할 수 있으며, 필요 시 외부 편집기에서 다시 서식을 조정할 수 있습니다.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.subtext,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'company_route_guard.dart';
import 'job_posting_service.dart';
import '../tabs/tabs_shared.dart';

class JobPostFormPage extends StatefulWidget {
  const JobPostFormPage({super.key, this.existing});

  final JobPostRecord? existing;

  @override
  State<JobPostFormPage> createState() => _JobPostFormPageState();
}

class _JobPostFormPageState extends State<JobPostFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtl = TextEditingController();
  final _categoryCtl = TextEditingController();
  final _subCategoryCtl = TextEditingController();
  final _employmentTypeCtl = TextEditingController();
  final _experienceCtl = TextEditingController();
  final _educationCtl = TextEditingController();
  final _descriptionCtl = TextEditingController();
  final _qualificationCtl = TextEditingController();
  final _preferredCtl = TextEditingController();
  final _processCtl = TextEditingController();
  final _locationCtl = TextEditingController();
  final _workHoursCtl = TextEditingController();
  final _salaryCtl = TextEditingController();
  final _benefitsCtl = TextEditingController();
  final _companyCtl = TextEditingController();
  final _websiteCtl = TextEditingController();
  final _contactNameCtl = TextEditingController();
  final _contactEmailCtl = TextEditingController();
  final _contactPhoneCtl = TextEditingController();
  final _applyMethodCtl = TextEditingController();
  final _attachmentsCtl = TextEditingController();
  final _additionalNotesCtl = TextEditingController();
  final List<TextEditingController> _interviewQuestionCtls = [];
  DateTime? _startDate;
  DateTime? _deadline;
  bool _submitting = false;

  final JobPostingService _service = JobPostingService();

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _titleCtl.text = existing.title;
      _categoryCtl.text = existing.category;
      _subCategoryCtl.text = existing.subCategory;
      _employmentTypeCtl.text = existing.employmentType;
      _experienceCtl.text = existing.experienceLevel;
      _educationCtl.text = existing.education;
      _descriptionCtl.text = existing.description;
      _qualificationCtl.text = existing.qualification;
      _preferredCtl.text = existing.preferred;
      _processCtl.text = existing.process;
      _locationCtl.text = existing.location;
      _workHoursCtl.text = existing.workHours;
      _salaryCtl.text = existing.salary;
      _benefitsCtl.text = existing.benefits;
      _companyCtl.text = existing.companyName;
      _websiteCtl.text = existing.companyWebsite ?? '';
      _contactNameCtl.text = existing.contactName;
      _contactEmailCtl.text = existing.contactEmail;
      _contactPhoneCtl.text = existing.contactPhone;
      _applyMethodCtl.text = existing.applyMethod;
      _attachmentsCtl.text = existing.attachments.join(', ');
      _additionalNotesCtl.text = existing.additionalNotes;
      _startDate = existing.startDate ?? existing.createdAt;
      _deadline = existing.deadline;
      _setupInterviewQuestionControllers(existing.interviewQuestions);
    } else {
      _setupInterviewQuestionControllers(const []);
    }
  }

  void _setupInterviewQuestionControllers(List<String> questions) {
    final initialQuestions =
        questions.isNotEmpty ? questions.take(5).toList() : List.filled(3, '');

    for (final q in initialQuestions) {
      _interviewQuestionCtls.add(TextEditingController(text: q));
    }

    while (_interviewQuestionCtls.length < 3) {
      _interviewQuestionCtls.add(TextEditingController());
    }
  }

  @override
  void dispose() {
    _titleCtl.dispose();
    _categoryCtl.dispose();
    _subCategoryCtl.dispose();
    _employmentTypeCtl.dispose();
    _experienceCtl.dispose();
    _educationCtl.dispose();
    _descriptionCtl.dispose();
    _qualificationCtl.dispose();
    _preferredCtl.dispose();
    _processCtl.dispose();
    _locationCtl.dispose();
    _workHoursCtl.dispose();
    _salaryCtl.dispose();
    _benefitsCtl.dispose();
    _companyCtl.dispose();
    _websiteCtl.dispose();
    _contactNameCtl.dispose();
    _contactEmailCtl.dispose();
    _contactPhoneCtl.dispose();
    _applyMethodCtl.dispose();
    _attachmentsCtl.dispose();
    _additionalNotesCtl.dispose();
    for (final ctl in _interviewQuestionCtls) {
      ctl.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initialDate = (isStart ? _startDate : _deadline) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _deadline = picked;
        }
      });
    }
  }

  void _addInterviewQuestion() {
    if (_interviewQuestionCtls.length >= 5) return;
    setState(() {
      _interviewQuestionCtls.add(TextEditingController());
    });
  }

  void _removeInterviewQuestion(int index) {
    if (_interviewQuestionCtls.length <= 3) return;
    setState(() {
      final controller = _interviewQuestionCtls.removeAt(index);
      controller.dispose();
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_startDate == null || _deadline == null) {
      _showSnack('모집 시작일과 마감일을 모두 선택해 주세요.');
      return;
    }
    if (_startDate!.isAfter(_deadline!)) {
      _showSnack('모집 시작일이 마감일보다 늦을 수 없습니다.');
      return;
    }
    final interviewQuestions = _interviewQuestionCtls
        .map((c) => c.text.trim())
        .where((q) => q.isNotEmpty)
        .toList(growable: false);

    if (interviewQuestions.length < 3) {
      _showSnack('면접 질문을 최소 3개 입력해 주세요.');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnack('로그인 후 다시 시도해 주세요.');
      return;
    }

    setState(() => _submitting = true);

    final draft = JobPostDraft(
      title: _titleCtl.text.trim(),
      category: _categoryCtl.text.trim(),
      subCategory: _subCategoryCtl.text.trim(),
      employmentType: _employmentTypeCtl.text.trim(),
      experienceLevel: _experienceCtl.text.trim(),
      education: _educationCtl.text.trim(),
      description: _descriptionCtl.text.trim(),
      qualification: _qualificationCtl.text.trim(),
      preferred: _preferredCtl.text.trim(),
      process: _processCtl.text.trim(),
      location: _locationCtl.text.trim(),
      workHours: _workHoursCtl.text.trim(),
      salary: _salaryCtl.text.trim(),
      benefits: _benefitsCtl.text.trim(),
      companyName: _companyCtl.text.trim(),
      companyWebsite:
          _websiteCtl.text.trim().isEmpty ? null : _websiteCtl.text.trim(),
      contactName: _contactNameCtl.text.trim(),
      contactEmail: _contactEmailCtl.text.trim(),
      contactPhone: _contactPhoneCtl.text.trim(),
      applyMethod: _applyMethodCtl.text.trim(),
      attachments: _splitInput(_attachmentsCtl.text),
      additionalNotes: _additionalNotesCtl.text.trim(),
      interviewQuestions: interviewQuestions,
      startDate: _startDate!,
      deadline: _deadline!,
      authorId: user.uid,
      isApproved: widget.existing?.isApproved ?? false,
      isActive: true,
      viewCount: widget.existing?.viewCount ?? 0,
      applicantCount: widget.existing?.applicantCount ?? 0,
    );

    try {
      if (widget.existing == null) {
        await _service.create(draft);
        _showSnack('공고가 등록되었습니다');
      } else {
        await _service.update(widget.existing!.id, draft);
        _showSnack('공고가 수정되었습니다');
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      _showSnack('저장에 실패했습니다. 잠시 후 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return CompanyRouteGuard(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('채용 공고 등록'),
        ),
        backgroundColor: AppColors.bg,
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle('기본 정보'),
                _Gap(),
                _LabeledField(
                  label: '공고 제목',
                  controller: _titleCtl,
                  validator: (v) => _required(v, '공고 제목을 입력해 주세요'),
                ),
                _Gap(),
                _DropdownField(
                  label: '직무 대분류',
                  controller: _categoryCtl,
                  options: _majorCategories,
                  validator: (v) => _required(v, '직무 대분류를 선택해 주세요'),
                ),
                _Gap(),
                _DropdownField(
                  label: '직무 소분류',
                  controller: _subCategoryCtl,
                  options: _subCategories,
                  validator: (v) => _required(v, '직무 소분류를 선택해 주세요'),
                ),
                _Gap(),
                _DropdownField(
                  label: '고용 형태',
                  controller: _employmentTypeCtl,
                  options: _employmentTypes,
                  validator: (v) => _required(v, '고용 형태를 선택해 주세요'),
                ),
                _Gap(),
                _DropdownField(
                  label: '경력 구분',
                  controller: _experienceCtl,
                  options: _experienceLevels,
                  validator: (v) => _required(v, '경력 구분을 선택해 주세요'),
                ),
                _Gap(),
                _DropdownField(
                  label: '학력 요건',
                  controller: _educationCtl,
                  options: _educationLevels,
                  validator: (v) => _required(v, '학력을 선택해 주세요'),
                ),
                const SizedBox(height: 24),
                const _SectionTitle('주요 내용'),
                _Gap(),
                _LabeledField(
                  label: '담당 업무',
                  controller: _descriptionCtl,
                  maxLines: 4,
                  validator: (v) => _required(v, '담당 업무를 입력해 주세요'),
                ),
                _Gap(),
                _LabeledField(
                  label: '자격 요건',
                  controller: _qualificationCtl,
                  maxLines: 4,
                  validator: (v) => _required(v, '자격 요건을 입력해 주세요'),
                ),
                _Gap(),
                _LabeledField(
                  label: '우대 사항',
                  controller: _preferredCtl,
                  maxLines: 3,
                  validator: null,
                ),
                _Gap(),
                _LabeledField(
                  label: '전형 절차',
                  controller: _processCtl,
                  maxLines: 3,
                  validator: null,
                ),
                _Gap(),
                const _SectionTitle('면접 질문 (비공개)'),
                const SizedBox(height: 8),
                const Text(
                  '면접관이 참고할 질문을 최소 3개, 최대 5개까지 입력하세요. 지원자에게는 공개되지 않습니다.',
                  style: TextStyle(color: AppColors.subtext, fontSize: 13),
                ),
                const SizedBox(height: 8),
                ...List.generate(_interviewQuestionCtls.length, (index) {
                  final canRemove = _interviewQuestionCtls.length > 3;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _interviewQuestionCtls[index],
                            validator: (v) =>
                                _required(v, '면접 질문 ${index + 1}을 입력해 주세요'),
                            decoration: InputDecoration(
                              labelText: '면접 질문 ${index + 1}',
                              filled: true,
                              fillColor: Colors.white,
                              border: const OutlineInputBorder(
                                  borderSide: BorderSide.none),
                            ),
                          ),
                        ),
                        if (canRemove)
                          IconButton(
                            tooltip: '질문 삭제',
                            onPressed: () => _removeInterviewQuestion(index),
                            icon: const Icon(Icons.delete_outline),
                          ),
                      ],
                    ),
                  );
                }),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _interviewQuestionCtls.length >= 5
                        ? null
                        : _addInterviewQuestion,
                    icon: const Icon(Icons.add),
                    label: const Text('질문 추가'),
                  ),
                ),
                const SizedBox(height: 24),
                const _SectionTitle('근무 조건'),
                _Gap(),
                _LabeledField(
                  label: '근무지',
                  controller: _locationCtl,
                  validator: (v) => _required(v, '근무지를 입력해 주세요'),
                ),
                _Gap(),
                _LabeledField(
                  label: '근무 요일/시간',
                  controller: _workHoursCtl,
                  validator: (v) => _required(v, '근무 요일/시간을 입력해 주세요'),
                ),
                _Gap(),
                _LabeledField(
                  label: '급여 조건',
                  controller: _salaryCtl,
                  validator: (v) => _required(v, '급여 조건을 입력해 주세요'),
                ),
                _Gap(),
                _LabeledField(
                  label: '복리후생',
                  controller: _benefitsCtl,
                  maxLines: 3,
                  validator: null,
                ),
                const SizedBox(height: 24),
                const _SectionTitle('기업 정보'),
                _Gap(),
                _LabeledField(
                  label: '회사명',
                  controller: _companyCtl,
                  validator: (v) => _required(v, '회사명을 입력해 주세요'),
                ),
                _Gap(),
                _LabeledField(
                  label: '회사 홈페이지 (선택)',
                  controller: _websiteCtl,
                  validator: null,
                ),
                _Gap(),
                _LabeledField(
                  label: '담당자명',
                  controller: _contactNameCtl,
                  validator: (v) => _required(v, '담당자명을 입력해 주세요'),
                ),
                _Gap(),
                _LabeledField(
                  label: '담당자 이메일',
                  controller: _contactEmailCtl,
                  validator: (v) => _required(v, '담당자 이메일을 입력해 주세요'),
                ),
                _Gap(),
                _LabeledField(
                  label: '담당자 전화번호',
                  controller: _contactPhoneCtl,
                  validator: (v) => _required(v, '담당자 전화번호를 입력해 주세요'),
                ),
                const SizedBox(height: 24),
                const _SectionTitle('지원 정보'),
                _Gap(),
                _LabeledField(
                  label: '지원 방법',
                  controller: _applyMethodCtl,
                  validator: (v) => _required(v, '지원 방법을 입력해 주세요'),
                ),
                _Gap(),
                _LabeledField(
                  label: '제출 서류 (쉼표로 구분)',
                  controller: _attachmentsCtl,
                  validator: null,
                ),
                _Gap(),
                _LabeledField(
                  label: '기타 안내',
                  controller: _additionalNotesCtl,
                  maxLines: 3,
                  validator: null,
                ),
                const SizedBox(height: 24),
                const _SectionTitle('모집 기간'),
                _Gap(),
                Row(
                  children: [
                    Expanded(
                      child: _DatePickerField(
                        label: '시작일',
                        date: _startDate,
                        onTap: () => _pickDate(isStart: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DatePickerField(
                        label: '마감일',
                        date: _deadline,
                        onTap: () => _pickDate(isStart: false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    child: Text(_submitting ? '저장 중...' : '등록하기'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _required(String? value, String message) {
    if (value == null || value.trim().isEmpty) {
      return message;
    }
    return null;
  }

  List<String> _splitInput(String input) {
    return input
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.controller,
    this.validator,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          maxLines: maxLines,
          decoration: const InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.controller,
    required this.options,
    this.validator,
  });

  final String label;
  final TextEditingController controller;
  final List<String> options;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: controller.text.isNotEmpty ? controller.text : null,
          decoration: const InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderSide: BorderSide.none),
          ),
          items: options
              .map((opt) => DropdownMenuItem<String>(
                    value: opt,
                    child: Text(opt),
                  ))
              .toList(),
          onChanged: (value) => controller.text = value ?? '',
          validator: validator,
        ),
      ],
    );
  }
}

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({
    required this.label,
    required this.date,
    required this.onTap,
  });

  final String label;
  final DateTime? date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = date == null
        ? '날짜 선택'
        : '${date!.year}.${date!.month.toString().padLeft(2, '0')}.${date!.day.toString().padLeft(2, '0')}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE5E5EA)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  text,
                  style: TextStyle(
                    color: date == null ? AppColors.subtext : Colors.black,
                  ),
                ),
                const Icon(Icons.calendar_today_outlined,
                    color: AppColors.subtext, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _Gap extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const SizedBox(height: 12);
}

const _majorCategories = [
  '개발',
  '디자인',
  '기획',
  '마케팅',
  '영업',
  '기타',
];

const _subCategories = [
  '백엔드',
  '프론트엔드',
  '모바일',
  '데이터',
  'AI/ML',
  '서비스 기획',
  'UI/UX',
  '브랜드/콘텐츠',
  'HR/경영지원',
  '기타',
];

const _employmentTypes = [
  '정규직',
  '계약직',
  '인턴',
  '프리랜서',
  '파트타임',
];

const _experienceLevels = [
  '신입',
  '경력',
  '무관',
];

const _educationLevels = [
  '학력 무관',
  '고졸 이상',
  '초대졸 이상',
  '대졸 이상',
  '석사 이상',
  '박사 이상',
];

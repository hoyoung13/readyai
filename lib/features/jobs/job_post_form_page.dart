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
  final _companyCtl = TextEditingController();
  final _titleCtl = TextEditingController();
  final _regionCtl = TextEditingController();
  final _urlCtl = TextEditingController();
  final _tagsCtl = TextEditingController();
  final _occupationsCtl = TextEditingController();
  final _descriptionCtl = TextEditingController();
  final _noticeCtl = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  bool _submitting = false;

  final JobPostingService _service = JobPostingService();

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _companyCtl.text = existing.company;
      _titleCtl.text = existing.title;
      _regionCtl.text = existing.region;
      _urlCtl.text = existing.url;
      _startDate = existing.applicationStartDate;
      _endDate = existing.applicationEndDate;
      _tagsCtl.text = existing.tags.join(', ');
      _occupationsCtl.text = existing.occupations.join(', ');
      _descriptionCtl.text = existing.description;
      _noticeCtl.text = existing.notice;
    }
  }

  @override
  void dispose() {
    _companyCtl.dispose();
    _titleCtl.dispose();
    _regionCtl.dispose();
    _urlCtl.dispose();
    _tagsCtl.dispose();
    _occupationsCtl.dispose();
    _descriptionCtl.dispose();
    _noticeCtl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initialDate = (isStart ? _startDate : _endDate) ?? DateTime.now();
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
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final start = _startDate;
    final end = _endDate;
    if (start == null || end == null) {
      _showSnack('모집 시작/마감 날짜를 모두 선택해 주세요.');
      return;
    }
    if (start.isAfter(end)) {
      _showSnack('모집 시작일이 마감일보다 늦을 수 없습니다.');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnack('로그인 후 다시 시도해 주세요.');
      return;
    }

    setState(() => _submitting = true);

    final draft = JobPostDraft(
      ownerUid: user.uid,
      company: _companyCtl.text.trim(),
      title: _titleCtl.text.trim(),
      region: _regionCtl.text.trim(),
      recruitUrl: _urlCtl.text.trim(),
      applicationStartDate: start,
      applicationEndDate: end,
      tags: _splitInput(_tagsCtl.text),
      occupations: _splitInput(_occupationsCtl.text),
      description: _descriptionCtl.text.trim(),
      notice: _noticeCtl.text.trim(),
    );

    try {
      if (widget.existing == null) {
        await _service.create(draft);
        _showSnack('채용 공고를 등록했습니다.');
      } else {
        await _service.update(widget.existing!.id, draft);
        _showSnack('채용 공고를 수정했습니다.');
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
          title: Text(widget.existing == null ? '채용 공고 등록' : '채용 공고 수정'),
        ),
        backgroundColor: AppColors.bg,
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionTitle('기본 정보'),
                _Gap(),
                _LabeledField(
                  label: '회사명',
                  controller: _companyCtl,
                  validator: (v) => _required(v, '회사명을 입력해 주세요'),
                ),
                _Gap(),
                _LabeledField(
                  label: '공고 제목',
                  controller: _titleCtl,
                  validator: (v) => _required(v, '공고 제목을 입력해 주세요'),
                ),
                _Gap(),
                _LabeledField(
                  label: '근무 지역',
                  controller: _regionCtl,
                  validator: (v) => _required(v, '근무 지역을 입력해 주세요'),
                ),
                _Gap(),
                _LabeledField(
                  label: '지원 링크',
                  controller: _urlCtl,
                  validator: (v) => _required(v, '지원 링크를 입력해 주세요'),
                ),
                const SizedBox(height: 24),
                _SectionTitle('모집 기간'),
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
                        date: _endDate,
                        onTap: () => _pickDate(isStart: false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _SectionTitle('추가 정보'),
                _Gap(),
                _LabeledField(
                  label: '태그 (쉼표 구분)',
                  controller: _tagsCtl,
                  validator: null,
                ),
                _Gap(),
                _LabeledField(
                  label: '직무 분류 (쉼표 구분)',
                  controller: _occupationsCtl,
                  validator: null,
                ),
                _Gap(),
                _LabeledField(
                  label: '상세 설명',
                  controller: _descriptionCtl,
                  maxLines: 4,
                  validator: null,
                ),
                _Gap(),
                _LabeledField(
                  label: '지원 시 유의사항',
                  controller: _noticeCtl,
                  maxLines: 3,
                  validator: null,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    child: Text(_submitting ? '저장 중...' : '저장하기'),
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

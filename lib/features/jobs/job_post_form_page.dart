import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool _loadingRegions = true;
  Map<String, dynamic> _regions = const {};
  String? _selectedCity;
  String? _selectedDistrict;
  String? _selectedNeighborhood;
  final Set<String> _selectedDays = {};
  TimeOfDay? _startTimeOfDay;
  TimeOfDay? _endTimeOfDay;

  String? _selectedMajor;
  String? _selectedSub;
  List<String> _currentSubCategories = const [];

  String? _initialCity;
  String? _initialDistrict;
  String? _initialNeighborhood;

  final JobPostingService _service = JobPostingService();

  @override
  void initState() {
    super.initState();
    _loadRegions();
    final existing = widget.existing;
    if (existing != null) {
      _titleCtl.text = existing.title;
      _categoryCtl.text = existing.category;
      _subCategoryCtl.text = existing.subCategory;
      _selectedMajor = existing.category;
      _currentSubCategories = subCategoryMap[_selectedMajor] ?? const ['미분류'];
      if (existing.subCategory.isNotEmpty &&
          !_currentSubCategories.contains(existing.subCategory)) {
        _currentSubCategories = List<String>.from(_currentSubCategories)
          ..add(existing.subCategory);
      }
      _selectedSub = existing.subCategory;
      _employmentTypeCtl.text = existing.employmentType;
      _experienceCtl.text = existing.experienceLevel;
      _educationCtl.text = existing.education;
      _descriptionCtl.text = existing.description;
      _qualificationCtl.text = existing.qualification;
      _preferredCtl.text = existing.preferred;
      _processCtl.text = existing.process;
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
      _setInitialLocation(existing);
      _setupInterviewQuestionControllers(existing.interviewQuestions);
      _initializeWorkHours(existing.workHours);
    } else {
      _setupInterviewQuestionControllers(const []);
    }
    _currentSubCategories =
        subCategoryMap[_selectedMajor]?.toList(growable: false) ?? const [];
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

  void _initializeWorkHours(String raw) {
    final match = RegExp(r'^([월화수목금토일,\s]+)\s+(\d{2}:\d{2})~(\d{2}:\d{2})')
        .firstMatch(raw.trim());
    if (match != null) {
      final days = match
          .group(1)!
          .split(RegExp(r'[\s,]+'))
          .where((d) => d.isNotEmpty)
          .toList();
      _selectedDays.addAll(days.where((d) => _weekDays.contains(d)));
      _startTimeOfDay = _parseTime(match.group(2)!);
      _endTimeOfDay = _parseTime(match.group(3)!);
    }
  }

  TimeOfDay? _parseTime(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> _loadRegions() async {
    try {
      final raw = await rootBundle.loadString('assets/regions.json');
      final decoded = json.decode(raw);
      if (decoded is Map<String, dynamic>) {
        setState(() {
          _regions = decoded;
        });
        _applyInitialLocationSelection();
      }
    } catch (_) {
      _showSnack('지역 정보를 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.');
    } finally {
      if (mounted) {
        setState(() => _loadingRegions = false);
      }
    }
  }

  void _setInitialLocation(JobPostRecord existing) {
    _initialCity = existing.locationCity.isNotEmpty
        ? existing.locationCity
        : (_selectedCity ?? '');
    _initialDistrict = existing.locationDistrict.isNotEmpty
        ? existing.locationDistrict
        : (_selectedDistrict ?? '');
    _initialNeighborhood = existing.locationNeighborhood.isNotEmpty
        ? existing.locationNeighborhood
        : (_selectedNeighborhood ?? '');

    if (_initialCity == null && existing.location.trim().isNotEmpty) {
      final parts = existing.location.trim().split(RegExp(r'\s+'));
      if (parts.isNotEmpty) {
        _initialCity = parts[0];
        if (parts.length > 1) {
          _initialDistrict = parts[1];
        }
        if (parts.length > 2) {
          _initialNeighborhood = parts.sublist(2).join(' ');
        }
      }
    }
  }

  void _applyInitialLocationSelection() {
    if (_regions.isEmpty) return;

    String? city = _initialCity;
    String? district = _initialDistrict;
    String? neighborhood = _initialNeighborhood;

    if (city != null && !_cityOptions.contains(city)) {
      city = null;
      district = null;
      neighborhood = null;
    }

    if (city != null) {
      final districts = _districtOptions(city);
      if (district != null && !districts.contains(district)) {
        district = null;
        neighborhood = null;
      }

      if (district != null) {
        final neighborhoods = _neighborhoodOptions(city, district);
        if (neighborhood != null && !neighborhoods.contains(neighborhood)) {
          neighborhood = null;
        }
      }
    }

    setState(() {
      _selectedCity = city;
      _selectedDistrict = district;
      _selectedNeighborhood = neighborhood;
    });
  }

  List<String> get _cityOptions {
    final cities =
        _regions.keys.map((e) => e.toString()).toList(growable: false);
    cities.sort();
    return cities;
  }

  List<String> _districtOptions(String city) {
    final districts = _regions[city];
    if (districts is Map<String, dynamic>) {
      final list =
          districts.keys.map((e) => e.toString()).toList(growable: false);
      list.sort();
      return list;
    }
    return const [];
  }

  List<String> _neighborhoodOptions(String city, String district) {
    final districts = _regions[city];
    if (districts is Map<String, dynamic>) {
      final neighborhoods = districts[district];
      if (neighborhoods is List) {
        return neighborhoods.map((e) => e.toString()).toList(growable: false);
      }
    }
    return const [];
  }

  List<String> get _selectedDistrictOptions =>
      _selectedCity == null ? const [] : _districtOptions(_selectedCity!);

  List<String> get _selectedNeighborhoodOptions =>
      _selectedCity != null && _selectedDistrict != null
          ? _neighborhoodOptions(_selectedCity!, _selectedDistrict!)
          : const [];
  List<String> get _majorCategories =>
      subCategoryMap.keys.toList(growable: false);

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

  Future<void> _pickTime({required bool isStart}) async {
    final current = isStart ? _startTimeOfDay : _endTimeOfDay;
    final picked = await showTimePicker(
      context: context,
      initialTime: current ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTimeOfDay = picked;
        } else {
          _endTimeOfDay = picked;
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

  String _composeWorkHours() {
    if (_selectedDays.isEmpty ||
        _startTimeOfDay == null ||
        _endTimeOfDay == null) {
      return '';
    }
    final days = _weekDays.where((d) => _selectedDays.contains(d)).join(',');
    return '$days ${_formatTime(_startTimeOfDay!)}~${_formatTime(_endTimeOfDay!)}';
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
    if (_selectedCity == null ||
        _selectedDistrict == null ||
        _selectedNeighborhood == null) {
      _showSnack('근무지를 모두 선택해 주세요.');
      return;
    }
    final workHoursText = _composeWorkHours();
    if (workHoursText.isEmpty) {
      _showSnack('근무 요일과 시간을 모두 선택해 주세요.');
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

    final majorCategory = _categoryCtl.text.trim();
    final subCategory = _subCategoryCtl.text.trim();
    final searchTags = _buildSearchTags(
      title: _titleCtl.text.trim(),
      majorCategory: majorCategory,
      subCategory: subCategory,
    );
    final requiredYears = _deriveRequiredYears(_experienceCtl.text.trim());

    final draft = JobPostDraft(
      title: _titleCtl.text.trim(),
      category: majorCategory,
      subCategory: subCategory,
      employmentType: _employmentTypeCtl.text.trim(),
      experienceLevel: _experienceCtl.text.trim(),
      education: _educationCtl.text.trim(),
      description: _descriptionCtl.text.trim(),
      qualification: _qualificationCtl.text.trim(),
      preferred: _preferredCtl.text.trim(),
      process: _processCtl.text.trim(),
      locationCity: _selectedCity!,
      locationDistrict: _selectedDistrict!,
      locationNeighborhood: _selectedNeighborhood!,
      workHours: workHoursText,
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
      searchTags: searchTags,
      requiredYears: requiredYears,
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

  Widget _buildRegionDropdowns() {
    const decoration = InputDecoration(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide.none,
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );

    if (_loadingRegions) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_cityOptions.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('근무지', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E5EA)),
            ),
            child: const Text('지역 정보를 불러올 수 없습니다.'),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('근무지', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _selectedCity,
          decoration: decoration.copyWith(hintText: '시 선택'),
          items: _cityOptions
              .map((opt) => DropdownMenuItem<String>(
                    value: opt,
                    child: Text(opt),
                  ))
              .toList(),
          onChanged: (value) {
            setState(() {
              _selectedCity = value;
              _selectedDistrict = null;
              _selectedNeighborhood = null;
            });
          },
          validator: (v) => _required(v, '시를 선택해 주세요'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _selectedDistrict,
          decoration: decoration.copyWith(hintText: '구 선택'),
          items: _selectedDistrictOptions
              .map((opt) => DropdownMenuItem<String>(
                    value: opt,
                    child: Text(opt),
                  ))
              .toList(),
          onChanged: _selectedCity == null
              ? null
              : (value) {
                  setState(() {
                    _selectedDistrict = value;
                    _selectedNeighborhood = null;
                  });
                },
          validator: (v) => _required(v, '구를 선택해 주세요'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _selectedNeighborhood,
          decoration: decoration.copyWith(hintText: '동 선택'),
          items: _selectedNeighborhoodOptions
              .map((opt) => DropdownMenuItem<String>(
                    value: opt,
                    child: Text(opt),
                  ))
              .toList(),
          onChanged: _selectedDistrict == null
              ? null
              : (value) {
                  setState(() {
                    _selectedNeighborhood = value;
                  });
                },
          validator: (v) => _required(v, '동을 선택해 주세요'),
        ),
      ],
    );
  }

  Widget _buildWorkScheduleSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('근무 요일', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _weekDays
              .map((day) => ChoiceChip(
                    label: Text(day),
                    selected: _selectedDays.contains(day),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedDays.add(day);
                        } else {
                          _selectedDays.remove(day);
                        }
                      });
                    },
                    selectedColor: Theme.of(context).colorScheme.primary,
                    labelStyle: TextStyle(
                      color: _selectedDays.contains(day)
                          ? Colors.white
                          : Colors.black87,
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ))
              .toList(),
        ),
        const SizedBox(height: 20),
        const Text('근무 시간', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _TimeSelector(
                label: '시작 시간',
                time: _startTimeOfDay,
                onTap: () => _pickTime(isStart: true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TimeSelector(
                label: '종료 시간',
                time: _endTimeOfDay,
                onTap: () => _pickTime(isStart: false),
              ),
            ),
          ],
        ),
        if (_startTimeOfDay != null && _endTimeOfDay != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              '선택된 시간: ${_formatTime(_startTimeOfDay!)} ~ ${_formatTime(_endTimeOfDay!)}',
              style: const TextStyle(color: AppColors.subtext),
            ),
          ),
      ],
    );
  }

  String _formatTime(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
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
              children: [
                _SectionCard(
                  title: '기본 정보',
                  children: [
                    _LabeledTextField(
                      label: '공고 제목',
                      controller: _titleCtl,
                      validator: (v) => _required(v, '공고 제목을 입력해 주세요'),
                    ),
                    _buildCategorySelectors(),
                    _LabeledDropdown(
                      label: '고용 형태',
                      controller: _employmentTypeCtl,
                      options: _employmentTypes,
                      validator: (v) => _required(v, '고용 형태를 선택해 주세요'),
                    ),
                    _LabeledDropdown(
                      label: '경력 구분',
                      controller: _experienceCtl,
                      options: _experienceLevels,
                      validator: (v) => _required(v, '경력 구분을 선택해 주세요'),
                    ),
                    _LabeledDropdown(
                      label: '학력 요건',
                      controller: _educationCtl,
                      options: _educationLevels,
                      validator: (v) => _required(v, '학력을 선택해 주세요'),
                    ),
                  ],
                ),
                _SectionCard(
                  title: '주요 내용',
                  children: [
                    _LabeledTextField(
                      label: '담당 업무',
                      controller: _descriptionCtl,
                      maxLines: 4,
                      validator: (v) => _required(v, '담당 업무를 입력해 주세요'),
                    ),
                    _LabeledTextField(
                      label: '자격 요건',
                      controller: _qualificationCtl,
                      maxLines: 4,
                      validator: (v) => _required(v, '자격 요건을 입력해 주세요'),
                    ),
                    _LabeledTextField(
                      label: '우대 사항',
                      controller: _preferredCtl,
                      maxLines: 3,
                    ),
                    _LabeledTextField(
                      label: '전형 절차',
                      controller: _processCtl,
                      maxLines: 3,
                    ),
                  ],
                ),
                _SectionCard(
                  title: '면접 질문 (비공개)',
                  subtitle:
                      '면접관이 참고할 질문을 최소 3개, 최대 5개까지 입력하세요. 지원자에게는 공개되지 않습니다.',
                  children: [
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
                                decoration:
                                    _fieldDecoration('면접 질문 ${index + 1} 입력'),
                              ),
                            ),
                            if (canRemove)
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: _IconButton(
                                  icon: Icons.remove_circle_outline,
                                  onPressed: () =>
                                      _removeInterviewQuestion(index),
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: _interviewQuestionCtls.length >= 5
                            ? null
                            : _addInterviewQuestion,
                        icon: const Icon(Icons.add),
                        label: const Text('질문 추가'),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                _SectionCard(
                  title: '근무 조건',
                  children: [
                    _buildRegionDropdowns(),
                    const SizedBox(height: 20),
                    _buildWorkScheduleSelector(),
                    const SizedBox(height: 20),
                    _LabeledTextField(
                      label: '급여 조건',
                      controller: _salaryCtl,
                      validator: (v) => _required(v, '급여 조건을 입력해 주세요'),
                    ),
                    _LabeledTextField(
                      label: '복지/혜택',
                      controller: _benefitsCtl,
                    ),
                  ],
                ),
                _SectionCard(
                  title: '기업 정보',
                  children: [
                    _LabeledTextField(
                      label: '기업명',
                      controller: _companyCtl,
                      validator: (v) => _required(v, '기업명을 입력해 주세요'),
                    ),
                    _LabeledTextField(
                      label: '회사 홈페이지',
                      controller: _websiteCtl,
                    ),
                  ],
                ),
                _SectionCard(
                  title: '지원 정보',
                  children: [
                    _LabeledTextField(
                      label: '담당자 이름',
                      controller: _contactNameCtl,
                      validator: (v) => _required(v, '담당자 이름을 입력해 주세요'),
                    ),
                    _LabeledTextField(
                      label: '담당자 이메일',
                      controller: _contactEmailCtl,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => _required(v, '담당자 이메일을 입력해 주세요'),
                    ),
                    _LabeledTextField(
                      label: '담당자 연락처',
                      controller: _contactPhoneCtl,
                      keyboardType: TextInputType.phone,
                      validator: (v) => _required(v, '담당자 연락처를 입력해 주세요'),
                    ),
                    _LabeledTextField(
                      label: '지원 방법',
                      controller: _applyMethodCtl,
                      validator: (v) => _required(v, '지원 방법을 입력해 주세요'),
                    ),
                    _LabeledTextField(
                      label: '필수/선택 제출 서류',
                      controller: _attachmentsCtl,
                      hintText: '쉼표로 구분해 입력하세요',
                    ),
                  ],
                ),
                _SectionCard(
                  title: '기타',
                  children: [
                    _LabeledTextField(
                      label: '추가 안내',
                      controller: _additionalNotesCtl,
                      maxLines: 3,
                    ),
                  ],
                ),
                _SectionCard(
                  title: '모집 기간',
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _DatePickerField(
                            label: '모집 시작일',
                            date: _startDate,
                            onTap: () => _pickDate(isStart: true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DatePickerField(
                            label: '모집 마감일',
                            date: _deadline,
                            onTap: () => _pickDate(isStart: false),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('저장하기', style: TextStyle(fontSize: 16)),
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
    if (value == null || value.trim().isEmpty) return message;
    return null;
  }

  List<String> _splitInput(String input) {
    if (input.trim().isEmpty) return [];
    return input
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  int _deriveRequiredYears(String experience) {
    final match = RegExp(r'(\d+)').firstMatch(experience);
    if (match != null) {
      return int.tryParse(match.group(1) ?? '0') ?? 0;
    }
    if (experience.contains('경력')) return 3;
    return 0;
  }

  List<String> _buildSearchTags({
    required String title,
    required String majorCategory,
    required String subCategory,
  }) {
    final normalizedTitle = title.trim();
    final normalizedMajor = majorCategory.trim();
    final normalizedSub = subCategory.trim();
    final tags = <String>{
      normalizedMajor,
      normalizedSub,
      normalizedMajor.toLowerCase(),
      normalizedSub.toLowerCase(),
      ...normalizedSub.split('/'),
      ...normalizedTitle.split(' '),
    };
    tags.removeWhere((element) => element.trim().isEmpty);
    return tags.toList(growable: false);
  }

  Widget _buildCategorySelectors() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('직무 대분류', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          key: ValueKey('major-$_selectedMajor'),
          value: _selectedMajor,
          decoration: _dropdownDecoration('선택해 주세요'),
          items: _majorCategories
              .map((opt) => DropdownMenuItem<String>(
                    value: opt,
                    child: Text(opt),
                  ))
              .toList(),
          onChanged: (value) {
            setState(() {
              _selectedMajor = value;
              _categoryCtl.text = value ?? '';
              _currentSubCategories =
                  value != null && subCategoryMap[value] != null
                      ? subCategoryMap[value]!
                      : const ['미분류'];
              _selectedSub = null;
              _subCategoryCtl.clear();
            });
          },
          validator: (v) => _required(v, '직무 대분류를 선택해 주세요'),
        ),
        const SizedBox(height: 16),
        const Text('직무 소분류', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: DropdownButtonFormField<String>(
            key: ValueKey('sub-$_selectedMajor-$_selectedSub'),
            value: _selectedSub,
            decoration: _dropdownDecoration('대분류 선택 후 선택해 주세요'),
            items: _currentSubCategories
                .map((opt) => DropdownMenuItem<String>(
                      value: opt,
                      child: Text(opt),
                    ))
                .toList(),
            onChanged: _selectedMajor == null
                ? null
                : (value) {
                    setState(() {
                      _selectedSub = value;
                      _subCategoryCtl.text = value ?? '';
                    });
                  },
            validator: (v) => _required(v, '직무 소분류를 선택해 주세요'),
          ),
        ),
        const SizedBox(height: 14),
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
              borderRadius: BorderRadius.circular(12),
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

class _LabeledTextField extends StatelessWidget {
  const _LabeledTextField({
    required this.label,
    required this.controller,
    this.validator,
    this.maxLines = 1,
    this.keyboardType,
    this.hintText,
  });

  final String label;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            validator: validator,
            maxLines: maxLines,
            keyboardType: keyboardType,
            decoration: _fieldDecoration(hintText ?? '입력해 주세요'),
          ),
        ],
      ),
    );
  }
}

class _LabeledDropdown extends StatelessWidget {
  const _LabeledDropdown({
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: controller.text.isEmpty ? null : controller.text,
            decoration: _dropdownDecoration('선택해 주세요'),
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
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.children,
    this.subtitle,
  });

  final String title;
  final List<Widget> children;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 14,
            offset: Offset(0, 8),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: const TextStyle(color: AppColors.subtext, fontSize: 13),
            ),
          ],
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _TimeSelector extends StatelessWidget {
  const _TimeSelector({
    required this.label,
    required this.time,
    required this.onTap,
  });

  final String label;
  final TimeOfDay? time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = time == null ? '시간 선택' : _format(time!);
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
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E5EA)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  text,
                  style: TextStyle(
                    color: time == null ? AppColors.subtext : Colors.black,
                  ),
                ),
                const Icon(Icons.access_time,
                    color: AppColors.subtext, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _format(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, color: Colors.redAccent),
        ),
      ),
    );
  }
}

InputDecoration _fieldDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
  );
}

InputDecoration _dropdownDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: Colors.grey.shade400),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    constraints: const BoxConstraints(minHeight: 52),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: const Color(0xFFE0E0E5)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: const Color(0xFFE0E0E5)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFF7B3EFF), width: 1.4),
    ),
  );
}

const Map<String, List<String>> subCategoryMap = {
  'IT · 소프트웨어': [
    '웹 개발',
    '애플리케이션 개발',
    '게임 개발',
    '풀스택 개발',
    '소프트웨어 엔지니어링',
    'QA/테스트',
    '기술 PM',
  ],
  '모바일 앱': [
    'iOS 개발',
    'Android 개발',
    'Flutter 개발',
    'React Native 개발',
    '모바일 QA',
  ],
  '웹 프론트엔드': [
    'React',
    'Vue',
    'Next.js',
    '웹 퍼블리싱',
    'UI 엔지니어',
  ],
  '백엔드/서버': [
    'Java 백엔드',
    'Node.js 백엔드',
    'Python 백엔드',
    'Django/FastAPI',
    'Spring 개발',
    'API 서버 개발',
    'DBA',
  ],
  '데이터/AI': [
    '데이터 분석가',
    '데이터 엔지니어',
    '머신러닝 엔지니어',
    'AI 모델링',
    'MLOps',
  ],
  '클라우드/DevOps': [
    'DevOps 엔지니어',
    'SRE',
    'AWS/GCP/Azure 엔지니어',
    '인프라 엔지니어',
    '쿠버네티스(K8s)',
  ],
  '보안(Security)': [
    '보안 엔지니어',
    '취약점 분석',
    '모의 해킹',
    '보안 솔루션 개발',
    'SIEM/보안관제',
  ],
  '금융/핀테크': [
    '핀테크 개발',
    '결제 시스템 개발',
    '금융 데이터 분석',
    '리스크 엔지니어링',
  ],
  '서비스/플랫폼': [
    '서비스 기획',
    '운영 PM',
    '프로덕트 매니저',
    '플랫폼 운영',
  ],
  '디자인/UX': [
    'UI/UX 디자인',
    'BX/브랜딩 디자인',
    '모바일 UX 디자인',
    '그래픽 디자인',
    '모션 그래픽',
  ],
  '제조/품질': [
    '제조 엔지니어',
    '공정 개발',
    '품질 관리(QC)',
    'QA/품질 보증',
    'R&D 연구원',
  ],
  '공공/공기업': [
    '행정/사무',
    '기술직',
    '연구직',
    '전산직',
    '기타 공공기관 직군',
  ],
  '마케팅/광고': [
    '콘텐츠 마케팅',
    '퍼포먼스 마케팅',
    '브랜드 마케팅',
    '광고 AE',
    'SNS 마케팅',
  ],
  '영업/CS': [
    '영업관리',
    'B2B 영업',
    '기술영업',
    '고객지원(CS)',
    '서비스 운영',
  ],
  '경영/지원': [
    'HR 인사',
    '총무',
    '재무/회계',
    '법무',
    '조직문화',
  ],
  '기타': [
    '미분류',
    '기타 역할',
  ],
};

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
const _weekDays = ['월', '화', '수', '목', '금', '토', '일'];

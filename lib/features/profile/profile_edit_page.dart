import 'dart:convert';
import 'dart:typed_data';
import 'dart:io' show File;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import '../jobs/job_categories.dart';
import '../tabs/tabs_shared.dart';

class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _desiredRoleController = TextEditingController();
  final _desiredLocationController = TextEditingController();
  String? _careerType;
  String? _gender;
  DateTime? _birthDate;
  XFile? _pickedImage;
  Uint8List? _pickedImageBytes;
  String? _profileImageUrl;
  bool _saving = false;
  bool _loadingRegions = true;
  Map<String, dynamic> _regions = const {};

  String? _selectedMajor;
  String? _selectedSub;
  List<String> _currentSubCategories = const [];

  String? _selectedCity;
  String? _selectedDistrict;
  String? _selectedNeighborhood;
  String? _initialCity;
  String? _initialDistrict;
  String? _initialNeighborhood;

  @override
  void initState() {
    super.initState();
    _loadRegions();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final data = doc.data();
    if (data == null) return;

    setState(() {
      _nameController.text = data['name'] as String? ?? '';
      _ageController.text = (data['age'] as int?)?.toString() ?? '';
      _phoneController.text = data['phone'] as String? ?? '';
      _emailController.text = data['email'] as String? ?? user.email ?? '';
      _careerType = data['careerType'] as String?;
      _gender = data['gender'] as String?;
      _birthDate = (data['birthDate'] as Timestamp?)?.toDate();
      _profileImageUrl = data['profileImageUrl'] as String?;
      final major = data['desiredMajorRole'] as String?;
      _selectedMajor = (major != null && major.isNotEmpty) ? major : null;
      _currentSubCategories =
          subCategoryMap[_selectedMajor]?.toList(growable: false) ?? const [];
      final savedSub = data['desiredSubRole'] as String?;
      _selectedSub =
          (savedSub != null && savedSub.isNotEmpty) ? savedSub : null;
      if (_selectedSub != null &&
          _selectedMajor != null &&
          !_currentSubCategories.contains(_selectedSub)) {
        _currentSubCategories = List<String>.from(_currentSubCategories)
          ..add(_selectedSub!);
      }
      _initialCity = data['desiredCity'] as String?;
      _initialDistrict = data['desiredDistrict'] as String?;
      _initialNeighborhood = data['desiredNeighborhood'] as String?;
      _selectedCity = _initialCity;
      _selectedDistrict = _initialDistrict;
      _selectedNeighborhood = _initialNeighborhood;
    });

    _applyInitialLocationSelection();
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('지역 정보를 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loadingRegions = false);
      }
    }
  }

  void _applyInitialLocationSelection() {
    if (_regions.isEmpty) return;

    String? city = _selectedCity ?? _initialCity;
    String? district = _selectedDistrict ?? _initialDistrict;
    String? neighborhood = _selectedNeighborhood ?? _initialNeighborhood;

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

  List<String> get _majorCategories =>
      subCategoryMap.keys.toList(growable: false);

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

  Future<String?> _uploadProfileImage(XFile image, String uid) async {
    final storageRef = FirebaseStorage.instance
        .ref()
        .child('users/$uid/profile.${image.name.split('.').last}');
    final metadata =
        SettableMetadata(contentType: image.mimeType ?? 'image/jpeg');

    if (kIsWeb) {
      final bytes = await image.readAsBytes();
      await storageRef.putData(bytes, metadata);
    } else {
      await storageRef.putFile(File(image.path), metadata);
    }

    return storageRef.getDownloadURL();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final result = await picker.pickImage(source: ImageSource.gallery);
    if (result != null) {
      Uint8List? bytes;
      if (kIsWeb) {
        bytes = await result.readAsBytes();
      }
      setState(() {
        _pickedImage = result;
        _pickedImageBytes = bytes;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_saving) return;

    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _saving = true);

    try {
      String? photoUrl = _profileImageUrl;
      if (_pickedImage != null) {
        photoUrl = await _uploadProfileImage(_pickedImage!, user.uid);
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': _nameController.text.trim(),
        'age': int.tryParse(_ageController.text.trim()),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'desiredMajorRole': _selectedMajor,
        'desiredSubRole': _selectedSub,
        'desiredCity': _selectedCity,
        'desiredDistrict': _selectedDistrict,
        'desiredNeighborhood': _selectedNeighborhood,
        'careerType': _careerType,
        'gender': _gender,
        'birthDate': _birthDate,
        'profileImageUrl': photoUrl,
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('프로필이 저장되었습니다.')),
      );
      context.pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('프로필 저장 중 오류가 발생했습니다: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('프로필 수정'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '기본 정보',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundImage: _buildProfileImage(),
                      child: (_pickedImage == null && _profileImageUrl == null)
                          ? const Icon(Icons.person,
                              size: 44, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('프로필 사진 선택'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildTextField(
                controller: _nameController,
                label: '이름',
                validator: (value) =>
                    value == null || value.isEmpty ? '이름을 입력해주세요.' : null,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _emailController,
                label: '이메일',
                keyboardType: TextInputType.emailAddress,
                validator: (value) =>
                    value == null || value.isEmpty ? '이메일을 입력해주세요.' : null,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _phoneController,
                label: '전화번호',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _ageController,
                label: '나이',
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return null;
                  final number = int.tryParse(value);
                  if (number == null) return '숫자로 입력해주세요.';
                  if (number <= 0) return '올바른 나이를 입력해주세요.';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _buildDatePickerField(context),
              const SizedBox(height: 12),
              _buildDropdown<String>(
                label: '성별',
                value: _gender,
                items: const ['남성', '여성', '기타'],
                onChanged: (value) => setState(() => _gender = value),
              ),
              const SizedBox(height: 24),
              const Text(
                '경력 & 희망 정보',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              _buildDropdown<String>(
                label: '경력 구분',
                value: _careerType,
                items: const ['신입', '경력'],
                onChanged: (value) => setState(() => _careerType = value),
              ),
              const SizedBox(height: 12),
              _buildCategorySelectors(),
              const SizedBox(height: 12),
              _buildRegionDropdowns(),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: const Color(0xFF6D5CFF),
                  ),
                  child: Text(_saving ? '저장 중...' : '저장하기'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySelectors() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('희망 직무/분야', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        _styledDropdown<String>(
          hint: '대분류 선택',
          value: _selectedMajor,
          items: _majorCategories,
          onChanged: (value) {
            setState(() {
              _selectedMajor = value;
              _selectedSub = null;
              _currentSubCategories =
                  subCategoryMap[value]?.toList(growable: false) ?? const [];
            });
          },
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _styledDropdown<String>(
            key: ValueKey(_selectedMajor ?? 'none'),
            hint: '소분류 선택',
            value: _selectedSub,
            items: _currentSubCategories,
            enabled: _selectedMajor != null,
            onChanged: (value) => setState(() => _selectedSub = value),
          ),
        ),
      ],
    );
  }

  Widget _buildRegionDropdowns() {
    const labelStyle = TextStyle(fontWeight: FontWeight.w700);

    if (_loadingRegions) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_cityOptions.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('희망 근무 지역', style: labelStyle),
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
        const Text('희망 근무 지역', style: labelStyle),
        const SizedBox(height: 12),
        _styledDropdown<String>(
          hint: '시 선택',
          value: _selectedCity,
          items: _cityOptions,
          onChanged: (value) {
            setState(() {
              _selectedCity = value;
              _selectedDistrict = null;
              _selectedNeighborhood = null;
            });
          },
        ),
        const SizedBox(height: 12),
        _styledDropdown<String>(
          hint: '구 선택',
          value: _selectedDistrict,
          items: _selectedDistrictOptions,
          enabled: _selectedCity != null,
          onChanged: (value) {
            setState(() {
              _selectedDistrict = value;
              _selectedNeighborhood = null;
            });
          },
        ),
        const SizedBox(height: 12),
        _styledDropdown<String>(
          hint: '동 선택',
          value: _selectedNeighborhood,
          items: _selectedNeighborhoodOptions,
          enabled: _selectedDistrict != null,
          onChanged: (value) => setState(() => _selectedNeighborhood = value),
        ),
      ],
    );
  }

  Widget _styledDropdown<T>({
    Key? key,
    required String hint,
    required T? value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    bool enabled = true,
  }) {
    return InputDecorator(
      key: key,
      decoration: const InputDecoration(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: Color(0xFFE5E5EA)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: Color(0xFFE5E5EA)),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(hint),
          isExpanded: true,
          items: items
              .map(
                (item) => DropdownMenuItem<T>(
                  value: item,
                  child: Text('$item'),
                ),
              )
              .toList(),
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE3E3E3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE3E3E3)),
        ),
      ),
      keyboardType: keyboardType,
      validator: validator,
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE3E3E3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE3E3E3)),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(label),
          isExpanded: true,
          items: items
              .map(
                (item) => DropdownMenuItem<T>(
                  value: item,
                  child: Text('$item'),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildDatePickerField(BuildContext context) {
    final display = _birthDate == null
        ? '생년월일 선택'
        : '${_birthDate!.year}.${_birthDate!.month.toString().padLeft(2, '0')}.${_birthDate!.day.toString().padLeft(2, '0')}';
    return GestureDetector(
      onTap: () async {
        final now = DateTime.now();
        final initialDate = _birthDate ?? DateTime(now.year - 20);
        final picked = await showDatePicker(
          context: context,
          initialDate: initialDate,
          firstDate: DateTime(1950),
          lastDate: now,
        );
        if (picked != null) {
          setState(() => _birthDate = picked);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: '생년월일',
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE3E3E3)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE3E3E3)),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              display,
              style: TextStyle(
                color: _birthDate == null ? AppColors.subtext : AppColors.text,
              ),
            ),
            const Icon(Icons.calendar_today_outlined, size: 18),
          ],
        ),
      ),
    );
  }

  ImageProvider<Object>? _buildProfileImage() {
    final image = _pickedImage;
    if (image != null) {
      if (kIsWeb) {
        final bytes = _pickedImageBytes;
        if (bytes != null) {
          return MemoryImage(bytes) as ImageProvider<Object>;
        }
        return null;
      }
      return FileImage(File(image.path)) as ImageProvider<Object>;
    }

    final url = _profileImageUrl;
    if (url != null) {
      return NetworkImage(url) as ImageProvider<Object>;
    }

    return null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }
}

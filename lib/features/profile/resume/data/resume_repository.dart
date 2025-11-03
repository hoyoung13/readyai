import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai/features/profile/resume/models/resume.dart';

class ResumeRepository {
  ResumeRepository._(this._prefs);

  static const _storageKey = 'profile.resumes';

  static ResumeRepository? _instance;

  static Future<ResumeRepository> instance() async {
    if (_instance != null) {
      return _instance!;
    }

    final prefs = await SharedPreferences.getInstance();
    _instance = ResumeRepository._(prefs);
    return _instance!;
  }

  final SharedPreferences _prefs;

  Future<List<Resume>> fetchAll() async {
    final stored = _prefs.getStringList(_storageKey);
    if (stored == null) {
      return [];
    }

    return stored
        .map((entry) => Resume.fromJson(entry))
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<void> save(Resume resume) async {
    final resumes = await fetchAll();
    final updated = <Resume>[
      resume,
      ...resumes.where((element) => element.id != resume.id),
    ];

    await _prefs.setStringList(
      _storageKey,
      updated.map((resume) => resume.toJson()).toList(),
    );
  }
}
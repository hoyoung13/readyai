import 'dart:convert';

enum ResumeCompletionStatus { completed, inProgress }

class Resume {
  Resume({
    required this.id,
    required this.title,
    required this.name,
    required this.phone,
    required this.email,
    this.address,
    this.summary,
    required this.education,
    required this.experience,
    this.certificates,
    this.skills,
    this.projects,
    this.additional,
    required this.isPublic,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String name;
  final String phone;
  final String email;
  final String? address;
  final String? summary;
  final String education;
  final String experience;
  final String? certificates;
  final String? skills;
  final String? projects;
  final String? additional;
  final bool isPublic;
  final DateTime updatedAt;

  ResumeCompletionStatus get completionStatus =>
      education.trim().isNotEmpty && experience.trim().isNotEmpty
          ? ResumeCompletionStatus.completed
          : ResumeCompletionStatus.inProgress;

  String get formattedDate =>
      '${updatedAt.month.toString().padLeft(2, '0')}-${updatedAt.day.toString().padLeft(2, '0')}';

String get formattedContent {
    final buffer = StringBuffer();

    buffer
      ..writeln('[기본 정보]')
      ..writeln('이름: $name')
      ..writeln('연락처: $phone')
      ..writeln('이메일: $email');

    if (address != null && address!.trim().isNotEmpty) {
      buffer.writeln('주소: ${address!.trim()}');
    }

    if (summary != null && summary!.trim().isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('[간단 소개/목표]')
        ..writeln(summary!.trim());
    }

    buffer
      ..writeln()
      ..writeln('[학력]')
      ..writeln(education.trim())
      ..writeln()
      ..writeln('[경력]')
      ..writeln(experience.trim());

    if (certificates != null && certificates!.trim().isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('[자격증·수상 내역]')
        ..writeln(certificates!.trim());
    }

    if (skills != null && skills!.trim().isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('[보유 기술]')
        ..writeln(skills!.trim());
    }

    if (projects != null && projects!.trim().isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('[프로젝트·활동]')
        ..writeln(projects!.trim());
    }

    if (additional != null && additional!.trim().isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('[기타]')
        ..writeln(additional!.trim());
    }

    buffer
      ..writeln()
      ..writeln('[PDF/HWP 저장 가이드]')
      ..writeln('1. 위 이력서 내용을 모두 선택해 복사합니다.')
      ..writeln('2. 한글 또는 MS Word에 붙여 넣습니다.')
      ..writeln('3. 문서를 원하는 양식으로 정리한 뒤, 내보내기/다른 이름으로 저장을 통해 PDF 또는 HWP 형식으로 저장합니다.');

    return buffer.toString().trimRight();
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'name': name,
        'phone': phone,
        'email': email,
        'address': address,
        'summary': summary,
        'education': education,
        'experience': experience,
        'certificates': certificates,
        'skills': skills,
        'projects': projects,
        'additional': additional,
        'isPublic': isPublic,
        'updatedAt': updatedAt.toIso8601String(),
      };

  String toJson() => jsonEncode(toMap());

  factory Resume.fromMap(Map<String, dynamic> map) => Resume(
        id: map['id'] as String,
        title: map['title'] as String,
        name: (map['name'] as String?) ?? '',
        phone: (map['phone'] as String?) ?? '',
        email: (map['email'] as String?) ?? '',
        address: map['address'] as String?,
        summary: map['summary'] as String?,
        education: map['education'] as String,
        experience: map['experience'] as String,
        certificates: map['certificates'] as String?,
        skills: map['skills'] as String?,
        projects: map['projects'] as String?,
        additional: map['additional'] as String?,
        isPublic: map['isPublic'] as bool,
        updatedAt: DateTime.parse(map['updatedAt'] as String),
      );

  factory Resume.fromJson(String source) =>
      Resume.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
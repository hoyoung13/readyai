import 'dart:convert';

enum ResumeCompletionStatus { completed, inProgress }

class Resume {
  Resume({
    required this.id,
    required this.title,
    required this.education,
    required this.experience,
    this.certificates,
    this.preferences,
    this.coverLetter,
    this.portfolio,
    required this.isPublic,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String education;
  final String experience;
  final String? certificates;
  final String? preferences;
  final String? coverLetter;
  final String? portfolio;
  final bool isPublic;
  final DateTime updatedAt;

  ResumeCompletionStatus get completionStatus =>
      education.trim().isNotEmpty && experience.trim().isNotEmpty
          ? ResumeCompletionStatus.completed
          : ResumeCompletionStatus.inProgress;

  String get formattedDate =>
      '${updatedAt.month.toString().padLeft(2, '0')}-${updatedAt.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'education': education,
        'experience': experience,
        'certificates': certificates,
        'preferences': preferences,
        'coverLetter': coverLetter,
        'portfolio': portfolio,
        'isPublic': isPublic,
        'updatedAt': updatedAt.toIso8601String(),
      };

  String toJson() => jsonEncode(toMap());

  factory Resume.fromMap(Map<String, dynamic> map) => Resume(
        id: map['id'] as String,
        title: map['title'] as String,
        education: map['education'] as String,
        experience: map['experience'] as String,
        certificates: map['certificates'] as String?,
        preferences: map['preferences'] as String?,
        coverLetter: map['coverLetter'] as String?,
        portfolio: map['portfolio'] as String?,
        isPublic: map['isPublic'] as bool,
        updatedAt: DateTime.parse(map['updatedAt'] as String),
      );

  factory Resume.fromJson(String source) =>
      Resume.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
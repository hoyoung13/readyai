import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ai/features/camera/interview_models.dart';

class InterviewRecord {
  InterviewRecord({
    required this.id,
    required this.category,
    required this.mode,
    required this.questions,
    required this.result,
    required this.createdAt,
    required this.categoryKey,
    required this.folderId,
    this.practiceName,
    this.videoUrl,
    this.videoStoragePath,
  });

  final String id;
  final JobCategory category;
  final InterviewMode mode;
  final List<String> questions;
  final InterviewRecordingResult result;
  final DateTime createdAt;
  final String categoryKey;
  final String folderId;
  final String? practiceName;
  final String? videoUrl;
  final String? videoStoragePath;

  factory InterviewRecord.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    final rawCategory = data['category'] as Map<String, dynamic>?;
    final rawQuestions = data['questions'] as List<dynamic>? ?? const [];
    final timestamp = data['createdAt'];
    final categoryKey = data['categoryKey'] as String?;
    final resultMap = data['result'] as Map<String, dynamic>?;
    final result = InterviewRecordingResult.fromMap(resultMap);

    final resolvedCategoryKey =
        categoryKey ?? buildCategoryKey(JobCategory.fromMap(rawCategory));

    DateTime createdAt;
    if (timestamp is Timestamp) {
      createdAt = timestamp.toDate();
    } else if (timestamp is DateTime) {
      createdAt = timestamp;
    } else {
      createdAt = DateTime.now();
    }

    return InterviewRecord(
      id: doc.id,
      category: JobCategory.fromMap(rawCategory),
      mode: interviewModeFromName(
        data['mode'] as String? ?? InterviewMode.ai.name,
      ),
      questions: rawQuestions.whereType<String>().toList(),
      result: result,
      createdAt: createdAt,
      categoryKey: resolvedCategoryKey,
      folderId: data['folderId'] as String? ?? resolvedCategoryKey,
      practiceName: (data['practiceName'] as String?)?.trim(),
      videoUrl: result.videoUrl,
      videoStoragePath: result.videoStoragePath,
    );
  }
}

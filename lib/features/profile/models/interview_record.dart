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
  });

  final String id;
  final JobCategory category;
  final InterviewMode mode;
  final List<String> questions;
  final InterviewRecordingResult result;
  final DateTime createdAt;

  factory InterviewRecord.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    final rawCategory = data['category'] as Map<String, dynamic>?;
    final rawQuestions = data['questions'] as List<dynamic>? ?? const [];
    final timestamp = data['createdAt'];

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
      result: InterviewRecordingResult.fromMap(
          data['result'] as Map<String, dynamic>?),
      createdAt: createdAt,
    );
  }
}

import 'package:ai/features/camera/services/azure_face_service.dart';

class JobCategory {
  const JobCategory({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  Map<String, dynamic> toMap() => {
        'title': title,
        'subtitle': subtitle,
      };

  factory JobCategory.fromMap(Map<String, dynamic>? map) {
    final data = map ?? const <String, dynamic>{};
    return JobCategory(
      title: data['title'] as String? ?? '미지정',
      subtitle: data['subtitle'] as String? ?? '',
    );
  }
}

enum InterviewMode { ai, selfIntro }

extension InterviewModeX on InterviewMode {
  String get title {
    switch (this) {
      case InterviewMode.ai:
        return 'AI 질문 면접';
      case InterviewMode.selfIntro:
        return '자기소개';
    }
  }

  String get description {
    switch (this) {
      case InterviewMode.ai:
        return '직무 기반 질문으로 실전처럼 연습해요.';
      case InterviewMode.selfIntro:
        return '자기소개 영상을 촬영하고 바로 피드백 받아요.';
    }
  }
}

InterviewMode interviewModeFromName(String value) {
  return InterviewMode.values.firstWhere(
    (mode) => mode.name == value,
    orElse: () => InterviewMode.ai,
  );
}

class InterviewCameraArgs {
  const InterviewCameraArgs({
    required this.category,
    required this.mode,
    this.questions = const [],
  });
  final JobCategory category;
  final InterviewMode mode;
  final List<String> questions;
}

class QuestionFeedback {
  const QuestionFeedback({
    required this.question,
    required this.feedback,
    this.score,
  });

  final String question;
  final String feedback;
  final double? score;
  Map<String, dynamic> toMap() => {
        'question': question,
        'feedback': feedback,
        if (score != null) 'score': score,
      };

  factory QuestionFeedback.fromMap(Map<String, dynamic>? map) {
    final data = map ?? const <String, dynamic>{};
    return QuestionFeedback(
      question: data['question'] as String? ?? '',
      feedback: data['feedback'] as String? ?? '',
      score: (data['score'] as num?)?.toDouble(),
    );
  }
}

class InterviewScore {
  const InterviewScore({
    required this.overallScore,
    this.perQuestionFeedback = const [],
  });

  final double overallScore;
  final List<QuestionFeedback> perQuestionFeedback;
  Map<String, dynamic> toMap() => {
        'overallScore': overallScore,
        'perQuestionFeedback':
            perQuestionFeedback.map((feedback) => feedback.toMap()).toList(),
      };

  factory InterviewScore.fromMap(Map<String, dynamic>? map) {
    final data = map ?? const <String, dynamic>{};
    final feedbackList =
        (data['perQuestionFeedback'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(QuestionFeedback.fromMap)
            .toList();
    return InterviewScore(
      overallScore: (data['overallScore'] as num?)?.toDouble() ?? 0,
      perQuestionFeedback: feedbackList,
    );
  }
}

class InterviewRecordingResult {
  const InterviewRecordingResult({
    required this.filePath,
    this.transcript,
    this.transcriptConfidence,
    this.score,
    this.faceAnalysis,
    this.faceAnalysisError,
    this.transcriptionError,
    this.evaluationError,
    this.videoUrl,
    this.videoStoragePath,
  });
  final String filePath;
  final String? transcript;
  final double? transcriptConfidence;
  final InterviewScore? score;
  final FaceAnalysisResult? faceAnalysis;
  final String? faceAnalysisError;
  final String? transcriptionError;
  final String? evaluationError;
  final String? videoUrl;
  final String? videoStoragePath;
  bool get hasTranscriptionError => transcriptionError != null;

  bool get hasEvaluationError => evaluationError != null;

  bool get hasFaceAnalysisError => faceAnalysisError != null;

  bool get hasError =>
      hasTranscriptionError || hasEvaluationError || hasFaceAnalysisError;
  Map<String, dynamic> toMap() => {
        'filePath': filePath,
        if (videoUrl != null) 'videoUrl': videoUrl,
        if (videoStoragePath != null) 'videoStoragePath': videoStoragePath,
        if (transcript != null) 'transcript': transcript,
        if (transcriptConfidence != null)
          'transcriptConfidence': transcriptConfidence,
        if (score != null) 'score': score!.toMap(),
        if (faceAnalysis != null) 'faceAnalysis': faceAnalysis!.toMap(),
        if (faceAnalysisError != null) 'faceAnalysisError': faceAnalysisError,
        if (transcriptionError != null)
          'transcriptionError': transcriptionError,
        if (evaluationError != null) 'evaluationError': evaluationError,
      };

  factory InterviewRecordingResult.fromMap(Map<String, dynamic>? map) {
    final data = map ?? const <String, dynamic>{};
    return InterviewRecordingResult(
      filePath: data['filePath'] as String? ?? '',
      transcript: data['transcript'] as String?,
      transcriptConfidence: (data['transcriptConfidence'] as num?)?.toDouble(),
      score: data['score'] is Map<String, dynamic>
          ? InterviewScore.fromMap(data['score'] as Map<String, dynamic>?)
          : null,
      faceAnalysis: data['faceAnalysis'] is Map<String, dynamic>
          ? FaceAnalysisResult.fromMap(
              data['faceAnalysis'] as Map<String, dynamic>?,
            )
          : null,
      faceAnalysisError: data['faceAnalysisError'] as String?,
      transcriptionError: data['transcriptionError'] as String?,
      evaluationError: data['evaluationError'] as String?,
      videoUrl: data['videoUrl'] as String?,
      videoStoragePath: data['videoStoragePath'] as String?,
    );
  }
  InterviewRecordingResult copyWith({
    String? filePath,
    String? transcript,
    double? transcriptConfidence,
    InterviewScore? score,
    FaceAnalysisResult? faceAnalysis,
    String? faceAnalysisError,
    String? transcriptionError,
    String? evaluationError,
    String? videoUrl,
    String? videoStoragePath,
  }) {
    return InterviewRecordingResult(
      filePath: filePath ?? this.filePath,
      transcript: transcript ?? this.transcript,
      transcriptConfidence: transcriptConfidence ?? this.transcriptConfidence,
      score: score ?? this.score,
      faceAnalysis: faceAnalysis ?? this.faceAnalysis,
      faceAnalysisError: faceAnalysisError ?? this.faceAnalysisError,
      transcriptionError: transcriptionError ?? this.transcriptionError,
      evaluationError: evaluationError ?? this.evaluationError,
      videoUrl: videoUrl ?? this.videoUrl,
      videoStoragePath: videoStoragePath ?? this.videoStoragePath,
    );
  }
}

String buildCategoryKey(JobCategory category) {
  String sanitize(String value) {
    var sanitized = value.trim().toLowerCase();
    sanitized = sanitized.replaceAll(RegExp('[^a-z0-9가-힣]+'), '_');
    sanitized = sanitized.replaceAll(RegExp('_+'), '_');
    if (sanitized.startsWith('_')) {
      sanitized = sanitized.substring(1);
    }
    if (sanitized.endsWith('_')) {
      sanitized = sanitized.substring(0, sanitized.length - 1);
    }
    return sanitized;
  }

  final primary = sanitize(category.title);
  if (primary.isNotEmpty) {
    return primary;
  }

  final secondary = sanitize(category.subtitle);
  if (secondary.isNotEmpty) {
    return secondary;
  }

  final fallback = sanitize('${category.title}_${category.subtitle}');
  return fallback.isNotEmpty ? fallback : 'category';
}

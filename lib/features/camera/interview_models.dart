class JobCategory {
  const JobCategory({required this.title, required this.subtitle});

  final String title;
  final String subtitle;
}

enum InterviewMode {
  ai,
  selfIntro,
}

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

class InterviewCameraArgs {
  const InterviewCameraArgs({required this.category, required this.mode});

  final JobCategory category;
  final InterviewMode mode;
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
}

class InterviewScore {
  const InterviewScore({
    required this.overallScore,
    this.perQuestionFeedback = const [],
  });

  final double overallScore;
  final List<QuestionFeedback> perQuestionFeedback;
}

class InterviewRecordingResult {
  const InterviewRecordingResult({
    required this.filePath,
    this.transcript,
    this.transcriptConfidence,
    this.score,
    this.error,
  });
  final String filePath;
  final String? transcript;
  final double? transcriptConfidence;
  final InterviewScore? score;
  final String? error;

  bool get hasError => error != null;
}

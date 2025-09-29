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

class InterviewRecordingResult {
  const InterviewRecordingResult({required this.filePath});

  final String filePath;
}

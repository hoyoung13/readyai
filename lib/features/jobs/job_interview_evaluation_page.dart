import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'package:ai/features/camera/interview_models.dart';
import 'package:ai/features/camera/services/azure_face_service.dart';
import 'package:ai/features/camera/services/interview_video_storage_service.dart';
import 'package:ai/features/jobs/job_activity_service.dart';
import 'package:ai/features/jobs/job_posting.dart';
import 'package:ai/features/jobs/job_posting_service.dart';
import 'package:ai/features/tabs/tabs_shared.dart';

class JobInterviewEvaluationArgs {
  const JobInterviewEvaluationArgs({
    required this.result,
    required this.questions,
    this.job,
    this.resumeFile,
    this.coverLetterFile,
    this.portfolioUrl,
    this.existingSummary,
    this.jobTitle,
    this.jobCompany,
    this.isEmployerView = false,
  });

  factory JobInterviewEvaluationArgs.fromApplication({
    required JobApplicationRecord application,
    required InterviewRecordingResult result,
  }) {
    return JobInterviewEvaluationArgs(
      result: result,
      questions: application.interviewQuestions,
      existingSummary: application.interviewSummary,
      jobTitle: application.jobTitle,
      jobCompany: application.jobCompany,
      portfolioUrl: application.portfolioUrl,
      isEmployerView: true,
    );
  }

  final JobPosting? job;
  final InterviewRecordingResult result;
  final List<String> questions;
  final PlatformFile? resumeFile;
  final PlatformFile? coverLetterFile;
  final String? portfolioUrl;
  final String? existingSummary;
  final String? jobTitle;
  final String? jobCompany;
  final bool isEmployerView;

  bool get canSubmitApplication =>
      !isEmployerView &&
      job != null &&
      resumeFile != null &&
      coverLetterFile != null;

  String get displayJobTitle => job?.title ?? jobTitle ?? '면접 평가';

  String get displayCompany => job?.companyLabel ?? jobCompany ?? '기업';

  JobCategory get category => JobCategory(
        title: displayCompany,
        subtitle: displayJobTitle,
      );
}

class JobInterviewEvaluationPage extends StatefulWidget {
  const JobInterviewEvaluationPage({required this.args, super.key});

  final JobInterviewEvaluationArgs args;

  @override
  State<JobInterviewEvaluationPage> createState() =>
      _JobInterviewEvaluationPageState();
}

class _JobInterviewEvaluationPageState
    extends State<JobInterviewEvaluationPage> {
  bool _submitting = false;
  late InterviewRecordingResult _result;
  final InterviewVideoStorageService _videoStorageService =
      InterviewVideoStorageService();
  static final JobPostingService _postingService = JobPostingService();
  static final JobActivityService _activityService = JobActivityService();

  @override
  void initState() {
    super.initState();
    _result = widget.args.result;
  }

  Future<void> _submitApplication() async {
    if (!widget.args.canSubmitApplication) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('필수 정보가 없어 지원을 완료할 수 없습니다.')),
      );
      return;
    }

    final job = widget.args.job;
    if (job?.postId == null ||
        job?.postId?.isEmpty == true ||
        job?.ownerUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('채용공고 정보를 불러오지 못했습니다.')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인 후 지원할 수 있습니다.')),
      );
      return;
    }

    final resumeFile = widget.args.resumeFile!;
    final coverLetterFile = widget.args.coverLetterFile!;

    setState(() => _submitting = true);

    try {
      final categoryKey = buildCategoryKey(widget.args.category);
      var updatedResult = _result;
      if (_result.videoUrl == null && _result.filePath.isNotEmpty) {
        final uploaded = await _videoStorageService.uploadVideo(
          localFilePath: _result.filePath,
          userId: user.uid,
          categoryKey: categoryKey,
        );
        updatedResult = _result.copyWith(
          videoUrl: uploaded.downloadUrl,
          videoStoragePath: uploaded.storagePath,
        );
      }

      final resumeUrl = await _uploadAttachment(
        file: resumeFile,
        prefix: 'resume',
        postId: job!.postId!,
        userId: user.uid,
      );
      final coverLetterUrl = await _uploadAttachment(
        file: coverLetterFile,
        prefix: 'cover-letter',
        postId: job.postId!,
        userId: user.uid,
      );

      final applicantName = await _resolveApplicantName(user);
      final summary =
          widget.args.existingSummary ?? _buildInterviewSummary(updatedResult);

      await _postingService.submitApplication(
        jobPostId: job.postId!,
        ownerUid: job.ownerUid!,
        jobTitle: job.title,
        jobCompany: job.companyLabel,
        applicantUid: user.uid,
        applicantName: applicantName,
        resumeUrl: resumeUrl,
        resumeFileName: resumeFile.name,
        coverLetterUrl: coverLetterUrl,
        coverLetterFileName: coverLetterFile.name,
        portfolioUrl: widget.args.portfolioUrl,
        interviewVideoUrl: updatedResult.videoUrl,
        interviewSummary: summary,
        interviewQuestions: widget.args.questions,
        interviewResult: _buildResultPayload(updatedResult),
      );

      try {
        await _activityService.recordApplication(job);
      } on JobActivityAuthException {
        // Ignore
      }

      if (mounted) {
        setState(() {
          _result = updatedResult;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('지원서가 접수되었어요.')),
        );
        context.pop();
      }
    } on InterviewVideoUploadException catch (error) {
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(error.message)),
        );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('지원 중 문제가 발생했습니다: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<String> _uploadAttachment({
    required PlatformFile file,
    required String prefix,
    required String postId,
    required String userId,
  }) async {
    final bytes = file.bytes ??
        (file.path != null ? await File(file.path!).readAsBytes() : null);
    if (bytes == null || bytes.isEmpty) {
      throw Exception('파일을 불러올 수 없습니다. 다시 시도해 주세요.');
    }

    final storageRef = FirebaseStorage.instance.ref().child(
          'applications/$postId/$userId/$prefix-${DateTime.now().millisecondsSinceEpoch}-${file.name}',
        );

    final metadata = SettableMetadata(
      contentType: file.extension != null
          ? 'application/${file.extension}'
          : 'application/octet-stream',
      customMetadata: {
        'originalName': file.name,
        'jobPostId': postId,
        'applicantUid': userId,
      },
    );

    final task = storageRef.putData(bytes, metadata);
    await task.whenComplete(() {});
    return storageRef.getDownloadURL();
  }

  Future<String> _resolveApplicantName(User user) async {
    final displayName = user.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final profileName = (snapshot.data()?['name'] as String?)?.trim();
    if (profileName != null && profileName.isNotEmpty) {
      return profileName;
    }

    return '지원자';
  }

  Map<String, dynamic> _buildResultPayload(InterviewRecordingResult result) {
    final map = result.toMap();
    map.remove('filePath');
    map['questions'] = widget.args.questions;
    return map;
  }

  String _buildInterviewSummary(InterviewRecordingResult result) {
    final buffer = StringBuffer();
    if (result.score != null) {
      buffer.writeln('총점: ${result.score!.overallScore.toStringAsFixed(1)}점');
    }

    if (result.score?.perQuestionFeedback.isNotEmpty == true) {
      buffer.writeln('주요 피드백:');
      for (final feedback in result.score!.perQuestionFeedback.take(3)) {
        buffer.writeln('- ${feedback.question}: ${feedback.feedback}');
      }
    }

    if (buffer.isEmpty) {
      return 'AI 면접 평가를 완료했습니다.';
    }

    return buffer.toString().trim();
  }

  void _launchVideo() {
    final url = _result.videoUrl;
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('녹화 영상을 찾을 수 없습니다.')),
      );
      return;
    }
    launchUrlString(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final score = _result.score;
    final hasFaceAnalysis = _result.faceAnalysis != null;
    final showApplyButton = widget.args.canSubmitApplication;
    final summaryText =
        widget.args.existingSummary ?? _buildInterviewSummary(_result);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 면접 평가'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _JobHeader(
                company: widget.args.displayCompany,
                title: widget.args.displayJobTitle,
              ),
              const SizedBox(height: 16),
              if (_result.videoUrl != null)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _launchVideo,
                    icon: const Icon(Icons.play_circle_outline),
                    label: const Text('녹화 영상 보기'),
                  ),
                ),
              if (_result.videoUrl != null) const SizedBox(height: 16),
              if (score != null)
                _ScoreCard(score: score)
              else
                _InfoSection(
                  title: '점수 정보 없음',
                  child: const Text('AI 점수 정보를 불러오지 못했습니다.'),
                ),
              const SizedBox(height: 16),
              if (summaryText.isNotEmpty)
                _InfoSection(
                  title: 'AI 요약',
                  child: Text(
                    summaryText,
                    style: const TextStyle(height: 1.5),
                  ),
                ),
              const SizedBox(height: 16),
              if (_result.score?.perQuestionFeedback.isNotEmpty == true)
                _FeedbackList(feedback: _result.score!.perQuestionFeedback),
              const SizedBox(height: 16),
              if (widget.args.questions.isNotEmpty)
                _QuestionList(questions: widget.args.questions),
              const SizedBox(height: 16),
              if (_result.transcript != null && _result.transcript!.isNotEmpty)
                _InfoSection(
                  title: '면접 스크립트',
                  child: Text(
                    _result.transcript!,
                    style: const TextStyle(height: 1.6),
                  ),
                ),
              const SizedBox(height: 24),
              if (widget.args.portfolioUrl != null &&
                  widget.args.portfolioUrl!.trim().isNotEmpty)
                _InfoSection(
                  title: '포트폴리오',
                  child: Text(widget.args.portfolioUrl!),
                ),
              const SizedBox(height: 16),
              if (showApplyButton || widget.args.isEmployerView)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _submitting
                        ? null
                        : widget.args.isEmployerView
                            ? () => ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('결과를 확인했습니다.')),
                                )
                            : _submitApplication,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(widget.args.isEmployerView ? '저장' : '지원하기'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JobHeader extends StatelessWidget {
  const _JobHeader({required this.company, required this.title});

  final String company;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            company,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.subtext,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.score});

  final InterviewScore score;

  @override
  Widget build(BuildContext context) {
    return _InfoSection(
      title: '총점',
      child: Row(
        children: [
          const Icon(Icons.emoji_events_outlined, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            score.overallScore.toStringAsFixed(1),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 6),
          const Text('점'),
        ],
      ),
    );
  }
}

class _FeedbackList extends StatelessWidget {
  const _FeedbackList({required this.feedback});

  final List<QuestionFeedback> feedback;

  @override
  Widget build(BuildContext context) {
    return _InfoSection(
      title: '질문별 피드백',
      child: Column(
        children: feedback
            .map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.question,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.feedback,
                      style: const TextStyle(color: AppColors.subtext),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _QuestionList extends StatelessWidget {
  const _QuestionList({required this.questions});

  final List<String> questions;

  @override
  Widget build(BuildContext context) {
    return _InfoSection(
      title: '면접 질문',
      child: Column(
        children: questions
            .map(
              (q) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading:
                    const Icon(Icons.help_outline, color: AppColors.primary),
                title: Text(q),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

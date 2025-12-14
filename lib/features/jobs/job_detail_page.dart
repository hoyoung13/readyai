import 'package:characters/characters.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:ai/core/router/app_router.dart';
import 'package:ai/core/utils/role_utils.dart';
import '../tabs/tabs_shared.dart';
import 'job_interview_question_service.dart';
import 'job_activity.dart';
import 'job_activity_service.dart';
import 'job_posting.dart';
import 'job_posting_service.dart';
import 'job_interview_evaluation_page.dart';
import '../camera/interview_flow_launcher.dart';
import '../camera/interview_models.dart';
import '../camera/interview_question_bank.dart';

class JobDetailPage extends StatelessWidget {
  const JobDetailPage({required this.job, super.key});

  final JobPosting job;

  static final JobInterviewQuestionService _questionService =
      JobInterviewQuestionService();
  static const InterviewFlowLauncher _interviewLauncher =
      InterviewFlowLauncher();
  static final JobActivityService _activityService = JobActivityService();
  static final JobPostingService _postingService = JobPostingService();

  @override
  Widget build(BuildContext context) {
    final trimmedDescription = job.description.trim();
    final trimmedNotice = job.notice.trim();
    final hasApplicationPeriod =
        job.applicationStartDateText.trim().isNotEmpty ||
            job.applicationEndDateText.trim().isNotEmpty;
    final jobRoleRow = _findDetailRow(['자격', '요건', '필수']);
    final preferredRow = _findDetailRow(['우대']);
    final welfareRow = _findDetailRow(['복지', '혜택', '복리후생']);

    final summaryItems = <JobSummaryItem>[...job.summaryItems];
    if (hasApplicationPeriod) {
      summaryItems.add(JobSummaryItem(
        label: '모집기간',
        value: _formatApplicationPeriod(
          job.applicationStartDateText,
          job.applicationEndDateText,
        ),
      ));
    }
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('채용공고 상세'),
      ),
      bottomNavigationBar: isCompanyRole(userRoleCache.value)
          ? null
          : ApplyBottomBar(onApply: () => _handleApply(context)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            JobHeader(
              job: job,
              activityService: _activityService,
              onToggleScrap: (scrapped) =>
                  _handleToggleScrap(context, scrapped),
              onOpenLink: () => _launchDetail(job.url, context),
            ),
            const SizedBox(height: 16),
            if (summaryItems.isNotEmpty)
              JobSummaryCard(summaryItems: summaryItems),
            const SizedBox(height: 16),
            if (trimmedDescription.isNotEmpty)
              SectionCard(
                title: '담당 업무',
                children: [
                  Text(
                    trimmedDescription,
                    style: const TextStyle(height: 1.6),
                  ),
                ],
              ),
            if (jobRoleRow != null) ...[
              const SizedBox(height: 12),
              SectionCard(
                title: jobRoleRow.title,
                children: [
                  Text(
                    jobRoleRow.description,
                    style: const TextStyle(height: 1.6),
                  ),
                ],
              ),
            ],
            if (preferredRow != null) ...[
              const SizedBox(height: 12),
              SectionCard(
                title: preferredRow.title,
                children: [
                  Text(
                    preferredRow.description,
                    style: const TextStyle(height: 1.6),
                  ),
                ],
              ),
            ],
            if (job.tags.isNotEmpty || welfareRow != null) ...[
              const SizedBox(height: 12),
              SectionCard(
                title: '복지/혜택',
                children: [
                  if (welfareRow != null) ...[
                    Text(
                      welfareRow.description,
                      style: const TextStyle(height: 1.6),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (job.tags.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: job.tags
                          .map((tag) => _BenefitChip(label: tag))
                          .toList(),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            SectionCard(
              title: '기업 정보',
              children: [
                _InfoRow(label: '기업명', value: job.companyLabel),
                _InfoRow(label: '근무지역', value: job.regionLabel),
                if (job.prettyPostedDate != null)
                  _InfoRow(label: '등록일', value: job.prettyPostedDate!),
                if (hasApplicationPeriod)
                  _InfoRow(
                    label: '모집기간',
                    value: _formatApplicationPeriod(
                      job.applicationStartDateText,
                      job.applicationEndDateText,
                    ),
                  ),
                if (job.url.trim().isNotEmpty)
                  GestureDetector(
                    onTap: () => _launchDetail(job.url, context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 82,
                            child: Text(
                              '홈페이지',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.text,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              job.url,
                              style: const TextStyle(
                                decoration: TextDecoration.underline,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (trimmedNotice.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      trimmedNotice,
                      style: const TextStyle(height: 1.5),
                    ),
                  ),
                if (trimmedNotice.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      '본 정보는 공공데이터포털 "기획재정부_공공기관 채용정보 조회서비스"를 통해 수집되었습니다.',
                      style: TextStyle(height: 1.5),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (job.detailRows.isNotEmpty)
              SectionCard(
                title: '추가 정보',
                children: job.detailRows
                    .where((row) => !summaryItems.any(
                          (item) => item.label == row.title,
                        ))
                    .map((row) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                row.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                row.description,
                                style: const TextStyle(height: 1.6),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  JobDetailRow? _findDetailRow(List<String> keywords) {
    if (job.detailRows.isEmpty) return null;

    // 키워드를 소문자로 변환
    final lowerKeywords = keywords.map((k) => k.toLowerCase()).toList();

    for (final row in job.detailRows) {
      final title = row.title.toLowerCase();
      final description = row.description.toLowerCase();

      // 제목 또는 내용에 키워드가 포함되면 해당 row 반환
      final matches = lowerKeywords.any(
        (keyword) => title.contains(keyword) || description.contains(keyword),
      );

      if (matches) {
        return row;
      }
    }

    return null;
  }

  Future<List<String>> _prepareInterviewQuestions(
    BuildContext context,
    JobCategory category,
  ) async {
    if (!context.mounted) {
      return _mixQuestions(const [], category);
    }
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);
    var dialogOpen = true;

    void closeDialogIfOpen() {
      if (dialogOpen && rootNavigator.mounted) {
        rootNavigator.pop();
        dialogOpen = false;
      }
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    List<String> generated = const [];
    try {
      generated = await _questionService.generateQuestions(job);
    } on JobInterviewQuestionException catch (error) {
      if (!context.mounted) {
        closeDialogIfOpen();
        return _mixQuestions(const [], category);
      }
      messenger
        ..removeCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('${error.message} 기본 질문으로 진행할게요.'),
          ),
        );
    } catch (_) {
      if (!context.mounted) {
        closeDialogIfOpen();
        return _mixQuestions(const [], category);
      }
      messenger
        ..removeCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('맞춤 질문을 준비하지 못했습니다. 기본 질문으로 진행할게요.'),
          ),
        );
    } finally {
      closeDialogIfOpen();
    }

    return _mixQuestions(generated, category);
  }

  List<String> _mixQuestions(List<String> generated, JobCategory category) {
    final presetQuestions = job.interviewQuestions
        .map((q) => q.trim())
        .where((q) => q.isNotEmpty)
        .toList(growable: false);

    final pool = <String>[];
    final seen = <String>{};

    for (final question in [...presetQuestions, ...generated]) {
      if (seen.add(question)) {
        pool.add(question);
      }
    }

    final fallback = InterviewQuestionBank.getQuestions(
      category: category,
      mode: InterviewMode.ai,
    );

    for (final question in fallback) {
      if (pool.length >= _questionService.questionCount) {
        break;
      }
      if (seen.add(question)) {
        pool.add(question);
      }
    }

    if (pool.length > _questionService.questionCount) {
      pool.shuffle();
      return pool.sublist(0, _questionService.questionCount);
    }

    if (pool.length < _questionService.questionCount && fallback.isNotEmpty) {
      while (pool.length < _questionService.questionCount) {
        pool.add(fallback[pool.length % fallback.length]);
      }
    }

    pool.shuffle();
    return pool;
  }

  Future<void> _handleApply(BuildContext context) async {
    final parentContext = context;
    final postId = job.postId;
    final ownerUid = job.ownerUid;
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인 후 지원할 수 있습니다.')),
      );
      return;
    }

    if (postId == null ||
        postId.isEmpty ||
        ownerUid == null ||
        ownerUid.isEmpty) {
      _launchDetail(job.url, context);
      return;
    }

    PlatformFile? resumeFile;
    PlatformFile? coverLetterFile;
    final portfolioController = TextEditingController();

    Future<void> pickAttachment(
        {required bool isResume,
        required BuildContext scope,
        required void Function(void Function()) setState}) async {
      final result = await FilePicker.platform.pickFiles(
        withData: true,
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: const [
          'pdf',
          'doc',
          'docx',
          'ppt',
          'pptx',
          'hwp',
          'hwpx',
        ],
      );

      if (result != null && result.files.isNotEmpty) {
        if (!scope.mounted) {
          return;
        }
        setState(() {
          if (isResume) {
            resumeFile = result.files.first;
          } else {
            coverLetterFile = result.files.first;
          }
        });
      }
    }

    try {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (sheetContext) {
          final viewInsets = MediaQuery.of(sheetContext).viewInsets.bottom;
          final viewPadding = MediaQuery.of(sheetContext).padding.bottom;
          var submitting = false;
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              bottom: 20 + viewInsets + viewPadding,
              top: 20,
            ),
            child: StatefulBuilder(
              builder: (context, setState) {
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AI 지원 준비',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '필수 서류를 첨부하고 카메라 AI 질문 면접을 시작하세요. 면접 평가 페이지에서 최종 지원을 완료할 수 있습니다.',
                        style: TextStyle(color: AppColors.subtext),
                      ),
                      const SizedBox(height: 16),
                      _AttachmentPickerTile(
                        title: '이력서 파일 첨부',
                        description: 'PDF, DOC, PPT 등 최대 20MB 파일을 올려주세요.',
                        fileName: resumeFile?.name,
                        onTap: () => pickAttachment(
                          isResume: true,
                          scope: context,
                          setState: setState,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _AttachmentPickerTile(
                        title: '자기소개서 파일 첨부',
                        description: '경험과 강점을 담은 파일을 추가로 제출해 주세요.',
                        fileName: coverLetterFile?.name,
                        onTap: () => pickAttachment(
                          isResume: false,
                          scope: context,
                          setState: setState,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: portfolioController,
                        decoration: const InputDecoration(
                          labelText: '포트폴리오/링크 (선택)',
                          hintText: 'GitHub, 노션, 블로그 등 주소를 남겨주세요.',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: submitting
                              ? null
                              : () async {
                                  if (resumeFile == null ||
                                      coverLetterFile == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content:
                                              Text('이력서와 자기소개서를 모두 첨부해 주세요.')),
                                    );
                                    return;
                                  }
                                  setState(() => submitting = true);
                                  final portfolioUrl =
                                      portfolioController.text.trim();
                                  Navigator.of(sheetContext).pop();

                                  if (!parentContext.mounted) return;
                                  await _handleApplyInterview(
                                    parentContext,
                                    resumeFile: resumeFile!,
                                    coverLetterFile: coverLetterFile!,
                                    portfolioUrl: portfolioUrl.isEmpty
                                        ? null
                                        : portfolioUrl,
                                  );
                                },
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            side: const BorderSide(color: AppColors.primary),
                          ),
                          icon: const Icon(Icons.videocam_outlined),
                          label: submitting
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('카메라 AI 질문 면접 시작'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '면접이 끝나면 AI 평가 결과 페이지에서 지원을 완료할 수 있어요.',
                        style: TextStyle(color: AppColors.subtext),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      );
    } finally {
      portfolioController.dispose();
    }
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

  Future<void> _handleApplyInterview(
    BuildContext context, {
    required PlatformFile resumeFile,
    required PlatformFile coverLetterFile,
    String? portfolioUrl,
  }) async {
    if (!context.mounted) {
      return;
    }
    final category = JobCategory(
      title: job.companyLabel,
      subtitle: job.title,
    );

    final questions = await _prepareInterviewQuestions(context, category);
    if (!context.mounted) {
      return;
    }

    final result = await _interviewLauncher.recordInterview(
      context: context,
      category: category,
      mode: InterviewMode.ai,
      questions: questions,
    );
    if (!context.mounted || result == null) {
      return;
    }

    await context.push(
      '/interview/job-evaluation',
      extra: JobInterviewEvaluationArgs(
        job: job,
        result: result,
        questions: questions,
        resumeFile: resumeFile,
        coverLetterFile: coverLetterFile,
        portfolioUrl: portfolioUrl,
      ),
    );
  }

  Future<void> _launchDetail(String url, BuildContext context) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('상세 링크가 제공되지 않았습니다.')),
      );
      return;
    }
    try {
      final recorded = await _activityService.recordApplication(job);
      if (recorded && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('지원 내역에 저장했어요.')),
        );
      }
    } on JobActivityAuthException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인 후 지원 내역을 저장할 수 있어요.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('지원 내역을 저장하지 못했습니다. 다시 시도해주세요.')),
        );
      }
    }

    final launched =
        await launchUrlString(trimmed, mode: LaunchMode.externalApplication);
    if (!launched) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('상세 페이지를 열 수 없습니다.')),
      );
    }
  }

  Future<void> _handleToggleScrap(
      BuildContext context, bool currentScrapState) async {
    try {
      final scrapped = await _activityService.toggleScrap(job);
      if (!context.mounted) {
        return;
      }

      final messenger = ScaffoldMessenger.of(context);
      messenger
        ..removeCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(scrapped ? '스크랩했어요.' : '스크랩을 취소했어요.'),
          ),
        );
    } on JobActivityAuthException {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('로그인 후 이용해주세요.')),
          );
      }
    } catch (_) {
      if (context.mounted) {
        final message = currentScrapState
            ? '스크랩을 취소하지 못했습니다. 다시 시도해주세요.'
            : '스크랩을 저장하지 못했습니다. 다시 시도해주세요.';
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }
}

class JobHeader extends StatelessWidget {
  const JobHeader({
    required this.job,
    required this.activityService,
    required this.onToggleScrap,
    required this.onOpenLink,
  });

  final JobPosting job;
  final JobActivityService activityService;
  final ValueChanged<bool> onToggleScrap;
  final VoidCallback onOpenLink;

  @override
  Widget build(BuildContext context) {
    final initial = (job.companyLabel.isNotEmpty)
        ? job.companyLabel.characters.first.toUpperCase()
        : '?';
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      initial,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        job.companyLabel,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.subtext,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        job.regionLabel,
                        style: const TextStyle(color: AppColors.subtext),
                      ),
                    ],
                  ),
                ),
                StreamBuilder<JobActivity?>(
                  stream: activityService.watch(job),
                  builder: (context, snapshot) {
                    final scrapped = snapshot.data?.scrapped ?? false;
                    return IconButton(
                      onPressed: () => onToggleScrap(scrapped),
                      icon: Icon(
                        scrapped ? Icons.star : Icons.star_border,
                        color: scrapped ? AppColors.primary : AppColors.subtext,
                      ),
                      tooltip: scrapped ? '스크랩 취소' : '스크랩',
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (job.prettyPostedDate != null)
                  _InfoTag(
                    icon: Icons.calendar_today_outlined,
                    label: job.prettyPostedDate!,
                  ),
                if (job.tags.isNotEmpty)
                  _InfoTag(
                    icon: Icons.label_outline,
                    label: job.tagsSummary,
                  ),
                if (job.hasUrl)
                  InkWell(
                    onTap: onOpenLink,
                    child: const _InfoTag(
                      icon: Icons.open_in_new,
                      label: '상세 보기',
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class JobSummaryCard extends StatelessWidget {
  const JobSummaryCard({required this.summaryItems});

  final List<JobSummaryItem> summaryItems;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '요약 정보',
      children: [
        Wrap(
          runSpacing: 10,
          spacing: 12,
          children: summaryItems
              .map(
                (item) => SizedBox(
                  width: (MediaQuery.of(context).size.width - 72) / 2,
                  child: _InfoRow(label: item.label, value: item.value),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class ApplyBottomBar extends StatelessWidget {
  const ApplyBottomBar({required this.onApply});

  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 10,
        bottom: 10 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: onApply,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('지원하기'),
          ),
        ),
      ),
    );
  }
}

class _AttachmentPickerTile extends StatelessWidget {
  const _AttachmentPickerTile({
    required this.title,
    required this.description,
    required this.onTap,
    this.fileName,
  });

  final String title;
  final String description;
  final VoidCallback onTap;
  final String? fileName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primarySoft),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(color: AppColors.subtext),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
            ),
            icon: const Icon(Icons.attach_file_outlined),
            label: Text(fileName ?? '파일 선택'),
          ),
        ],
      ),
    );
  }
}

class _InfoTag extends StatelessWidget {
  const _InfoTag({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE6E6E6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.subtext),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}

class ModernSectionCard extends StatelessWidget {
  const ModernSectionCard({
    super.key,
    required this.title,
    required this.children,
    this.icon,
    this.separated = false,
  });

  final String title;
  final List<Widget> children;
  final IconData? icon;
  final bool separated;

  List<Widget> get _spacedChildren {
    if (!separated || children.length <= 1) {
      return children;
    }

    final widgets = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      widgets.add(children[i]);
      if (i != children.length - 1) {
        widgets.add(
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(
              height: 1,
              thickness: 1,
              color: Color(0xFFE7E7E7),
            ),
          ),
        );
      }
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: AppColors.text),
                const SizedBox(width: 8),
              ],
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._spacedChildren,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 82,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.text,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatApplicationPeriod(String start, String end) {
  final hasStart = start.trim().isNotEmpty;
  final hasEnd = end.trim().isNotEmpty;

  if (hasStart && hasEnd) return '$start ~ $end';
  if (hasStart) return '$start ~ 마감일 미정';
  if (hasEnd) return '시작일 미정 ~ $end';
  return '기간 미정';
}

class _BenefitChip extends StatelessWidget {
  const _BenefitChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return ModernTag(label: label);
  }
}

class ModernTag extends StatelessWidget {
  const ModernTag({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE6E6E6)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.text,
        ),
      ),
    );
  }
}

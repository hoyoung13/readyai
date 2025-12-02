import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../tabs/tabs_shared.dart';
import 'job_interview_question_service.dart';
import 'job_activity.dart';
import 'job_activity_service.dart';
import 'job_posting.dart';
import 'job_posting_service.dart';
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
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('채용공고 상세'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HeaderCard(
              job: job,
              activityService: _activityService,
              onToggleScrap: (scrapped) =>
                  _handleToggleScrap(context, scrapped),
            ),
            const SizedBox(height: 16),
            _PrimaryActions(
              onApply: () => _handleApply(context),
              onPractice: () => _handleStartInterview(context),
            ),
            const SizedBox(height: 24),
            if (job.summaryItems.isNotEmpty)
              _InfoBlock(
                title: '공고 요약',
                separated: true,
                children: job.summaryItems
                    .map(
                      (item) => _InfoRow(
                        label: item.label,
                        value: item.value,
                      ),
                    )
                    .toList(growable: false),
              ),
            if (job.summaryItems.isNotEmpty) const SizedBox(height: 16),
            if (hasApplicationPeriod)
              _InfoBlock(
                title: '접수 기간',
                separated: true,
                children: [
                  _InfoRow(
                    label: '기간',
                    value: _formatApplicationPeriod(
                      job.applicationStartDateText,
                      job.applicationEndDateText,
                    ),
                  ),
                ],
              ),
            if (hasApplicationPeriod) const SizedBox(height: 16),
            _InfoBlock(
              title: '기본 정보',
              separated: true,
              children: [
                _InfoRow(label: '기업명', value: job.companyLabel),
                _InfoRow(label: '근무지', value: job.regionLabel),
                _InfoRow(
                  label: '등록일',
                  value: job.prettyPostedDate ?? '정보 없음',
                ),
                _InfoRow(
                  label: '상세 링크',
                  value: job.hasUrl ? job.url : '제공되지 않음',
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (trimmedDescription.isNotEmpty)
              _InfoBlock(
                title: '상세 설명',
                children: [
                  Text(
                    trimmedDescription,
                    style: const TextStyle(height: 1.5),
                  ),
                ],
              ),
            if (trimmedDescription.isNotEmpty) const SizedBox(height: 16),
            if (job.detailRows.isNotEmpty)
              _InfoBlock(
                title: '상세 정보',
                separated: true,
                children: job.detailRows
                    .map(
                      (row) => Padding(
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
                              style: const TextStyle(height: 1.5),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            if (job.detailRows.isNotEmpty) const SizedBox(height: 16),
            if (job.tags.isNotEmpty)
              _InfoBlock(
                title: '복리후생 / 태그',
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: job.tags
                        .map((tag) => _BenefitChip(label: tag))
                        .toList(growable: false),
                  ),
                ],
              ),
            if (job.tags.isNotEmpty) const SizedBox(height: 16),
            _InfoBlock(
              title: '안내',
              children: [
                Text(
                  trimmedNotice.isNotEmpty
                      ? trimmedNotice
                      : '본 정보는 공공데이터포털 "기획재정부_공공기관 채용정보 조회서비스"를 통해 수집되었습니다.',
                  style: const TextStyle(height: 1.5),
                ),
                if (trimmedNotice.isNotEmpty) const SizedBox(height: 8),
              ],
            ),
          ],
        ),
      ),
    );
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

    Future<void> pickAttachment(
        {required bool isResume,
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
        setState(() {
          if (isResume) {
            resumeFile = result.files.first;
          } else {
            coverLetterFile = result.files.first;
          }
        });
      }
    }

    Future<String> uploadAttachment(PlatformFile file, String prefix) async {
      final bytes = file.bytes;
      if (bytes == null) {
        throw Exception('파일을 불러올 수 없습니다. 다시 선택해 주세요.');
      }

      final storageRef = FirebaseStorage.instance.ref().child(
            'applications/$postId/${user.uid}/$prefix-${DateTime.now().millisecondsSinceEpoch}-${file.name}',
          );

      final metadata = SettableMetadata(
        contentType: file.extension != null
            ? 'application/${file.extension}'
            : 'application/octet-stream',
        customMetadata: {
          'originalName': file.name,
          'jobPostId': postId,
          'applicantUid': user.uid,
        },
      );

      await storageRef.putData(bytes, metadata);
      return storageRef.getDownloadURL();
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        var submitting = false;
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: 20 + MediaQuery.of(sheetContext).viewInsets.bottom,
            top: 20,
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AI 지원하기',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '이력서와 자기소개서를 파일로 제출하고, 카메라 AI 면접으로 답변을 녹화하세요.',
                      style: TextStyle(color: AppColors.subtext),
                    ),
                    const SizedBox(height: 16),
                    _AttachmentPickerTile(
                      title: '이력서 파일 첨부',
                      description: 'PDF, DOC, PPT 등 최대 20MB 파일을 올려주세요.',
                      fileName: resumeFile?.name,
                      onTap: () => pickAttachment(
                        isResume: true,
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
                        setState: setState,
                      ),
                    ),
                    const SizedBox(height: 18),
                    OutlinedButton.icon(
                      onPressed: submitting
                          ? null
                          : () async {
                              if (context.mounted) {
                                Navigator.of(context).pop();
                              }
                              await _handleStartInterview(parentContext);
                            },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        side: const BorderSide(color: AppColors.primary),
                      ),
                      icon: const Icon(Icons.videocam_outlined),
                      label: const Text('카메라 AI 질문 면접 시작'),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '카메라로 답변을 녹화하면 AI가 질문 면접을 도와줘요.',
                      style: TextStyle(color: AppColors.subtext),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: submitting
                            ? null
                            : () async {
                                if (resumeFile == null ||
                                    coverLetterFile == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text('이력서와 자기소개서 파일을 모두 첨부해 주세요.'),
                                    ),
                                  );
                                  return;
                                }

                                setState(() => submitting = true);

                                try {
                                  final resumeUrl = await uploadAttachment(
                                    resumeFile!,
                                    'resume',
                                  );
                                  final coverLetterUrl = await uploadAttachment(
                                    coverLetterFile!,
                                    'cover-letter',
                                  );
                                  final applicantName =
                                      await _resolveApplicantName(user);
                                  await _postingService.submitApplication(
                                    jobPostId: postId,
                                    ownerUid: ownerUid,
                                    jobTitle: job.title,
                                    jobCompany: job.companyLabel,
                                    applicantUid: user.uid,
                                    applicantName: applicantName,
                                    resumeUrl: resumeUrl,
                                    resumeFileName: resumeFile?.name,
                                    coverLetterUrl: coverLetterUrl,
                                    coverLetterFileName: coverLetterFile?.name,
                                  );
                                  try {
                                    await _activityService
                                        .recordApplication(job);
                                  } on JobActivityAuthException {}
                                  if (context.mounted) {
                                    Navigator.of(context).pop();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            '지원서가 접수되었어요. AI 면접 결과를 기다려 주세요!'),
                                      ),
                                    );
                                  }
                                } catch (error) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('지원 중 문제가 발생했습니다: $error'),
                                    ),
                                  );
                                } finally {
                                  setState(() => submitting = false);
                                }
                              },
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: submitting
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('AI 분석과 함께 지원하기'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
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

  Future<void> _handleStartInterview(BuildContext context) async {
    final category = JobCategory(
      title: job.companyLabel,
      subtitle: job.title,
    );

    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);
    var dialogOpen = true;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return const Center(child: CircularProgressIndicator());
      },
    );

    List<String> questions;
    try {
      questions = await _questionService.generateQuestions(job);
    } on JobInterviewQuestionException catch (error) {
      questions = InterviewQuestionBank.getQuestions(
        category: category,
        mode: InterviewMode.ai,
      );
      messenger
        ..removeCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('${error.message} 기본 질문으로 진행할게요.'),
          ),
        );
    } catch (_) {
      questions = InterviewQuestionBank.getQuestions(
        category: category,
        mode: InterviewMode.ai,
      );
      messenger
        ..removeCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('맞춤 질문을 준비하지 못했습니다. 기본 질문으로 진행할게요.'),
          ),
        );
    } finally {
      if (dialogOpen && rootNavigator.mounted) {
        rootNavigator.pop();
        dialogOpen = false;
      }
    }

    if (!context.mounted) {
      return;
    }

    await _interviewLauncher.launch(
      context: context,
      category: category,
      mode: InterviewMode.ai,
      questions: questions,
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

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.job,
    required this.activityService,
    required this.onToggleScrap,
  });

  final JobPosting job;
  final JobActivityService activityService;
  final ValueChanged<bool> onToggleScrap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.business_center_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.companyLabel,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.subtext,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      job.title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
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
                      scrapped ? Icons.star : Icons.star_outline,
                      color: scrapped ? Colors.amber : AppColors.subtext,
                    ),
                    tooltip: scrapped ? '스크랩 취소' : '스크랩',
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoTag(
                icon: Icons.place_outlined,
                label: job.regionLabel,
              ),
              if (job.prettyPostedDate != null)
                _InfoTag(
                  icon: Icons.event_note,
                  label: '${job.prettyPostedDate} 등록',
                ),
              if (job.occupations.isNotEmpty)
                _InfoTag(
                  icon: Icons.work_outline,
                  label: job.occupations.join(', '),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PrimaryActions extends StatelessWidget {
  const _PrimaryActions({
    required this.onApply,
    required this.onPractice,
  });

  final VoidCallback onApply;
  final VoidCallback onPractice;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primarySoft),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '지원 및 준비',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onApply,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(54),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.assignment_turned_in_outlined),
            label: const Text('AI 분석과 함께 지원하기'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onPractice,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              minimumSize: const Size.fromHeight(52),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.smart_toy_outlined),
            label: const Text('AI 면접 연습 시작'),
          ),
          const SizedBox(height: 6),
          const Text(
            '이력서/자기소개서 파일 제출과 AI 면접 준비를 한 번에 진행할 수 있어요.',
            style: TextStyle(
              color: AppColors.subtext,
              fontSize: 13,
            ),
          ),
        ],
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
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({
    required this.title,
    required this.children,
    this.separated = false,
  });

  final String title;
  final List<Widget> children;
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
            padding: EdgeInsets.symmetric(vertical: 10),
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
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.15)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: AppColors.text,
        ),
      ),
    );
  }
}

import 'dart:io';
import 'package:ai/features/camera/interview_models.dart';
import 'package:ai/features/jobs/job_interview_evaluation_page.dart';
import 'package:ai/features/jobs/job_posting_service.dart';
import 'package:ai/features/notifications/notification_service.dart';
import 'package:ai/features/tabs/tabs_shared.dart';
import 'package:ai/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import 'package:ai/features/common/pdf_viewer_page.dart';

class CompanyApplicantOverviewPage extends StatefulWidget {
  const CompanyApplicantOverviewPage({super.key});

  @override
  State<CompanyApplicantOverviewPage> createState() =>
      _CompanyApplicantOverviewPageState();
}

class _CompanyApplicantOverviewPageState
    extends State<CompanyApplicantOverviewPage> {
  final JobPostingService _service = JobPostingService();
  final NotificationService _notificationService = NotificationService();
  JobPostRecord? _selectedJob;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('로그인 후 이용해 주세요.')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('지원 현황 보기'),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              children: const [
                Text(
                  '본인이 등록한 채용공고를 선택하면 지원 내역이 표시돼요.',
                  style: TextStyle(color: AppColors.subtext),
                ),
              ],
            ),
          ),
        ),
      ),
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          _JobPicker(
            service: _service,
            ownerUid: user.uid,
            selectedJob: _selectedJob,
            onSelected: (job) => setState(() => _selectedJob = job),
          ),
          Expanded(
            child: _ApplicantList(
              service: _service,
              ownerUid: user.uid,
              selectedJob: _selectedJob,
              notificationService: _notificationService,
            ),
          ),
        ],
      ),
    );
  }
}

class _JobPicker extends StatelessWidget {
  const _JobPicker({
    required this.service,
    required this.ownerUid,
    required this.selectedJob,
    required this.onSelected,
  });

  final JobPostingService service;
  final String ownerUid;
  final JobPostRecord? selectedJob;
  final ValueChanged<JobPostRecord> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: StreamBuilder<List<JobPostRecord>>(
        stream: service.streamOwnerPosts(ownerUid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final posts = snapshot.data ?? const <JobPostRecord>[];
          if (posts.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('등록한 채용공고가 없습니다. 공고를 먼저 등록해주세요.'),
              ),
            );
          }

          final currentSelection = selectedJob;
          if (currentSelection == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              onSelected(posts.first);
            });
          }

          final controller = PageController(viewportFraction: 0.9);

          return PageView.builder(
            controller: controller,
            itemCount: posts.length,
            padEnds: false,
            itemBuilder: (context, index) {
              final post = posts[index];
              final isSelected = post.id == selectedJob?.id;
              return Padding(
                  padding: EdgeInsets.only(
                    left: index == 0 ? 16 : 10,
                    right: index == posts.length - 1 ? 16 : 10,
                    top: 14,
                    bottom: 10,
                  ),
                  child: _JobCard(
                    post: post,
                    selected: isSelected,
                    service: service,
                    onTap: () => onSelected(post),
                  ));
            },
            onPageChanged: (page) {
              final post = posts[page];
              if (post.id != selectedJob?.id) {
                onSelected(post);
              }
            },
          );
        },
      ),
    );
  }
}

class _ApplicantList extends StatelessWidget {
  const _ApplicantList({
    required this.service,
    required this.ownerUid,
    required this.selectedJob,
    required this.notificationService,
  });

  final JobPostingService service;
  final String ownerUid;
  final JobPostRecord? selectedJob;
  final NotificationService notificationService;

  @override
  Widget build(BuildContext context) {
    if (selectedJob == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('확인할 채용공고를 선택해 주세요.'),
        ),
      );
    }

    return StreamBuilder<List<JobApplicationRecord>>(
      stream: service.streamApplicationsForOwner(
        ownerUid,
        jobPostId: selectedJob!.id,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final applications =
            List<JobApplicationRecord>.from(snapshot.data ?? const []);
        final pendingApplications = applications
            .where(
              (application) =>
                  application.status != JobApplicationStatus.accepted &&
                  application.status != JobApplicationStatus.rejected,
            )
            .toList();
        pendingApplications.sort(
          (a, b) => b.appliedAt.compareTo(a.appliedAt),
        );
        if (pendingApplications.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('해당 공고에 접수된 지원 내역이 없습니다.'),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '지원 내역 보기',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (selectedJob != null)
                        Flexible(
                          child: Text(
                            selectedJob!.title,
                            style: const TextStyle(color: AppColors.subtext),
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                          ),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(12),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                        child: DataTable(
                          columnSpacing: 12,
                          dataRowMaxHeight: 72,
                          headingTextStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.text,
                          ),
                          columns: const [
                            DataColumn(label: Text('지원자')),
                            DataColumn(
                              label: Center(child: Text('이력서')),
                            ),
                            DataColumn(
                              label: Center(child: Text('자기소개서')),
                            ),
                            DataColumn(label: Center(child: Text('면접'))),
                          ],
                          rows: pendingApplications
                              .map(
                                (application) => DataRow(
                                  cells: [
                                    DataCell(
                                      Text(
                                        application.applicantName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Center(
                                        child: _TableActionButton(
                                          label: '보기',
                                          onPressed:
                                              application.resumeUrl == null
                                                  ? null
                                                  : () => context.push(
                                                        '/pdf-viewer',
                                                        extra: PdfViewerArgs(
                                                          title: '이력서',
                                                          pdfUrl: application
                                                              .resumeUrl!,
                                                        ),
                                                      ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Center(
                                        child: _TableActionButton(
                                          label: '보기',
                                          onPressed:
                                              application.coverLetterUrl == null
                                                  ? null
                                                  : () => context.push(
                                                        '/pdf-viewer',
                                                        extra: PdfViewerArgs(
                                                          title: '자기소개서',
                                                          pdfUrl: application
                                                              .coverLetterUrl!,
                                                        ),
                                                      ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Center(
                                        child: _TableActionButton(
                                          label: '확인',
                                          onPressed: () => _showInterviewResult(
                                            application,
                                            context,
                                            service,
                                            notificationService,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({
    required this.post,
    required this.selected,
    required this.onTap,
    required this.service,
  });

  final JobPostRecord post;
  final bool selected;
  final VoidCallback onTap;
  final JobPostingService service;

  @override
  Widget build(BuildContext context) {
    final badgeColor = selected ? AppColors.mint : Colors.white;
    final textColor = selected ? Colors.black : AppColors.text;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 260,
        decoration: BoxDecoration(
          color: badgeColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : const Color(0xFFE5E5E5),
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 6),
            )
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              post.company,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              post.title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Row(
              children: [
                const Icon(Icons.people_outline, size: 18),
                const SizedBox(width: 6),
                StreamBuilder<int>(
                  stream: service.watchApplicationCount(post.id),
                  builder: (context, snapshot) {
                    final count = snapshot.data ?? post.applicantCount;
                    return Text('지원자 $count명');
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TableActionButton extends StatelessWidget {
  const _TableActionButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SizedBox(
        height: 36,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF6C4CFF),
            minimumSize: const Size(70, 36),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          onPressed: onPressed,
          child: Text(label),
        ),
      ),
    );
  }
}

void _showInterviewResult(
  JobApplicationRecord application,
  BuildContext context,
  JobPostingService service,
  NotificationService notificationService,
) {
  InterviewRecordingResult? storedResult;
  if (application.interviewResult != null) {
    storedResult =
        InterviewRecordingResult.fromMap(application.interviewResult);
  }

  if (storedResult != null) {
    final resultWithVideo = storedResult.copyWith(
      videoUrl: storedResult.videoUrl ?? application.interviewVideoUrl,
    );

    context.push(
      '/interview/job-evaluation',
      extra: JobInterviewEvaluationArgs.fromApplication(
        application: application,
        result: resultWithVideo,
      ),
    );
    return;
  }
  final videoUrl = application.interviewVideoUrl;
  final hasSummary = application.interviewSummary?.isNotEmpty ?? false;
  if (videoUrl == null && !hasSummary) {
    return;
  }

  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      return _InterviewResultSheet(
        application: application,
        hasSummary: hasSummary,
        videoUrl: videoUrl,
        service: service,
        notificationService: notificationService,
      );
    },
  );
}

class _InterviewResultSheet extends StatefulWidget {
  const _InterviewResultSheet({
    required this.application,
    required this.hasSummary,
    required this.videoUrl,
    required this.service,
    required this.notificationService,
  });

  final JobApplicationRecord application;
  final bool hasSummary;
  final String? videoUrl;
  final JobPostingService service;
  final NotificationService notificationService;

  @override
  State<_InterviewResultSheet> createState() => _InterviewResultSheetState();
}

class _InterviewResultSheetState extends State<_InterviewResultSheet> {
  VideoPlayerController? _controller;
  bool _isInitializing = false;
  String? _errorMessage;
  bool _isUpdating = false;

  Future<void> _sendStatusNotification(String status) async {
    final applicantUid = widget.application.applicantUid.trim();
    if (applicantUid.isEmpty) {
      return;
    }

    final label = status == JobApplicationStatus.accepted ? '1차 합격' : '불합격';
    final jobTitle = widget.application.jobTitle.isNotEmpty
        ? widget.application.jobTitle
        : '채용공고';
    final company = widget.application.jobCompany.isNotEmpty
        ? '${widget.application.jobCompany} '
        : '';

    await widget.notificationService.sendNotification(
      userId: applicantUid,
      type: 'application_status',
      title: '$company$jobTitle $label 안내',
      message:
          '지원하신 ${company.isEmpty ? '' : company}$jobTitle 공고의 1차 결과가 "$label" 처리되었습니다.',
      data: {
        'jobPostId': widget.application.jobPostId,
        'applicationId': widget.application.id,
        'status': status,
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  @override
  void didUpdateWidget(covariant _InterviewResultSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _initializeController();
    }
  }

  Future<void> _initializeController() async {
    final videoUrl = widget.videoUrl;
    if (videoUrl == null) {
      return;
    }

    setState(() {
      _isInitializing = true;
      _errorMessage = null;
    });

    final nextController =
        VideoPlayerController.networkUrl(Uri.parse(videoUrl));
    try {
      await nextController.initialize();
      nextController.setLooping(false);
      if (!mounted) {
        await nextController.dispose();
        return;
      }
      setState(() {
        _controller?.dispose();
        _controller = nextController;
        _isInitializing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '영상을 불러오지 못했습니다. 다시 시도해 주세요.';
        _isInitializing = false;
      });
      await nextController.dispose();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _updateStatus(String status) async {
    if (_isUpdating) return;
    setState(() => _isUpdating = true);

    try {
      await widget.service.updateApplicationStatus(
        widget.application.jobPostId,
        widget.application.id,
        status,
      );
      await _sendStatusNotification(status);
      if (!mounted) return;
      Navigator.of(context).pop();
      final label = status == JobApplicationStatus.accepted ? '1차 합격' : '불합격';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('상태가 "$label"(으)로 변경되었습니다.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('상태를 업데이트하지 못했습니다. 다시 시도해 주세요.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_outlined, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${widget.application.applicantName}님의 면접 결과',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (widget.hasSummary) ...[
            const Text(
              'AI 요약',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              widget.application.interviewSummary!,
              style: const TextStyle(color: AppColors.subtext),
            ),
            const SizedBox(height: 14),
          ],
          if (widget.videoUrl != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '녹화 영상',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 10),
                _isInitializing
                    ? const Center(child: CircularProgressIndicator())
                    : _errorMessage != null
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: const [
                                  Icon(Icons.error_outline,
                                      color: Colors.redAccent),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '영상을 불러오지 못했습니다. 다시 시도해 주세요.',
                                      style: TextStyle(color: Colors.redAccent),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              FilledButton.tonalIcon(
                                onPressed: _initializeController,
                                icon: const Icon(Icons.refresh),
                                label: const Text('다시 시도'),
                              ),
                            ],
                          )
                        : controller != null
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AspectRatio(
                                    aspectRatio:
                                        controller.value.aspectRatio == 0
                                            ? 16 / 9
                                            : controller.value.aspectRatio,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Stack(
                                        alignment: Alignment.bottomCenter,
                                        children: [
                                          VideoPlayer(controller),
                                          VideoProgressIndicator(
                                            controller,
                                            allowScrubbing: true,
                                            padding: const EdgeInsets.all(8),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      FilledButton.icon(
                                        onPressed: () {
                                          if (controller.value.isPlaying) {
                                            controller.pause();
                                          } else {
                                            controller.play();
                                          }
                                          setState(() {});
                                        },
                                        icon: Icon(
                                          controller.value.isPlaying
                                              ? Icons.pause_circle_outline
                                              : Icons.play_circle_outline,
                                        ),
                                        label: Text(controller.value.isPlaying
                                            ? '일시정지'
                                            : '재생'),
                                      ),
                                      const SizedBox(width: 12),
                                      OutlinedButton.icon(
                                        onPressed: () {
                                          controller.seekTo(Duration.zero);
                                          controller.play();
                                          setState(() {});
                                        },
                                        icon: const Icon(Icons.replay),
                                        label: const Text('처음부터'),
                                      ),
                                    ],
                                  ),
                                ],
                              )
                            : const SizedBox.shrink(),
              ],
            ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isUpdating
                      ? null
                      : () => _updateStatus(JobApplicationStatus.accepted),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: const Color(0xFFB486FF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '1차 합격',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _isUpdating
                      ? null
                      : () => _updateStatus(JobApplicationStatus.rejected),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Color(0xFFB486FF)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '불합격',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFB486FF),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

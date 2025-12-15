import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ai/features/common/pdf_viewer_page.dart';
import '../tabs/tabs_shared.dart';
import 'company_route_guard.dart';
import 'job_post_form_page.dart';
import 'job_posting_service.dart';

class JobPostManagementPage extends StatefulWidget {
  const JobPostManagementPage({super.key});

  @override
  State<JobPostManagementPage> createState() => _JobPostManagementPageState();
}

class _JobPostManagementPageState extends State<JobPostManagementPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final JobPostingService _service = JobPostingService();
  String? _statusFilter;
  String? _selectedJobId;
  StreamSubscription<List<JobPostRecord>>? _hiddenJobSub;
  String? _currentOwnerUid;
  bool _notifiedHidden = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _hiddenJobSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('로그인 후 이용해 주세요.')),
      );
    }
    if (_currentOwnerUid != user.uid) {
      _listenHiddenPosts(user.uid);
    }

    return CompanyRouteGuard(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('나의 공고'),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: '공고 관리'),
              Tab(text: '지원자 현황'),
            ],
          ),
          actions: [
            if (_tabController.index == 0)
              IconButton(
                onPressed: () async {
                  final created = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => const JobPostFormPage(),
                    ),
                  );
                  if (created == true && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('새 공고가 추가되었습니다.')),
                    );
                  }
                },
                icon: const Icon(Icons.add),
                tooltip: '공고 등록',
              ),
          ],
        ),
        backgroundColor: AppColors.bg,
        body: TabBarView(
          controller: _tabController,
          children: [
            _CompanyJobsTab(service: _service, ownerUid: user.uid),
            _ApplicationsTab(
              service: _service,
              ownerUid: user.uid,
              statusFilter: _statusFilter,
              onStatusChanged: (value) => setState(() => _statusFilter = value),
              selectedJobId: _selectedJobId,
              onJobChanged: (value) => setState(() => _selectedJobId = value),
            ),
          ],
        ),
      ),
    );
  }

  void _listenHiddenPosts(String ownerUid) {
    _currentOwnerUid = ownerUid;
    _hiddenJobSub?.cancel();
    _notifiedHidden = false;
    _hiddenJobSub = _service.streamOwnerPosts(ownerUid).listen((posts) {
      final hidden = posts.where((p) => !p.visible).toList(growable: false);
      if (hidden.isEmpty || _notifiedHidden || !mounted) {
        return;
      }
      _notifiedHidden = true;
      final reason = hidden.first.blockedReason.trim().isEmpty
          ? '공고가 운영 정책 위반으로 숨겨졌습니다.'
          : hidden.first.blockedReason;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(reason)),
      );
    });
  }
}

class _CompanyJobsTab extends StatelessWidget {
  const _CompanyJobsTab({
    required this.service,
    required this.ownerUid,
  });

  final JobPostingService service;
  final String ownerUid;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return SafeArea(
      top: false,
      bottom: true,
      child: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<JobPostRecord>>(
              stream: service.streamOwnerPosts(ownerUid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final posts = snapshot.data ?? const <JobPostRecord>[];
                if (posts.isEmpty) {
                  return const _EmptyState(
                    message: '등록된 채용 공고가 없습니다. 첫 공고를 등록해 보세요!',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    return _JobPostCard(post: post, service: service);
                  },
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemCount: posts.length,
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final created = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => const JobPostFormPage(),
                    ),
                  );
                  if (created == true && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('새 공고가 추가되었습니다.')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB486FF),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  '신규 공고 등록',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _JobPostCard extends StatelessWidget {
  const _JobPostCard({required this.post, required this.service});

  final JobPostRecord post;
  final JobPostingService service;

  @override
  Widget build(BuildContext context) {
    final subtitle = '${post.experienceLevel} · ${post.employmentType} · '
        '${post.region}';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.company,
                      style: const TextStyle(
                        color: AppColors.subtext,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      post.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(color: AppColors.subtext),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '소프트웨어개발, 솔루션, 서버관리',
                      style: TextStyle(
                        color: AppColors.subtext.withOpacity(0.9),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () async {
                      final updated = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => JobPostFormPage(existing: post),
                        ),
                      );
                      if (updated == true && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('공고를 업데이트했습니다.')),
                        );
                      }
                    },
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: '수정',
                  ),
                  IconButton(
                    onPressed: () => _confirmDelete(context),
                    icon: const Icon(Icons.delete_outline),
                    tooltip: '삭제',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(
                icon: Icons.schedule,
                label: '시작 ${_formatDate(post.applicationStartDate)}',
              ),
              _InfoChip(
                icon: Icons.event_available_outlined,
                label: '마감 ${_formatDate(post.applicationEndDate)}',
              ),
              StreamBuilder<int>(
                stream: service.watchApplicationCount(post.id),
                builder: (context, snapshot) {
                  final count = snapshot.data ?? 0;
                  return _InfoChip(
                    icon: Icons.people_outline,
                    label: '지원자 $count명',
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('공고를 삭제할까요?'),
          content: Text('"${post.title}" 공고와 관련된 데이터가 삭제됩니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true || !context.mounted) return;

    try {
      await service.delete(post.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('공고를 삭제했습니다.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('공고 삭제에 실패했습니다. 잠시 후 다시 시도해 주세요.')),
      );
    }
  }
}

class _ApplicationsTab extends StatelessWidget {
  const _ApplicationsTab({
    required this.service,
    required this.ownerUid,
    required this.statusFilter,
    required this.onStatusChanged,
    required this.selectedJobId,
    required this.onJobChanged,
  });

  final JobPostingService service;
  final String ownerUid;
  final String? statusFilter;
  final ValueChanged<String?> onStatusChanged;
  final String? selectedJobId;
  final ValueChanged<String?> onJobChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ApplicationsFilter(
          service: service,
          ownerUid: ownerUid,
          statusFilter: statusFilter,
          onStatusChanged: onStatusChanged,
          selectedJobId: selectedJobId,
          onJobChanged: onJobChanged,
        ),
        Expanded(
          child: StreamBuilder<List<JobApplicationRecord>>(
            stream: service.streamApplicationsForOwner(
              ownerUid,
              status: statusFilter,
              jobPostId: selectedJobId,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final applications =
                  snapshot.data ?? const <JobApplicationRecord>[];
              if (applications.isEmpty) {
                return const _EmptyState(
                  message: '아직 접수된 지원자가 없습니다.',
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return const _ApplicationsHeader();
                  }
                  final application = applications[index - 1];
                  return _ApplicationTile(
                    application: application,
                    service: service,
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemCount: applications.length + 1,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ApplicationsFilter extends StatelessWidget {
  const _ApplicationsFilter({
    required this.service,
    required this.ownerUid,
    required this.statusFilter,
    required this.onStatusChanged,
    required this.selectedJobId,
    required this.onJobChanged,
  });

  final JobPostingService service;
  final String ownerUid;
  final String? statusFilter;
  final ValueChanged<String?> onStatusChanged;
  final String? selectedJobId;
  final ValueChanged<String?> onJobChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(color: Colors.white, boxShadow: [
        BoxShadow(
          color: Color(0x11000000),
          blurRadius: 8,
          offset: Offset(0, 4),
        )
      ]),
      child: StreamBuilder<List<JobPostRecord>>(
        stream: service.streamOwnerPosts(ownerUid),
        builder: (context, snapshot) {
          final posts = snapshot.data ?? const <JobPostRecord>[];
          final jobOptions = <DropdownMenuItem<String?>>[
            const DropdownMenuItem(value: null, child: Text('전체 공고')),
            ...posts.map(
              (post) => DropdownMenuItem(
                value: post.id,
                child: Text(post.title, overflow: TextOverflow.ellipsis),
              ),
            ),
          ];

          final statusOptions = <DropdownMenuItem<String?>>[
            const DropdownMenuItem(value: null, child: Text('전체 상태')),
            ...JobApplicationStatus.labels.entries.map(
              (entry) => DropdownMenuItem(
                value: entry.key,
                child: Text(entry.value),
              ),
            ),
          ];

          return Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: selectedJobId,
                  decoration: const InputDecoration(
                    labelText: '공고 선택',
                    filled: true,
                    fillColor: Color(0xFFF7F7FB),
                    border: OutlineInputBorder(borderSide: BorderSide.none),
                  ),
                  items: jobOptions,
                  onChanged: onJobChanged,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: statusFilter,
                  decoration: const InputDecoration(
                    labelText: '상태',
                    filled: true,
                    fillColor: Color(0xFFF7F7FB),
                    border: OutlineInputBorder(borderSide: BorderSide.none),
                  ),
                  items: statusOptions,
                  onChanged: onStatusChanged,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ApplicationsHeader extends StatelessWidget {
  const _ApplicationsHeader();

  @override
  Widget build(BuildContext context) {
    const headers = ['지원자', '지원일자', '이력서', '자기소개서', '면접', '최종'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3ECFF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: headers.map((label) {
          return SizedBox(
            width: 70, // 👈 고정 넓이로 세로 깨짐 방지
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF7B3EFF),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ApplicationTile extends StatelessWidget {
  const _ApplicationTile({required this.application, required this.service});

  final JobApplicationRecord application;
  final JobPostingService service;

  @override
  Widget build(BuildContext context) {
    final statusLabel =
        JobApplicationStatus.labels[application.status] ?? application.status;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showApplicationDetail(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE8E8E8)),
          ),
          child: Row(
            children: [
              _TableCell(
                child: Text(
                  application.applicantName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              _TableCell(
                child: Text(
                  _formatMonthDay(application.appliedAt),
                  style: const TextStyle(color: AppColors.subtext),
                ),
              ),
              _TableCell(
                child: _ActionPill(
                  label: '확인',
                  onTap: application.resumeUrl != null
                      ? () => _launchResume(
                            application.resumeUrl!,
                            context,
                            fileName: application.resumeFileName ?? '이력서 파일',
                          )
                      : null,
                ),
              ),
              _TableCell(
                child: _ActionPill(
                  label: '확인',
                  onTap: application.coverLetterUrl != null
                      ? () => _launchResume(
                            application.coverLetterUrl!,
                            context,
                            fileName:
                                application.coverLetterFileName ?? '자기소개서 파일',
                          )
                      : null,
                ),
              ),
              _TableCell(
                child: _ActionPill(
                  label: '확인',
                  onTap: () => _showApplicationDetail(context),
                ),
              ),
              _TableCell(
                child: _StatusPill(label: statusLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchResume(
    String url,
    BuildContext context, {
    required String fileName,
  }) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('파일 링크가 없습니다.')),
      );
      return;
    }
    context.push(
      '/pdf-viewer',
      extra: PdfViewerArgs(title: fileName, pdfUrl: trimmed),
    );
  }

  void _showApplicationDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                application.applicantName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '지원일 ${_formatDate(application.appliedAt)}',
                style: const TextStyle(color: AppColors.subtext),
              ),
              const SizedBox(height: 16),
              const Text(
                '면접 영상 및 AI 분석 결과를 확인하고 최종 평가를 결정해주세요.',
                style: TextStyle(height: 1.4),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _updateStatus(
                        context,
                        JobApplicationStatus.accepted,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFB486FF),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        '합격',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _updateStatus(
                        context,
                        JobApplicationStatus.rejected,
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFB486FF)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
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
      },
    );
  }

  Future<void> _updateStatus(BuildContext context, String status) async {
    await service.updateApplicationStatus(
      application.jobPostId,
      application.id,
      status,
    );
    if (context.mounted) {
      Navigator.of(context).pop();
      final label = JobApplicationStatus.labels[status] ?? status;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('상태가 "$label"(으)로 변경되었습니다.')),
      );
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inbox_outlined,
                size: 48, color: AppColors.subtext),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  const _TableCell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(child: child),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFFB486FF) : const Color(0xFFE0D6F5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: enabled ? Colors.white : const Color(0xFF8C8C8C),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFDCD0FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF5B3AB2),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18, color: AppColors.subtext),
      label: Text(label),
      backgroundColor: const Color(0xFFF3F5F9),
    );
  }
}

String _formatMonthDay(DateTime date) {
  return '${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
}

String _formatDate(DateTime date) {
  return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
}

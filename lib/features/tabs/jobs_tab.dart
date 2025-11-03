import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../jobs/job_detail_page.dart';
import '../jobs/job_posting.dart';
import '../jobs/job_posting_loader.dart';
import 'tabs_shared.dart';

class JobsTab extends StatefulWidget {
  const JobsTab({super.key});
  @override
  State<JobsTab> createState() => _JobsTabState();
}

class _JobsTabState extends State<JobsTab> {
  late Future<JobFeed> _future;
  final JobPostingLoader _loader = const JobPostingLoader();

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  Future<JobFeed> _fetch() => _loader.load();

  Future<void> _handleRefresh() {
    final future = _fetch();
    setState(() {
      _future = future;
    });
    return future.then((_) {});
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: FutureBuilder<JobFeed>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _LoadingView();
          }

          if (snapshot.hasError) {
            return _ErrorView(
              error: snapshot.error,
              onRetry: () {
                setState(() {
                  _future = _fetch();
                });
              },
            );
          }

          final feed = snapshot.data;
          if (feed == null || feed.items.isEmpty) {
            return const _EmptyView();
          }

          return _JobsList(feed: feed);
        },
      ),
    );
  }
}

class _JobsList extends StatefulWidget {
  const _JobsList({required this.feed});

  final JobFeed feed;
  @override
  State<_JobsList> createState() => _JobsListState();
}

class _JobsListState extends State<_JobsList> {
  static const _pageSize = 20;
  int _currentPage = 1;

  @override
  void didUpdateWidget(covariant _JobsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.feed.items, oldWidget.feed.items) ||
        widget.feed.totalCount != oldWidget.feed.totalCount) {
      final totalPages = _totalPages;
      if (_currentPage > totalPages) {
        setState(() {
          _currentPage = totalPages;
        });
      }
    }
  }

  int get _totalPages {
    final count = widget.feed.items.length;
    if (count == 0) {
      return 1;
    }
    return ((count - 1) / _pageSize).floor() + 1;
  }

  List<JobPosting> get _visibleJobs {
    final startIndex = (_currentPage - 1) * _pageSize;
    return widget.feed.items
        .skip(startIndex)
        .take(_pageSize)
        .toList(growable: false);
  }

  void _onPageSelected(int page) {
    if (page == _currentPage) {
      return;
    }

    final totalPages = _totalPages;
    var nextPage = page;
    if (nextPage < 1) {
      nextPage = 1;
    } else if (nextPage > totalPages) {
      nextPage = totalPages;
    }

    setState(() {
      _currentPage = nextPage;
    });
  }

  @override
  Widget build(BuildContext context) {
    final jobs = _visibleJobs;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 48),
      children: [
        _Header(totalCount: widget.feed.totalCount),
        const SizedBox(height: 24),
        const _FilterRow(),
        const SizedBox(height: 24),
        _JobsGrid(jobs: jobs),
        const SizedBox(height: 32),
        _PaginationControls(
          currentPage: _currentPage,
          totalPages: _totalPages,
          onPageSelected: _onPageSelected,
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.totalCount});

  final int totalCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            CircleAvatar(
              radius: 18,
              backgroundImage: AssetImage('assets/logo.png'),
              backgroundColor: Colors.transparent,
            ),
            SizedBox(width: 8),
            Text(
              'Ai',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(width: 4),
            Text(
              '채용공고',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          '채용정보 총 $totalCount건',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '데이터 출처: 공공데이터포털(기획재정부 공공기관 채용정보 조회서비스)',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.subtext,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black, width: 1.1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 520;

            Widget buildWideLayout() {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Expanded(child: _FilterChip(label: '직업 선택')),
                  SizedBox(width: 12),
                  Expanded(child: _FilterChip(label: '지역 선택')),
                  SizedBox(width: 12),
                  Expanded(flex: 2, child: _SearchField()),
                ],
              );
            }

            Widget buildCompactLayout() {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: const [
                  _FilterChip(label: '직업 선택'),
                  SizedBox(height: 12),
                  _FilterChip(label: '지역 선택'),
                  SizedBox(height: 12),
                  _SearchField(),
                ],
              );
            }

            return isCompact ? buildCompactLayout() : buildWideLayout();
          },
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: () {},
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.black, width: 1.0),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          foregroundColor: AppColors.text,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
          alignment: Alignment.centerLeft,
          backgroundColor: Colors.white,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.expand_more, size: 18, color: AppColors.subtext),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black, width: 1.0),
        ),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(Icons.search, size: 18, color: AppColors.subtext),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  '검색어 입력',
                  style: TextStyle(color: AppColors.subtext),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JobsGrid extends StatelessWidget {
  const _JobsGrid({required this.jobs});

  final List<JobPosting> jobs;

  static const _palette = <Color>[
    Color(0xFF6C63FF),
    Color(0xFF4F86FF),
    Color(0xFF2CB1A3),
    Color(0xFFFF7043),
    Color(0xFF8E24AA),
    Color(0xFF43A047),
  ];

  @override
  Widget build(BuildContext context) {
    if (jobs.isEmpty) {
      return SizedBox(
        height: 160,
        child: Center(
          child: Text(
            '해당 페이지에 표시할 공고가 없습니다.',
            style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.subtext) ??
                const TextStyle(color: AppColors.subtext),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const spacing = 16.0;
        final crossAxisCount = width >= 900
            ? 3
            : width >= 640
                ? 2
                : 1;
        final itemWidth = crossAxisCount == 1
            ? width
            : (width - spacing * (crossAxisCount - 1)) / crossAxisCount;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (var i = 0; i < jobs.length; i++)
              SizedBox(
                width: crossAxisCount == 1 ? width : itemWidth,
                child: _JobCard(
                  job: jobs[i],
                  color: _palette[i % _palette.length],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({required this.job, required this.color});

  final JobPosting job;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final meta = _buildMeta(job);
    final secondaryStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.subtext,
            ) ??
        const TextStyle(color: AppColors.subtext);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => JobDetailPage(job: job)),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.companyLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      job.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      meta,
                      style: secondaryStyle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.chevron_right, color: AppColors.subtext),
            ],
          ),
        ),
      ),
    );
  }

  String _buildMeta(JobPosting job) {
    final parts = <String>[];
    final region = job.regionLabel.trim();
    if (region.isNotEmpty) {
      parts.add(region);
    }
    if (job.tags.isNotEmpty) {
      parts.add(job.tags.first);
    } else {
      final date = job.prettyPostedDate;
      if (date != null && date.isNotEmpty) {
        parts.add(date);
      }
    }
    if (parts.isEmpty) {
      return '상세 정보 확인';
    }
    return parts.join(' · ');
  }
}

class _PaginationControls extends StatelessWidget {
  const _PaginationControls({
    required this.currentPage,
    required this.totalPages,
    required this.onPageSelected,
  });

  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageSelected;

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 1) {
      return const SizedBox.shrink();
    }

    final pages = _visiblePages();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ArrowButton(
          icon: Icons.chevron_left,
          onPressed:
              currentPage > 1 ? () => onPageSelected(currentPage - 1) : null,
        ),
        const SizedBox(width: 12),
        for (final page in pages)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _PageButton(
              page: page,
              isActive: page == currentPage,
              onTap: () => onPageSelected(page),
            ),
          ),
        const SizedBox(width: 12),
        _ArrowButton(
          icon: Icons.chevron_right,
          onPressed: currentPage < totalPages
              ? () => onPageSelected(currentPage + 1)
              : null,
        ),
      ],
    );
  }

  List<int> _visiblePages() {
    const window = 5;
    if (totalPages <= window) {
      return [for (var i = 1; i <= totalPages; i++) i];
    }
    final block = ((currentPage - 1) / window).floor();
    final start = block * window + 1;
    final end = math.min(start + window - 1, totalPages);
    return [for (var i = start; i <= end; i++) i];
  }
}

class _PageButton extends StatelessWidget {
  const _PageButton({
    required this.page,
    required this.isActive,
    required this.onTap,
  });

  final int page;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = isActive ? AppColors.mint : Colors.white;
    final foreground = isActive ? Colors.black : AppColors.subtext;
    final borderColor = isActive ? AppColors.mint : const Color(0xFFE1E1E5);

    return SizedBox(
      width: 44,
      height: 40,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          side: BorderSide(color: borderColor),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ) ??
              const TextStyle(fontWeight: FontWeight.w700),
        ),
        child: Text('$page'),
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({required this.icon, this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final background = enabled ? Colors.white : const Color(0xFFE9E9EC);
    final iconColor = enabled ? AppColors.text : AppColors.subtext;

    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(20),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: iconColor),
          ),
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.only(top: 120),
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 160),
      children: const [
        Icon(Icons.work_outline, size: 48, color: AppColors.subtext),
        SizedBox(height: 12),
        const Center(
          child: Text(
            '조회된 채용공고가 없습니다.',
            style: TextStyle(color: AppColors.subtext),
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 160),
      children: [
        const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
        const SizedBox(height: 12),
        Center(
          child: Text(
            '채용공고를 불러오지 못했습니다.\n${error ?? ''}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.subtext),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('다시 시도'),
          ),
        ),
      ],
    );
  }
}

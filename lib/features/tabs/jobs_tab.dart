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

class _JobsList extends StatelessWidget {
  const _JobsList({required this.feed});

  final JobFeed feed;

  @override
  Widget build(BuildContext context) {
    final highlightJobs = feed.items.take(12).toList(growable: false);
    final tableJobs = feed.items.take(6).toList(growable: false);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      children: [
        _Header(totalCount: feed.totalCount),
        const SizedBox(height: 24),
        const _FilterRow(),
        const SizedBox(height: 24),
        _JobsTable(jobs: tableJobs),
        const SizedBox(height: 32),
        const Text(
          '이 공고, 놓치지 마세요!',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'AI가 엄선한 인기 채용 공고를 지금 확인해 보세요.',
          style: TextStyle(
            color: AppColors.subtext,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 24),
        _HighlightsGrid(jobs: highlightJobs),
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

class _JobsTable extends StatelessWidget {
  const _JobsTable({required this.jobs});

  final List<JobPosting> jobs;

  @override
  Widget build(BuildContext context) {
    if (jobs.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final headingStyle = theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.subtext,
        ) ??
        const TextStyle(fontWeight: FontWeight.w700, color: AppColors.subtext);

    final dataStyle = theme.textTheme.bodyMedium?.copyWith(height: 1.3) ??
        const TextStyle(height: 1.3);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 24,
            horizontalMargin: 20,
            headingRowHeight: 44,
            dataRowMinHeight: 56,
            dataRowMaxHeight: 64,
            headingTextStyle: headingStyle,
            dataTextStyle: dataStyle,
            columns: const [
              DataColumn(label: Text('기업')),
              DataColumn(label: Text('채용 공고')),
              DataColumn(label: Text('지역')),
              DataColumn(label: Text('마감일')),
            ],
            rows: jobs
                .map(
                  (job) => DataRow(
                    onSelectChanged: (_) => _openDetail(context, job),
                    cells: [
                      DataCell(Text(job.companyLabel,
                          overflow: TextOverflow.ellipsis)),
                      DataCell(
                          Text(job.title, overflow: TextOverflow.ellipsis)),
                      DataCell(Text(job.regionLabel,
                          overflow: TextOverflow.ellipsis)),
                      DataCell(
                        Text(
                          job.prettyPostedDate ?? '상시',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                )
                .toList(growable: false),
          ),
        ),
      ),
    );
  }

  void _openDetail(BuildContext context, JobPosting job) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => JobDetailPage(job: job)),
    );
  }
}

class _HighlightsGrid extends StatelessWidget {
  const _HighlightsGrid({required this.jobs});

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
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const spacing = 16.0;
        final crossAxisCount = width >= 920
            ? 3
            : width >= 600
                ? 2
                : 1;
        final cardWidth = crossAxisCount == 1
            ? width
            : (width - spacing * (crossAxisCount - 1)) / crossAxisCount;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: List.generate(jobs.length, (index) {
            final job = jobs[index];
            final color = _palette[index % _palette.length];
            return SizedBox(
              width: crossAxisCount == 1 ? width : cardWidth,
              child: _HighlightCard(job: job, color: color),
            );
          }),
        );
      },
    );
  }
}

class _HighlightCard extends StatelessWidget {
  const _HighlightCard({required this.job, required this.color});

  final JobPosting job;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tagSummary = job.tags.take(2).join(' · ');
    final meta = _buildMeta(job);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => JobDetailPage(job: job)),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.35),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                job.companyLabel,
                style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withOpacity(0.85),
                      fontWeight: FontWeight.w700,
                    ) ??
                    const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                job.title,
                style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                    ) ??
                    const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                    ),
              ),
              const SizedBox(height: 16),
              if (tagSummary.isNotEmpty) ...[
                Text(
                  tagSummary,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Expanded(
                    child: Text(
                      meta,
                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right, color: Colors.white),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _buildMeta(JobPosting job) {
    final date = job.prettyPostedDate;
    if (date != null && date.isNotEmpty) {
      return '${job.regionLabel} · $date';
    }
    if (job.tags.isNotEmpty) {
      return '${job.regionLabel} · ${job.tags.first}';
    }
    return job.regionLabel;
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

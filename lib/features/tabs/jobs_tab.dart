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
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        _Header(totalCount: feed.totalCount),
        const SizedBox(height: 24),
        const _FilterRow(),
        const SizedBox(height: 24),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: feed.items.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.88,
          ),
          itemBuilder: (context, index) {
            final job = feed.items[index];
            return _JobCard(job: job);
          },
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
          '검색 결과 총 $totalCount건',
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
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
          side: const BorderSide(color: Colors.black, width: 1.2),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          foregroundColor: AppColors.text,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
          alignment: Alignment.centerLeft,
          backgroundColor: Colors.transparent,
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
          ),
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
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black, width: 1.2),
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

class _JobCard extends StatelessWidget {
  const _JobCard({required this.job});

  final JobPosting job;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => JobDetailPage(job: job)),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black, width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                job.companyLabel,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                job.title,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                ),
              ),
              const Spacer(),
              Text(
                _buildSummary(job),
                style: const TextStyle(
                  color: AppColors.subtext,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _buildSummary(JobPosting job) {
    final location = job.regionLabel;
    final date = job.prettyPostedDate;
    if (date != null) {
      return '$location · $date';
    }
    return location;
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

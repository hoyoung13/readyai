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

  static const _cardColors = [
    Color(0xFFEF5350),
    Color(0xFF7E57C2),
    Color(0xFF26A69A),
    Color(0xFF42A5F5),
    Color(0xFFFFCA28),
    Color(0xFFAB47BC),
  ];

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
        ...feed.items.mapIndexed(
          (index, job) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _JobCard(
              job: job,
              color: _cardColors[index % _cardColors.length],
            ),
          ),
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
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
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
            children: const [
              Text(
                '이 공고, 놓치지 마세요!',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'JobKorea에서 수집한 최신 채용공고를 한눈에 확인해 보세요.',
                style: TextStyle(
                  color: AppColors.subtext,
                  height: 1.3,
                ),
              ),
            ],
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
    return Container(
      padding: const EdgeInsets.all(12),
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
        children: [
          Row(
            children: const [
              _FilterChip(label: '직업 선택'),
              SizedBox(width: 8),
              _FilterChip(label: '지역 선택'),
              SizedBox(width: 8),
              Expanded(child: _SearchField()),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: const [
              Icon(Icons.info_outline, size: 16, color: AppColors.subtext),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  '필터는 곧 제공될 예정입니다. 지금은 최신 공고를 확인해 보세요.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.subtext,
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

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F2F6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: const [
          Icon(Icons.search, size: 18, color: AppColors.subtext),
          SizedBox(width: 6),
          Text('검색어 입력', style: TextStyle(color: AppColors.subtext)),
        ],
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({required this.job, required this.color});

  final JobPosting job;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => JobDetailPage(job: job)),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.22),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                job.companyLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              job.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _buildSummary(job),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ],
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

extension _IterableMapIndexed<E> on Iterable<E> {
  Iterable<T> mapIndexed<T>(T Function(int index, E element) convert) sync* {
    var index = 0;
    for (final element in this) {
      yield convert(index, element);
      index++;
    }
  }
}

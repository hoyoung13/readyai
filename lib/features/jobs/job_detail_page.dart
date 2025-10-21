import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../tabs/tabs_shared.dart';
import 'job_posting.dart';

class JobDetailPage extends StatelessWidget {
  const JobDetailPage({required this.job, super.key});

  final JobPosting job;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('채용 공고 상세'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
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
                        job.companyLabel,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.subtext,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        job.title,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(
                            Icons.place_outlined,
                            size: 18,
                            color: AppColors.subtext,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              job.regionLabel,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.subtext,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: () => _launchDetail(job.url, context),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    backgroundColor: const Color(0xFF4C6EF5),
                  ),
                  child: const Text('입사지원'),
                ),
              ],
            ),
            const SizedBox(height: 28),
            _SummaryWrap(job: job),
            const SizedBox(height: 32),
            _DetailSection(
              title: '모집정보',
              innerPadding: EdgeInsets.zero,
              child: _DetailTable(rows: job.detailRows),
            ),
            if (job.description.trim().isNotEmpty) ...[
              const SizedBox(height: 24),
              _DetailSection(
                title: '이 포지션은 이런 일을 해요',
                child: Text(
                  job.description,
                  style: const TextStyle(height: 1.5),
                ),
              ),
            ],
            if (job.notice.trim().isNotEmpty) ...[
              const SizedBox(height: 24),
              _DetailSection(
                title: '지원 안내',
                child: Text(
                  job.notice,
                  style: const TextStyle(height: 1.5),
                ),
              ),
            ],
            if (job.hasUrl) ...[
              const SizedBox(height: 28),
              Center(
                child: OutlinedButton.icon(
                  onPressed: () => _launchDetail(job.url, context),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('상세 공고 페이지 열기'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _launchDetail(String url, BuildContext context) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('상세 링크가 제공되지 않았습니다.')),
      );
      return;
    }

    final launched =
        await launchUrlString(trimmed, mode: LaunchMode.externalApplication);
    if (!launched) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('상세 페이지를 열 수 없습니다.')),
      );
    }
  }
}

class _SummaryWrap extends StatelessWidget {
  const _SummaryWrap({required this.job});

  final JobPosting job;

  @override
  Widget build(BuildContext context) {
    final items = job.summaryItems.isNotEmpty
        ? job.summaryItems
        : [
            JobSummaryItem(label: '근무지', value: job.regionLabel),
            if (job.prettyPostedDate != null)
              JobSummaryItem(label: '등록일', value: job.prettyPostedDate!),
          ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children:
          items.map((item) => _SummaryTile(item: item)).toList(growable: false),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.item});

  final JobSummaryItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.subtext,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.title,
    required this.child,
    this.innerPadding,
  });

  final String title;
  final Widget child;
  final EdgeInsetsGeometry? innerPadding;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: innerPadding ?? const EdgeInsets.all(20),
              child: child,
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailTable extends StatelessWidget {
  const _DetailTable({required this.rows});

  final List<JobDetailRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Text(
          '세부 모집정보가 곧 업데이트될 예정입니다.',
          style: TextStyle(color: AppColors.subtext),
        ),
      );
    }

    const headerColor = Color(0xFFFF6B6B);
    const headerTextStyle = TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w700,
    );
    const titleStyle = TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 14,
    );
    const descriptionStyle = TextStyle(
      fontSize: 14,
      height: 1.5,
    );

    return Column(
      children: [
        Container(
          color: headerColor,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: const [
              Expanded(child: Text('구분', style: headerTextStyle)),
              SizedBox(width: 12),
              Expanded(flex: 2, child: Text('상세 내용', style: headerTextStyle)),
            ],
          ),
        ),
        for (var i = 0; i < rows.length; i++)
          Container(
            color: i.isEven ? Colors.white : const Color(0xFFFFF4F2),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    rows[i].title,
                    style: titleStyle,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: Text(
                    rows[i].description,
                    style: descriptionStyle,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

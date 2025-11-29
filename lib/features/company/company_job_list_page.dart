import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ai/features/tabs/tabs_shared.dart';

class CompanyJobListPage extends StatelessWidget {
  const CompanyJobListPage({super.key});

  static const _jobs = [
    {
      'company': '(주)부천컴퍼니',
      'title': '백엔드 개발자 채용',
      'summary': '3년 이상 / 대졸 / 서울 / 정규직',
    },
    {
      'company': '레디AI',
      'title': 'AI 리서처',
      'summary': '신입 · 경력 / 석사 / 판교 / 정규직',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('나의 공고'),
        centerTitle: false,
      ),
      backgroundColor: AppColors.bg,
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemBuilder: (context, index) {
          final job = _jobs[index];
          return _JobCard(
            company: job['company']!,
            title: job['title']!,
            summary: job['summary']!,
            onViewApplicants: () => context.go('/company/applicants'),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemCount: _jobs.length,
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: FilledButton(
            onPressed: () => context.push('/company/post-job'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('신규 공고 등록'),
          ),
        ),
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({
    required this.company,
    required this.title,
    required this.summary,
    required this.onViewApplicants,
  });

  final String company;
  final String title;
  final String summary;
  final VoidCallback onViewApplicants;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$company / $title',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  summary,
                  style: const TextStyle(color: AppColors.subtext),
                ),
              ),
              TextButton(
                onPressed: onViewApplicants,
                child: const Text('지원현황 보기'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

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
        title: const Text('채용공고 상세'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              job.organizationName,
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
                fontSize: 24,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Text(
                    _statusLabel(job.status),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => _launchApply(job.url, context),
                  child: const Text('입사지원'),
                ),
              ],
            ),
            const SizedBox(height: 28),
            _InfoBlock(
              title: '모집기간',
              children: [
                _InfoRow(label: '등록일', value: _formatDate(job.regDate)),
                _InfoRow(label: '수정일', value: _formatDate(job.modDate)),
                _InfoRow(
                    label: '마감일',
                    value: _formatDate(job.endDate, placeholder: '채용시까지')),
              ],
            ),
            const SizedBox(height: 20),
            _InfoBlock(
              title: '채용기관 정보',
              children: [
                _InfoRow(label: '기관명', value: job.organizationName),
                _InfoRow(label: '공고 번호', value: '#${job.id}'),
              ],
            ),
            const SizedBox(height: 20),
            _InfoBlock(
              title: '지원 안내',
              children: const [
                Text('공고 상세 페이지에서 지원 절차를 확인하고 제출해 주세요.'),
                SizedBox(height: 8),
                Text('입사지원 버튼을 눌러 한국저작권위원회 채용 게시판으로 이동합니다.'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _launchApply(String url, BuildContext context) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('지원 링크가 제공되지 않았습니다.')),
      );
      return;
    }

    final launched =
        await launchUrlString(trimmed, mode: LaunchMode.externalApplication);
    if (!launched) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('지원 페이지를 열 수 없습니다.')),
      );
    }
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.title, required this.children});

  final String title;
  final List<Widget> children;

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
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.subtext,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime? value, {String placeholder = '정보 없음'}) {
  if (value == null) {
    return placeholder;
  }
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}.$month.$day';
}

String _statusLabel(String status) {
  switch (status.toUpperCase()) {
    case 'Y':
      return '모집중';
    case 'N':
      return '마감';
    default:
      return status.isEmpty ? '상태 미확인' : status;
  }
}

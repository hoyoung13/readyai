import 'package:flutter/material.dart';
import 'package:ai/features/tabs/tabs_shared.dart';

class CompanyApplicantOverviewPage extends StatelessWidget {
  const CompanyApplicantOverviewPage({super.key});

  static final _applicants = [
    {
      'name': '김가임',
      'appliedAt': '2024-06-01',
      'resumeScore': 87,
      'coverLetterScore': 82,
      'interviewScore': 90,
      'finalResult': '대기',
    },
    {
      'name': '박지원',
      'appliedAt': '2024-06-03',
      'resumeScore': 78,
      'coverLetterScore': 75,
      'interviewScore': 81,
      'finalResult': '대기',
    },
  ];

  void _openInterview(BuildContext context, Map<String, Object?> applicant) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('AI 면접 분석 이동'),
          content: Text(
            '${applicant['name']}님의 AI 면접 영상과 분석 페이지로 이동합니다.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  void _openFinalSummary(BuildContext context, Map<String, Object?> applicant) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${applicant['name']} - AI 평가 요약',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              _scoreRow('이력서', applicant['resumeScore'] as int),
              _scoreRow('자기소개서', applicant['coverLetterScore'] as int),
              _scoreRow('면접', applicant['interviewScore'] as int),
              const SizedBox(height: 16),
              const Text(
                'AI가 평가한 내용을 기반으로 최종 결과를 선택하세요.',
                style: TextStyle(color: AppColors.subtext),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.mint,
                        foregroundColor: Colors.black,
                      ),
                      child: const Text('합격'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('불합격'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('지원 내역 보기'),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              children: const [
                Text(
                  '(주)부천컴퍼니',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 4),
                Text(
                  '백엔드 개발자 채용',
                  style: TextStyle(color: AppColors.subtext),
                ),
              ],
            ),
          ),
        ),
      ),
      backgroundColor: AppColors.bg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(14)),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: _ApplicantHeaderRow(),
                ),
              ),
              for (final applicant in _applicants)
                _ApplicantRow(
                  applicant: applicant,
                  onInterview: () => _openInterview(context, applicant),
                  onFinal: () => _openFinalSummary(context, applicant),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _scoreRow(String label, int value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        Text('$value점', style: const TextStyle(color: AppColors.text)),
      ],
    ),
  );
}

class _ApplicantHeaderRow extends StatelessWidget {
  const _ApplicantHeaderRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(flex: 2, child: Text('지원자', textAlign: TextAlign.center)),
        Expanded(flex: 2, child: Text('지원일자', textAlign: TextAlign.center)),
        Expanded(child: Text('이력서', textAlign: TextAlign.center)),
        Expanded(child: Text('자기소개서', textAlign: TextAlign.center)),
        Expanded(child: Text('면접', textAlign: TextAlign.center)),
        Expanded(child: Text('최종', textAlign: TextAlign.center)),
      ],
    );
  }
}

class _ApplicantRow extends StatelessWidget {
  const _ApplicantRow({
    required this.applicant,
    required this.onInterview,
    required this.onFinal,
  });

  final Map<String, Object?> applicant;
  final VoidCallback onInterview;
  final VoidCallback onFinal;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              applicant['name'] as String,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              applicant['appliedAt'] as String,
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(child: _RoundedActionButton(label: '확인', onTap: () {})),
          Expanded(child: _RoundedActionButton(label: '확인', onTap: () {})),
          Expanded(
            child: _RoundedActionButton(
              label: '확인',
              onTap: onInterview,
            ),
          ),
          Expanded(
            child: _RoundedActionButton(
              label: '확인',
              onTap: onFinal,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundedActionButton extends StatelessWidget {
  const _RoundedActionButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Text(label),
      ),
    );
  }
}

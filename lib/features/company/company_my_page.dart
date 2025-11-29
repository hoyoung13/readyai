import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ai/features/tabs/tabs_shared.dart';

class CompanyMyPage extends StatelessWidget {
  const CompanyMyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('나의 공고관리')),
      backgroundColor: AppColors.bg,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '관리 메뉴',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.work_outline),
              title: const Text('공고 관리'),
              subtitle: const Text('등록된 공고를 수정하거나 마감합니다.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/company/jobs'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.assignment_ind_outlined),
              title: const Text('지원자 관리'),
              subtitle: const Text('지원 현황과 AI 분석을 확인하세요.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/company/applicants'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('계정 설정'),
              subtitle: const Text('회사 정보와 알림 설정을 변경합니다.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
          ),
        ],
      ),
    );
  }
}

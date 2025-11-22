import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ai/features/community/community_board_page.dart';
import 'package:ai/features/tabs/jobs_tab.dart';
import 'package:ai/features/tabs/tabs_shared.dart';
import 'content_moderation_page.dart';
import 'corporate_approval_page.dart';

class AdminTabsPage extends StatefulWidget {
  const AdminTabsPage({super.key});

  @override
  State<AdminTabsPage> createState() => _AdminTabsPageState();
}

class _AdminTabsPageState extends State<AdminTabsPage> {
  int _index = 0;

  static const _pages = <Widget>[
    _AdminHomeTab(),
    CommunityBoardPage(),
    JobsTab(),
    _AdminManageTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return TabsNavigation(
      currentIndex: _index,
      goTo: (value) {
        if (value == _index) return;
        final clamped = value.clamp(0, _pages.length - 1).toInt();
        setState(() => _index = clamped);
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(child: _pages[_index]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          indicatorColor: AppColors.mint.withOpacity(0.18),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: '홈',
            ),
            NavigationDestination(
              icon: Icon(Icons.forum_outlined),
              selectedIcon: Icon(Icons.forum),
              label: '게시판',
            ),
            NavigationDestination(
              icon: Icon(Icons.work_outline),
              selectedIcon: Icon(Icons.work),
              label: '공고',
            ),
            NavigationDestination(
              icon: Icon(Icons.admin_panel_settings_outlined),
              selectedIcon: Icon(Icons.admin_panel_settings),
              label: '관리',
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminHomeTab extends StatelessWidget {
  const _AdminHomeTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Text(
                '관리자 홈',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              SizedBox(width: 8),
              Chip(label: Text('운영 전용')),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            '게시판 검수와 기업 인증 등 운영 도구에 빠르게 접근하세요.',
            style: TextStyle(color: AppColors.subtext),
          ),
          const SizedBox(height: 24),
          _AdminShortcutCard(
            title: '커뮤니티 관리',
            description: '게시글/댓글을 검수하고 커뮤니티 품질을 유지하세요.',
            icon: Icons.shield_outlined,
            onTap: () => context.push('/admin/content'),
          ),
          const SizedBox(height: 12),
          _AdminShortcutCard(
            title: '기업 회원 승인',
            description: '기업 인증 요청을 확인하고 승인/거절하세요.',
            icon: Icons.approval_outlined,
            onTap: () => context.push('/admin/corporate-approvals'),
          ),
        ],
      ),
    );
  }
}

class _AdminManageTab extends StatelessWidget {
  const _AdminManageTab();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            const Text(
              '운영 도구',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            _AdminShortcutCard(
              title: '커뮤니티 모더레이션',
              description: '신고된 게시글/댓글을 검토하고 조치합니다.',
              icon: Icons.policy_outlined,
              onTap: () => context.push('/admin/content'),
            ),
            const SizedBox(height: 12),
            _AdminShortcutCard(
              title: '기업 인증 관리',
              description: '기업 회원 신청 내역을 확인하고 승인/거절합니다.',
              icon: Icons.business_center_outlined,
              onTap: () => context.push('/admin/corporate-approvals'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminShortcutCard extends StatelessWidget {
  const _AdminShortcutCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: AppColors.text),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(description),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

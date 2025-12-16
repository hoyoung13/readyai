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
  int _index = 2;

  static final _pages = <Widget>[
    const CorporateApprovalPage(),
    const CommunityBoardPage(),
    const _AdminHomeTab(),
    const SafeArea(child: JobsTab()),
    const ContentModerationPage(),
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
        body: _pages[_index],
        bottomNavigationBar: NavigationBar(
          height: 72,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          selectedIndex: _index,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (i) => setState(() => _index = i),
          indicatorColor: AppColors.primary.withOpacity(0.18),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.verified_user_outlined),
              selectedIcon: Icon(Icons.verified_user),
              label: '계정승인',
            ),
            NavigationDestination(
              icon: Icon(Icons.forum_outlined),
              selectedIcon: Icon(Icons.forum),
              label: '게시판',
            ),
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: '홈',
            ),
            NavigationDestination(
              icon: Icon(Icons.campaign_outlined),
              selectedIcon: Icon(Icons.campaign),
              label: '공고',
            ),
            NavigationDestination(
              icon: Icon(Icons.report_gmailerrorred_outlined),
              selectedIcon: Icon(Icons.report_gmailerrorred),
              label: '신고관리',
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
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.camera_outlined,
                        color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('ReadyAi',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.text)),
                      SizedBox(height: 4),
                      Text('관리자센터', style: TextStyle(color: AppColors.subtext)),
                    ],
                  ),
                  const Spacer(),
                  const CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primarySoft,
                    child: Icon(Icons.notifications_none,
                        color: AppColors.primary),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              const Text(
                '안녕하세요, 관리자님',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                '오늘도 ReadyAi를 믿고 맡겨주세요.',
                style: TextStyle(color: AppColors.subtext, fontSize: 14),
              ),
              const SizedBox(height: 24),
              _AdminActionCard(
                title: '계정 승인',
                subtitle: '기업 계정 승인',
                icon: Icons.workspace_premium_outlined,
                onTap: () => context.push('/admin/corporate-approvals'),
              ),
              const SizedBox(height: 14),
              _AdminActionCard(
                title: '콘텐츠 관리',
                subtitle: '신고',
                icon: Icons.policy_outlined,
                onTap: () => context.push('/admin/content'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminActionCard extends StatelessWidget {
  const _AdminActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

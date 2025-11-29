import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ai/features/community/community_board_page.dart';
import 'package:ai/features/company/company_applicant_overview_page.dart';
import 'package:ai/features/company/company_home_page.dart';
import 'package:ai/features/company/company_job_list_page.dart';
import 'package:ai/features/company/company_my_page.dart';
import 'package:ai/features/tabs/tabs_shared.dart';

class CompanyTabsPage extends StatefulWidget {
  const CompanyTabsPage({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<CompanyTabsPage> createState() => _CompanyTabsPageState();
}

class _CompanyTabsPageState extends State<CompanyTabsPage> {
  late int _index = widget.initialIndex;

  final _pages = const <Widget>[
    CompanyHomePage(),
    CompanyJobListPage(),
    CommunityBoardPage(),
    CompanyMyPage(),
    CompanyApplicantOverviewPage(),
  ];

  void _onTabChanged(int value) {
    final clamped = value.clamp(0, _pages.length - 1).toInt();
    if (_index == clamped) return;
    setState(() => _index = clamped);
    switch (clamped) {
      case 0:
        context.go('/company/home');
        break;
      case 1:
        context.go('/company/jobs');
        break;
      case 2:
        context.go('/company/community');
        break;
      case 3:
        context.go('/company/mypage');
        break;
      case 4:
        context.go('/company/applicants');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return TabsNavigation(
      currentIndex: _index,
      goTo: _onTabChanged,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(child: _pages[_index]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _onTabChanged,
          indicatorColor: AppColors.mint.withOpacity(0.18),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: '홈',
            ),
            NavigationDestination(
              icon: Icon(Icons.work_outline),
              selectedIcon: Icon(Icons.work),
              label: '공고관리',
            ),
            NavigationDestination(
              icon: Icon(Icons.forum_outlined),
              selectedIcon: Icon(Icons.forum),
              label: '게시판',
            ),
            NavigationDestination(
              icon: Icon(Icons.assignment_outlined),
              selectedIcon: Icon(Icons.assignment),
              label: '나의 공고관리',
            ),
            NavigationDestination(
              icon: Icon(Icons.assignment_ind_outlined),
              selectedIcon: Icon(Icons.assignment_ind),
              label: '지원현황',
            ),
          ],
        ),
      ),
    );
  }
}

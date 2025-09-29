import 'package:flutter/material.dart';
import 'camera_tab.dart';
import 'home_tab.dart';
import 'jobs_tab.dart';
import 'profile_tab.dart';
import 'tabs_shared.dart';

class TabsPage extends StatefulWidget {
  const TabsPage({super.key});
  @override
  State<TabsPage> createState() => _TabsPageState();
}

class _TabsPageState extends State<TabsPage> {
  int _index = 0;

  static const _pages = <Widget>[
    HomeTab(), // 홈: 공고 슬라이드 + 추천
    JobsTab(), // 공고: 리스트
    CameraTab(), // 카메라/AI 면접 시작
    ProfileTab(), // 마이
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            icon: Icon(Icons.work_outline),
            selectedIcon: Icon(Icons.work),
            label: '공고',
          ),
          NavigationDestination(
            icon: Icon(Icons.photo_camera_outlined),
            selectedIcon: Icon(Icons.photo_camera),
            label: '카메라',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '마이',
          ),
        ],
      ),
    );
  }
}

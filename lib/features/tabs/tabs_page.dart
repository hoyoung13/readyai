import 'package:flutter/material.dart';

/// 앱 공통 컬러
class AppColors {
  static const bg = Color(0xFFF7F7F7);
  static const mint = Color(0xFF2EE8A5);
  static const text = Color(0xFF191919);
  static const subtext = Color(0xFF7C7C7C);
}

class TabsPage extends StatefulWidget {
  const TabsPage({super.key});
  @override
  State<TabsPage> createState() => _TabsPageState();
}

class _TabsPageState extends State<TabsPage> {
  int _index = 0;

  static const _pages = <Widget>[
    _HomeScreen(), // 홈: 공고 슬라이드 + 추천
    _JobsScreen(), // 공고: 리스트
    _CameraScreen(), // 카메라/AI 면접 시작
    _ProfileScreen(), // 마이
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

/// ---------- 홈(슬라이드) ----------
class _HomeScreen extends StatefulWidget {
  const _HomeScreen();
  @override
  State<_HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<_HomeScreen> {
  final _pageCtl = PageController(viewportFraction: 0.86);
  int _page = 0;

  final _slides = const [
    _SlideData(
      title: '지금 채용 중인\n공고를 골라보세요',
      subtitle: '관심 카테고리를 선택하면 더 정확해져요',
      leftColor: Color(0xFF7EE8FA),
      rightColor: Color(0xFFEEC0C6),
      emoji: '📋',
      cta: '공고 보러가기',
    ),
    _SlideData(
      title: 'AI 면접으로\n실전처럼 연습해요',
      subtitle: '시선/목소리/속도까지 자동 분석',
      leftColor: Color(0xFF84FAB0),
      rightColor: Color(0xFF8FD3F4),
      emoji: '🤖',
      cta: '면접 연습 시작',
    ),
    _SlideData(
      title: '지원 현황과\n피드백을 한눈에',
      subtitle: '기업 관심도와 진행 단계 요약',
      leftColor: Color(0xFFFFD3A5),
      rightColor: Color(0xFFFFAAA6),
      emoji: '📈',
      cta: '대시보드 열기',
    ),
  ];

  @override
  void dispose() {
    _pageCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 앱바 느낌
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset('assets/logo.png', width: 20, height: 20),
              ),
              const SizedBox(width: 8),
              const Text('앱이름', style: TextStyle(fontSize: 14)),
              const Spacer(),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.notifications_none),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // 슬라이드
        SizedBox(
          height: 200,
          child: PageView.builder(
            controller: _pageCtl,
            itemCount: _slides.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) => _SlideCard(data: _slides[i]),
          ),
        ),

        const SizedBox(height: 10),

        // 도트 인디케이터
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_slides.length, (i) {
            final active = i == _page;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: active ? 12 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: active ? AppColors.text : Colors.black26,
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),

        const SizedBox(height: 20),

        // 추천 섹션 (샘플)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: const [
              _SectionHeader(title: '추천 공고'),
              SizedBox(height: 8),
              _JobMiniCard(title: '백엔드 엔지니어', company: '무지개컴퍼니', tag: '신입/주니어'),
              SizedBox(height: 8),
              _JobMiniCard(
                  title: 'Flutter 앱 개발자', company: '아이엠', tag: '경력 1~3년'),
            ],
          ),
        ),
      ],
    );
  }
}

class _SlideData {
  final String title;
  final String subtitle;
  final Color leftColor;
  final Color rightColor;
  final String emoji;
  final String cta;
  const _SlideData({
    required this.title,
    required this.subtitle,
    required this.leftColor,
    required this.rightColor,
    required this.emoji,
    required this.cta,
  });
}

class _SlideCard extends StatelessWidget {
  const _SlideCard({required this.data});
  final _SlideData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [data.leftColor, data.rightColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 8),
            )
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            // 텍스트
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                        color: Colors.black87,
                      )),
                  const SizedBox(height: 6),
                  Text(
                    data.subtitle,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.mint,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onPressed: () {
                      // TODO: 각 CTA 라우팅
                    },
                    child: Text(data.cta),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              data.emoji,
              style: const TextStyle(fontSize: 40),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w800, fontSize: 16, height: 1.2)),
        const Spacer(),
        TextButton(
          onPressed: () {},
          child: const Text('전체보기'),
        ),
      ],
    );
  }
}

class _JobMiniCard extends StatelessWidget {
  const _JobMiniCard({
    required this.title,
    required this.company,
    required this.tag,
  });
  final String title;
  final String company;
  final String tag;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 6),
          )
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          const CircleAvatar(radius: 18, backgroundColor: Color(0xFFE9E9EC)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 4),
                Text('$company · $tag',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.subtext)),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.chevron_right),
          )
        ],
      ),
    );
  }
}

/// ---------- 공고 탭 ----------
class _JobsScreen extends StatelessWidget {
  const _JobsScreen();
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      children: const [
        _SectionHeader(title: '전체 공고'),
        SizedBox(height: 8),
        _JobMiniCard(title: 'iOS 엔지니어', company: '오로라랩스', tag: '경력 3~6년'),
        SizedBox(height: 8),
        _JobMiniCard(title: '데이터 분석가', company: '하모니', tag: '신입/주니어'),
        SizedBox(height: 8),
        _JobMiniCard(title: '백엔드(Java)', company: '클라우드웨이브', tag: '경력 2~5년'),
      ],
    );
  }
}

/// ---------- 카메라 탭 ----------
class _CameraScreen extends StatelessWidget {
  const _CameraScreen();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: IconButton(
              onPressed: () {
                // TODO: 카메라/면접 시작 라우팅
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('AI 면접 시작!')),
                );
              },
              iconSize: 42,
              icon: const Icon(Icons.photo_camera),
            ),
          ),
          const SizedBox(height: 12),
          const Text('AI 면접 시작', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('카테고리 선택 후 카메라로 넘어갑니다.',
              style: TextStyle(color: AppColors.subtext)),
        ],
      ),
    );
  }
}

/// ---------- 마이 탭 ----------
class _ProfileScreen extends StatelessWidget {
  const _ProfileScreen();
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      children: [
        Row(
          children: const [
            CircleAvatar(radius: 24, backgroundColor: Color(0xFFE9E9EC)),
            SizedBox(width: 12),
            Text('홍길동',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 16),
        _ProfileTile(
          icon: Icons.description_outlined,
          title: '이력서 업로드',
          onTap: () {},
        ),
        _ProfileTile(
          icon: Icons.public_outlined,
          title: '이력서 공개 설정',
          onTap: () {},
        ),
        _ProfileTile(
          icon: Icons.logout,
          title: '로그아웃',
          onTap: () {},
        ),
      ],
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({required this.icon, required this.title, this.onTap});
  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

/*import 'package:flutter/material.dart';

class TabsPage extends StatefulWidget {
  const TabsPage({super.key});
  @override
  State<TabsPage> createState() => _TabsPageState();
}

class _TabsPageState extends State<TabsPage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const _HomeScreen(),
      const _QuestionsScreen(),
      const _ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(child: pages[_index]),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: 카메라 화면 이동
        },
        shape: const CircleBorder(),
        child: const Icon(Icons.photo_camera, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _BottomBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}

// 🔻 하단바
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.currentIndex, required this.onTap});
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      height: 64,
      notchMargin: 8,
      shape: const AutomaticNotchedShape(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _TabItem(
            label: '질문',
            icon: Icons.forum_outlined,
            selectedIcon: Icons.forum,
            selected: currentIndex == 1,
            onTap: () => onTap(1),
          ),
          const SizedBox(width: 56), // 카메라 공간
          _TabItem(
            label: '마이',
            icon: Icons.person_outline,
            selectedIcon: Icons.person,
            selected: currentIndex == 2,
            onTap: () => onTap(2),
          ),
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.black : Colors.black54;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selected ? selectedIcon : icon, color: color),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

// 🔻 홈 화면
class _HomeScreen extends StatefulWidget {
  const _HomeScreen();
  @override
  State<_HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<_HomeScreen> {
  final _pageCtl = PageController(viewportFraction: 0.86);
  int _page = 0;

  final _slides = const [
    '지금 채용 중인\n공고를 골라보세요',
    'AI 면접으로\n연습을 시작해요',
    '지원 현황과\n피드백을 확인해요',
    '프로필을 채우면\n추천 정확도가 올라가요',
  ];

  @override
  void dispose() {
    _pageCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 앱바 느낌
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset('assets/logo.png', width: 20, height: 20),
              ),
              const SizedBox(width: 8),
              const Text('앱이름'),
            ],
          ),
        ),
        SizedBox(
          height: 160,
          child: PageView.builder(
            controller: _pageCtl,
            itemCount: _slides.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) => _SlideCard(text: _slides[i]),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_slides.length, (i) {
            final active = i == _page;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: active ? 10 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: active ? Colors.black87 : Colors.black26,
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _SlideCard extends StatelessWidget {
  const _SlideCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFE9E9EC),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(20),
        alignment: Alignment.centerLeft,
        child: Text(text, style: const TextStyle(fontSize: 18)),
      ),
    );
  }
}

// 🔻 나머지 탭
class _QuestionsScreen extends StatelessWidget {
  const _QuestionsScreen();
  @override
  Widget build(BuildContext context) => const Center(child: Text('질문 탭 콘텐츠'));
}

class _ProfileScreen extends StatelessWidget {
  const _ProfileScreen();
  @override
  Widget build(BuildContext context) => const Center(child: Text('마이 탭 콘텐츠'));
}
*/

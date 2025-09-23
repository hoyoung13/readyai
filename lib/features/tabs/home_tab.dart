import 'package:flutter/material.dart';

import 'tabs_shared.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
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
              SectionHeader(title: '추천 공고'),
              SizedBox(height: 8),
              JobMiniCard(title: '백엔드 엔지니어', company: '무지개컴퍼니', tag: '신입/주니어'),
              SizedBox(height: 8),
              JobMiniCard(
                  title: 'Flutter 앱 개발자', company: '아이엠', tag: '경력 1~3년'),
            ],
          ),
        ),
      ],
    );
  }
}

class _SlideData {
  const _SlideData({
    required this.title,
    required this.subtitle,
    required this.leftColor,
    required this.rightColor,
    required this.emoji,
    required this.cta,
  });

  final String title;
  final String subtitle;
  final Color leftColor;
  final Color rightColor;
  final String emoji;
  final String cta;
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
                  Text(
                    data.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                      color: Colors.black87,
                    ),
                  ),
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
                        horizontal: 14,
                        vertical: 10,
                      ),
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

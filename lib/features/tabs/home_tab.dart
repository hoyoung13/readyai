import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ai/features/notifications/notification_service.dart';
import 'package:go_router/go_router.dart';
import 'tabs_shared.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final NotificationService _notificationService = NotificationService();
  final _slides = const [
    _SlideData(
      title: '지금 채용 중인\n공고를 골라보세요',
      subtitle: '관심 카테고리를 선택하면 더 정확해져요',
      leftColor: Color(0xFF7EE8FA),
      rightColor: Color(0xFFEEC0C6),
      emoji: '📋',
      cta: '공고 보러가기',
      tabIndex: 1,
    ),
    _SlideData(
      title: 'AI 면접으로\n실전처럼 연습해요',
      subtitle: '시선/목소리/속도까지 자동 분석',
      leftColor: Color(0xFF84FAB0),
      rightColor: Color(0xFF8FD3F4),
      emoji: '🤖',
      cta: '면접 시작',
      tabIndex: 2,
    ),
    _SlideData(
      title: '지원 현황과\n피드백을 한눈에',
      subtitle: '기업 관심도와 진행 단계 요약',
      leftColor: Color(0xFFFFD3A5),
      rightColor: Color(0xFFFFAAA6),
      emoji: '📈',
      cta: '대시보드 열기',
      tabIndex: 3,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 앱바 느낌
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset('assets/logo.png', width: 50, height: 50),
                ),
                const SizedBox(width: 8),
                Text(
                  'ReadyAI',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                _buildNotificationButton(),
              ],
            ),
          ),

          const SizedBox(height: 8),

          Column(
            children: [
              for (var i = 0; i < _slides.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                _SlideCard(data: _slides[i]),
              ],
            ],
          ),

          const SizedBox(height: 24),
          const _CommunityPreviewCard(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildNotificationButton() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return IconButton(
        onPressed: _openNotifications,
        icon: const Icon(Icons.notifications_none),
      );
    }

    return StreamBuilder<int>(
      stream: _notificationService.watchUnreadCount(user.uid),
      builder: (context, snapshot) {
        final hasUnread = (snapshot.data ?? 0) > 0;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              onPressed: _openNotifications,
              icon: const Icon(Icons.notifications_none),
            ),
            if (hasUnread)
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _openNotifications() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인 후 알림을 볼 수 있어요.')),
      );
      return;
    }

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '알림',
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerRight,
          child: FractionallySizedBox(
            widthFactor: 0.88,
            child: _NotificationPanel(
              userId: user.uid,
              service: _notificationService,
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final offsetAnimation = Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
        return SlideTransition(position: offsetAnimation, child: child);
      },
    );
  }
}

class _NotificationPanel extends StatefulWidget {
  const _NotificationPanel({required this.userId, required this.service});

  final String userId;
  final NotificationService service;

  @override
  State<_NotificationPanel> createState() => _NotificationPanelState();
}

class _NotificationPanelState extends State<_NotificationPanel> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.service.markAllRead(widget.userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 12,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Text(
                    '알림',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: StreamBuilder<List<AppNotification>>(
                stream: widget.service.watchNotifications(widget.userId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final notifications =
                      snapshot.data ?? const <AppNotification>[];
                  if (notifications.isEmpty) {
                    return const Center(
                      child: Text('새로운 알림이 없습니다.'),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: notifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = notifications[index];
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: item.isRead
                              ? Colors.grey.shade100
                              : AppColors.mint.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                Text(
                                  _formatNotificationTime(item.createdAt),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.subtext,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item.message,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatNotificationTime(DateTime? time) {
  if (time == null) {
    return '방금 전';
  }
  final now = DateTime.now();
  final diff = now.difference(time);
  if (diff.inMinutes < 1) return '방금 전';
  if (diff.inHours < 1) return '${diff.inMinutes}분 전';
  if (diff.inDays < 1) return '${diff.inHours}시간 전';
  if (diff.inDays < 7) return '${diff.inDays}일 전';
  final month = time.month.toString().padLeft(2, '0');
  final day = time.day.toString().padLeft(2, '0');
  return '${time.year}.$month.$day';
}

class _SlideData {
  const _SlideData({
    required this.title,
    required this.subtitle,
    required this.leftColor,
    required this.rightColor,
    required this.emoji,
    required this.cta,
    this.tabIndex,
  });

  final String title;
  final String subtitle;
  final Color leftColor;
  final Color rightColor;
  final String emoji;
  final String cta;
  final int? tabIndex;
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
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
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
                    ],
                  ),
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
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    onPressed: () {
                      final targetTab = data.tabIndex;
                      if (targetTab != null) {
                        final navigation = TabsNavigation.of(context);
                        navigation?.goTo(targetTab);
                      }
                    },
                    child: Text(data.cta),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(data.emoji, style: const TextStyle(fontSize: 40)),
          ],
        ),
      ),
    );
  }
}

class _CommunityPreviewCard extends StatelessWidget {
  const _CommunityPreviewCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    '커뮤니티 게시판',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '다른 취준생들과 정보를 나누고 최신 글을 확인해 보세요.',
                    style: TextStyle(color: AppColors.subtext),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.tonal(
              onPressed: () {
                final navigation = TabsNavigation.of(context);
                if (navigation != null) {
                  navigation.goTo(3);
                  return;
                }
                context.push('/community');
              },
              child: const Text('바로가기'),
            ),
          ],
        ),
      ),
    );
  }
}

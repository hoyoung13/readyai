import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ai/core/router/app_router.dart';
import 'tabs_shared.dart';

class CompanyHomeTab extends StatelessWidget {
  const CompanyHomeTab({super.key});

  bool _isCompanyRole(String? role) {
    return role == 'company' || role == 'corporate';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final role = userRoleCache.value;
    final name = user?.displayName?.trim();
    final greetingName = _isCompanyRole(role)
        ? (name?.isNotEmpty == true ? name : '담당자')
        : (name?.isNotEmpty == true ? name : '사용자');

    final items = [
      _CompanyAction(
        title: '나의 공고',
        subtitle: '채용 공고 등록/관리',
        emoji: '📣',
        tag: '공고 관리',
        colors: const [Color(0xFFA181FF), Color(0xFFBFA4FF)],
        onTap: () => context.push('/profile/company-jobs'),
      ),
      _CompanyAction(
        title: '지원 내역',
        subtitle: '지원자 관리',
        emoji: '🗂️',
        tag: '지원자 관리',
        colors: const [Color(0xFF9BC5FF), Color(0xFFB4D5FF)],
        onTap: () => context.push('/profile/company-jobs'),
      ),
      _CompanyAction(
        title: '게시판',
        subtitle: '커뮤니티 소통',
        emoji: '💬',
        tag: '게시판',
        colors: const [Color(0xFFFFD3A5), Color(0xFFFFAAA6)],
        onTap: () => context.push('/community'),
        tabIndex: 3,
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.business_center_rounded,
                          color: AppColors.text),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'ReadyAI for Company',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7EE8FA), Color(0xFFEEC0C6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 14,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '안녕하세요, $greetingName님',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              '공고 관리와 지원자 확인을 한곳에서 빠르게!',
                              style: TextStyle(
                                color: AppColors.text,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                '기업 전용 대시보드',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.text,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text('📌', style: TextStyle(fontSize: 42)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Column(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    _CompanyActionCard(action: items[i]),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompanyAction {
  const _CompanyAction({
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.colors,
    required this.emoji,
    this.tabIndex,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final String tag;
  final List<Color> colors;
  final String emoji;
  final int? tabIndex;
  final VoidCallback? onTap;
}

class _CompanyActionCard extends StatelessWidget {
  const _CompanyActionCard({required this.action});

  final _CompanyAction action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            final navigation = TabsNavigation.of(context);
            if (navigation != null && action.tabIndex != null) {
              navigation.goTo(action.tabIndex!);
            }
            action.onTap?.call();
          },
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: action.colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          action.tag,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        action.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        action.subtitle,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(action.emoji, style: const TextStyle(fontSize: 40)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

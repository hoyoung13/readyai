import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ai/core/router/app_router.dart';
import 'tabs_shared.dart';
import 'package:ai/core/utils/role_utils.dart';

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
        subtitle: '공고 관리',
        icon: Icons.campaign_outlined,
        tag: '공고 관리',
        onTap: () => context.push('/profile/company-jobs'),
      ),
      _CompanyAction(
        title: '지원 내역',
        subtitle: '지원자 관리',
        icon: Icons.work_history_outlined,
        tag: '지원자 관리',
        onTap: () => context.push('/profile/company-jobs'),
      ),
      _CompanyAction(
        title: '게시판',
        subtitle: '게시판',
        icon: Icons.forum_outlined,
        tag: '커뮤니티',
        onTap: () => context.push('/community'),
        tabIndex: 3,
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/logo.png',
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Already',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.notifications_none_rounded,
                        color: AppColors.text),
                    onPressed: () => _launchNotificationSetting(),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text(
                '안녕하세요, $greetingName님',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '오늘의 추천 공고들을 확인해보세요',
                style: TextStyle(
                  color: AppColors.subtext,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFB486FF),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < items.length; i++)
                      _CompanyActionCard(
                        action: items[i],
                        isLast: i == items.length - 1,
                      ),
                  ],
                ),
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
    required this.icon,
    this.tabIndex,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final String tag;
  final IconData icon;
  final int? tabIndex;
  final VoidCallback? onTap;
}

class _CompanyActionCard extends StatelessWidget {
  const _CompanyActionCard({required this.action, this.isLast = false});

  final _CompanyAction action;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          final navigation = TabsNavigation.of(context);
          if (navigation != null && action.tabIndex != null) {
            navigation.goTo(action.tabIndex!);
          }
          action.onTap?.call();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            border: Border(
              bottom: isLast
                  ? BorderSide.none
                  : const BorderSide(color: Color(0x22FFFFFF), width: 1),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(action.icon, color: const Color(0xFF7B3EFF)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      action.subtitle,
                      style: const TextStyle(
                        color: Color(0xFFE9DBFF),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFF7B3EFF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  action.tag,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

void _launchNotificationSetting() async {
  final uri = Uri.parse('app-settings:');
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  }
}

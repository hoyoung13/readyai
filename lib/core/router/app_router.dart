import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ai/features/auth/login_page.dart';
import 'package:ai/features/auth/signup_page.dart';
import 'package:ai/features/tabs/tabs_page.dart';
import 'package:ai/features/camera/interview_camera_page.dart';
import 'package:ai/features/camera/interview_models.dart';
import 'package:ai/features/camera/interview_summary_page.dart';
import 'package:ai/features/profile/interview_history_page.dart';

final router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, __) => const LoginPage()),
    GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
    GoRoute(path: '/signup', builder: (_, __) => const SignupPage()),
    GoRoute(path: '/tabs', builder: (_, __) => const TabsPage()),
    GoRoute(
      path: '/profile/history',
      builder: (_, __) => const InterviewHistoryPage(),
    ),
    GoRoute(
      path: '/interview/camera',
      builder: (_, state) {
        final extra = state.extra;
        if (extra is InterviewCameraArgs) {
          return InterviewCameraPage(args: extra);
        }
        return const Scaffold(body: Center(child: Text('면접 정보를 불러오지 못했습니다.')));
      },
    ),
    GoRoute(
      path: '/interview/summary',
      builder: (_, state) {
        final extra = state.extra;
        if (extra is InterviewSummaryPageArgs) {
          return InterviewSummaryPage(args: extra);
        }
        return const Scaffold(
          body: Center(child: Text('면접 결과를 불러오지 못했습니다.')),
        );
      },
    ),
  ],
);

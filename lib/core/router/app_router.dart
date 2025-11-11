import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ai/features/auth/login_page.dart';
import 'package:ai/features/auth/signup_page.dart';
import 'package:ai/features/tabs/tabs_page.dart';
import 'package:ai/features/camera/interview_camera_page.dart';
import 'package:ai/features/camera/interview_models.dart';
import 'package:ai/features/camera/interview_summary_page.dart';
import 'package:ai/features/profile/interview_history_page.dart';
import 'package:ai/features/profile/interview_replay_page.dart';
import 'package:ai/features/profile/interview_folder_page.dart';
import 'package:ai/features/profile/interview_video_page.dart';
import 'package:ai/features/profile/job_activity_page.dart';
import 'package:ai/features/profile/resume/resume_dashboard_page.dart';
import 'package:ai/features/profile/resume/resume_editor_page.dart';

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
      path: '/profile/jobs',
      builder: (_, __) => const JobActivityPage(),
    ),
    GoRoute(
      path: '/profile/resume',
      builder: (_, __) => const ResumeDashboardPage(),
    ),
    GoRoute(
      path: '/profile/resume/new',
      builder: (_, state) {
        final extra = state.extra;
        return ResumeEditorPage(
          summary: extra is ResumeProfileSummary ? extra : null,
        );
      },
    ),
    GoRoute(
      path: '/profile/history/folder',
      builder: (_, state) {
        final extra = state.extra;
        if (extra is InterviewFolderPageArgs) {
          return InterviewFolderPage(args: extra);
        }
        return const Scaffold(
          body: Center(child: Text('폴더 정보를 불러오지 못했습니다.')),
        );
      },
    ),
    GoRoute(
      path: '/profile/history/video',
      builder: (_, state) {
        final extra = state.extra;
        if (extra is InterviewVideoPageArgs) {
          return InterviewVideoPage(args: extra);
        }
        return const Scaffold(
          body: Center(child: Text('영상을 불러오지 못했습니다.')),
        );
      },
    ),
    GoRoute(
      path: '/profile/history/replay',
      builder: (_, state) {
        final extra = state.extra;
        if (extra is InterviewReplayPageArgs) {
          return InterviewReplayPage(args: extra);
        }
        return const Scaffold(
          body: Center(child: Text('면접 다시보기 정보를 불러오지 못했습니다.')),
        );
      },
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

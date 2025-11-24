import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ai/features/auth/login_page.dart';
import 'package:ai/features/auth/signup_page.dart';
import 'package:ai/features/admin/admin_guard.dart';
import 'package:ai/features/admin/corporate_approval_page.dart';
import 'package:ai/features/admin/content_moderation_page.dart';
import 'package:ai/features/admin/admin_tabs_page.dart';
import 'package:ai/features/tabs/tabs_page.dart';
import 'package:ai/features/tabs/company_home_tab.dart';
import 'package:ai/features/jobs/company_route_guard.dart';
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
import 'package:ai/features/profile/profile_edit_page.dart';
import 'package:ai/features/community/community_board_page.dart';
import 'package:ai/features/community/community_list_page.dart';
import 'package:ai/features/community/community_post_detail_page.dart';
import 'package:ai/features/jobs/job_post_form_page.dart';
import 'package:ai/features/jobs/job_post_management_page.dart';
import 'package:ai/features/jobs/job_posting_service.dart';

final ValueNotifier<String?> userRoleCache = ValueNotifier<String?>(null);

final router = GoRouter(
  refreshListenable: userRoleCache,
  routes: [
    GoRoute(path: '/', builder: (_, __) => const LoginPage()),
    GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
    GoRoute(path: '/signup', builder: (_, __) => const SignupPage()),
    GoRoute(path: '/tabs', builder: (_, __) => const TabsPage()),
    GoRoute(
      path: '/company',
      builder: (_, __) => const CompanyRouteGuard(
        child: CompanyHomeTab(),
      ),
    ),
    GoRoute(
      path: '/admin',
      builder: (_, __) => const AdminRouteGuard(
        child: AdminTabsPage(),
      ),
    ),
    GoRoute(path: '/community', builder: (_, __) => const CommunityBoardPage()),
    GoRoute(
      path: '/community/list',
      builder: (_, state) {
        final extra = state.extra;
        final category = extra is String && extra.isNotEmpty ? extra : null;
        return CommunityListPage(initialCategory: category);
      },
    ),
    GoRoute(
      path: '/community/posts/:id',
      builder: (_, state) {
        final postId = state.pathParameters['id'];
        if (postId == null || postId.isEmpty) {
          return const Scaffold(
            body: Center(child: Text('게시글 정보를 불러오지 못했습니다.')),
          );
        }
        return CommunityPostDetailPage(postId: postId);
      },
    ),
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
      path: '/profile/edit',
      builder: (_, __) => const ProfileEditPage(),
    ),
    GoRoute(
      path: '/profile/company-jobs',
      builder: (_, __) => const JobPostManagementPage(),
    ),
    GoRoute(
      path: '/admin/content',
      builder: (_, __) => const AdminRouteGuard(
        child: ContentModerationPage(),
      ),
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
      path: '/admin/corporate-approvals',
      builder: (_, __) => const AdminRouteGuard(
        child: CorporateApprovalPage(),
      ),
    ),
    GoRoute(
      path: '/jobs/post',
      builder: (_, state) {
        final existing = state.extra;
        return JobPostFormPage(
          existing: existing is JobPostRecord ? existing : null,
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

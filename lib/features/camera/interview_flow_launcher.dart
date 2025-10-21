import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import 'interview_models.dart';
import 'interview_summary_page.dart';

class InterviewFlowLauncher {
  const InterviewFlowLauncher();

  Future<void> launch({
    required BuildContext context,
    required JobCategory category,
    required InterviewMode mode,
    required List<String> questions,
  }) async {
    final granted = await _ensureCameraPermission(context);
    if (!granted || !context.mounted) {
      return;
    }

    await _startInterview(context, category, mode, questions);
  }

  Future<void> _startInterview(
    BuildContext context,
    JobCategory category,
    InterviewMode mode,
    List<String> questions,
  ) async {
    final result = await context.push<InterviewRecordingResult>(
      '/interview/camera',
      extra: InterviewCameraArgs(
        category: category,
        mode: mode,
        questions: questions,
      ),
    );

    if (!context.mounted || result == null) {
      return;
    }

    if (result.hasError) {
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              result.transcriptionError ??
                  result.evaluationError ??
                  '녹화 결과를 불러오는 중 문제가 발생했습니다.',
            ),
          ),
        );
    }

    final summaryResult = await context.push<InterviewSummaryResult>(
      '/interview/summary',
      extra: InterviewSummaryPageArgs(
        result: result,
        category: category,
        mode: mode,
        questions: questions,
      ),
    );

    if (!context.mounted) {
      return;
    }

    if (summaryResult == InterviewSummaryResult.retry) {
      await _startInterview(context, category, mode, questions);
    }
  }

  Future<bool> _ensureCameraPermission(BuildContext context) async {
    final statuses = await Future.wait([
      Permission.camera.request(),
      Permission.microphone.request(),
    ]);

    final granted = statuses.every((status) => status.isGranted);
    if (granted) {
      return true;
    }

    final permanentlyDenied = statuses.any(
      (status) => status.isPermanentlyDenied || status.isRestricted,
    );

    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            permanentlyDenied
                ? '카메라/마이크 권한이 영구적으로 거부되었습니다. 설정에서 허용해 주세요.'
                : '카메라/마이크 권한이 필요합니다. 허용 후 이용해 주세요.',
          ),
          action: permanentlyDenied
              ? SnackBarAction(
                  label: '설정 열기',
                  onPressed: () {
                    openAppSettings();
                  },
                )
              : null,
        ),
      );
    return false;
  }
}

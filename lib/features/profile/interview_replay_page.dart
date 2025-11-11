import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import 'package:ai/features/camera/interview_models.dart';
import 'package:ai/features/camera/interview_summary_page.dart';
import 'package:ai/features/profile/models/interview_record.dart';
import 'package:ai/features/tabs/tabs_shared.dart';
import 'package:ai/features/camera/interview_flow_launcher.dart';

class InterviewReplayPageArgs {
  const InterviewReplayPageArgs({
    required this.record,
    this.previousRecord,
  });

  final InterviewRecord record;
  final InterviewRecord? previousRecord;
}

class InterviewReplayPage extends StatefulWidget {
  const InterviewReplayPage({super.key, required this.args});

  final InterviewReplayPageArgs args;

  @override
  State<InterviewReplayPage> createState() => _InterviewReplayPageState();
}

class _InterviewReplayPageState extends State<InterviewReplayPage> {
  VideoPlayerController? _controller;
  bool _isInitializing = false;
  String? _errorMessage;
  late final List<String> _strengths;
  late final List<String> _focusPoints;
  bool _isLaunchingPractice = false;

  static const _flowLauncher = InterviewFlowLauncher();

  @override
  void initState() {
    super.initState();
    _strengths = _buildStrengths();
    _focusPoints = _buildFocusPoints();
    _initializeVideo();
  }

  List<String> _buildStrengths() {
    final current = widget.args.record;
    final previous = widget.args.previousRecord;
    final messages = <String>[];

    final currentScore = current.result.score?.overallScore;
    final previousScore = previous?.result.score?.overallScore;

    if (currentScore != null) {
      if (previousScore != null) {
        final diff = currentScore - previousScore;
        if (diff > 0.2) {
          messages.add(
            '총점이 ${previousScore.toStringAsFixed(1)}점에서 '
            '${currentScore.toStringAsFixed(1)}점으로 ${diff.toStringAsFixed(1)}점 상승했어요.',
          );
        } else if (diff.abs() <= 0.2) {
          messages.add(
            '총점이 ${currentScore.toStringAsFixed(1)}점으로 안정적으로 유지되고 있어요.',
          );
        }
      } else {
        messages.add('이번 면접 총점은 ${currentScore.toStringAsFixed(1)}점이에요.');
      }
    }

    final currentFeedbacks =
        current.result.score?.perQuestionFeedback ?? const <QuestionFeedback>[];
    final previousFeedbacks = previous?.result.score?.perQuestionFeedback ??
        const <QuestionFeedback>[];

    if (currentFeedbacks.isNotEmpty) {
      final previousByQuestion = {
        for (final feedback in previousFeedbacks)
          if (feedback.question.isNotEmpty && feedback.score != null)
            feedback.question: feedback.score!
      };

      final improvements = <_QuestionDiff>[];
      for (final feedback in currentFeedbacks) {
        if (feedback.question.isEmpty || feedback.score == null) {
          continue;
        }
        final prevScore = previousByQuestion[feedback.question];
        if (prevScore != null) {
          final diff = feedback.score! - prevScore;
          if (diff > 0.3) {
            improvements.add(
              _QuestionDiff(
                question: feedback.question,
                difference: diff,
                score: feedback.score!,
                feedback: feedback.feedback,
              ),
            );
          }
        }
      }

      improvements.sort((a, b) => b.difference.compareTo(a.difference));
      if (improvements.isNotEmpty) {
        final top = improvements.first;
        messages.add(
          '"${top.question}" 질문에서 ${top.difference.toStringAsFixed(1)}점 향상되며 '
          '현재 ${top.score.toStringAsFixed(1)}점을 기록했어요.',
        );
        if (top.feedback.trim().isNotEmpty) {
          messages.add('피드백: ${top.feedback}');
        }
      } else {
        final sortedCurrent = currentFeedbacks
            .where((element) => element.score != null)
            .toList()
          ..sort((a, b) => b.score!.compareTo(a.score!));
        if (sortedCurrent.isNotEmpty) {
          final best = sortedCurrent.first;
          messages.add(
            '"${best.question}" 질문에서 ${best.score!.toStringAsFixed(1)}점으로 좋은 평가를 받았어요.',
          );
        }
      }
    }

    if (messages.isEmpty) {
      messages.add('이번 면접에서 성장한 부분을 계속 기록해 보세요.');
    }

    return messages;
  }

  List<String> _buildFocusPoints() {
    final current = widget.args.record;
    final previous = widget.args.previousRecord;
    final messages = <String>[];

    final currentScore = current.result.score?.overallScore;
    final previousScore = previous?.result.score?.overallScore;

    if (currentScore != null && previousScore != null) {
      final diff = currentScore - previousScore;
      if (diff < -0.2) {
        messages.add(
          '총점이 ${previousScore.toStringAsFixed(1)}점에서 '
          '${currentScore.toStringAsFixed(1)}점으로 ${diff.abs().toStringAsFixed(1)}점 낮아졌어요.',
        );
      }
    }

    final currentFeedbacks =
        current.result.score?.perQuestionFeedback ?? const <QuestionFeedback>[];
    final previousFeedbacks = previous?.result.score?.perQuestionFeedback ??
        const <QuestionFeedback>[];

    final previousByQuestion = {
      for (final feedback in previousFeedbacks)
        if (feedback.question.isNotEmpty && feedback.score != null)
          feedback.question: feedback.score!
    };

    final declines = <_QuestionDiff>[];
    for (final feedback in currentFeedbacks) {
      if (feedback.question.isEmpty || feedback.score == null) {
        continue;
      }
      final prevScore = previousByQuestion[feedback.question];
      if (prevScore != null) {
        final diff = feedback.score! - prevScore;
        if (diff < -0.3) {
          declines.add(
            _QuestionDiff(
              question: feedback.question,
              difference: diff,
              score: feedback.score!,
              feedback: feedback.feedback,
            ),
          );
        }
      }
    }

    declines.sort((a, b) => a.difference.compareTo(b.difference));
    if (declines.isNotEmpty) {
      final weakest = declines.first;
      messages.add(
        '"${weakest.question}" 질문은 ${weakest.difference.abs().toStringAsFixed(1)}점 낮아져 '
        '${weakest.score.toStringAsFixed(1)}점이에요.',
      );
      if (weakest.feedback.trim().isNotEmpty) {
        messages.add('피드백: ${weakest.feedback}');
      }
    }

    if (messages.isEmpty && currentFeedbacks.isNotEmpty) {
      final lowest = currentFeedbacks
          .where((element) => element.score != null)
          .toList()
        ..sort((a, b) => a.score!.compareTo(b.score!));
      if (lowest.isNotEmpty) {
        final weakest = lowest.first;
        messages.add(
          '"${weakest.question}" 질문은 ${weakest.score!.toStringAsFixed(1)}점으로 '
          '추가 연습이 필요해요.',
        );
        if (weakest.feedback.trim().isNotEmpty) {
          messages.add('피드백: ${weakest.feedback}');
        }
      }
    }

    if (messages.isEmpty) {
      messages.add('아직 비교할 데이터가 충분하지 않아요. 다음 면접을 기록해 보세요.');
    }

    return messages;
  }

  Future<void> _initializeVideo() async {
    final videoUrl = widget.args.record.videoUrl;
    if (videoUrl == null || videoUrl.isEmpty) {
      return;
    }

    setState(() {
      _isInitializing = true;
      _errorMessage = null;
    });

    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      await controller.initialize();
      controller.setLooping(false);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _isInitializing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '영상을 불러오지 못했습니다. 다시 시도해 주세요.';
        _isInitializing = false;
      });
    }
  }

  Future<void> _handlePracticeAgain() async {
    if (_isLaunchingPractice) {
      return;
    }

    final record = widget.args.record;
    final questions = record.questions;

    if (questions.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('이 기록에는 질문 정보가 없어 다시 연습을 시작할 수 없어요.'),
          ),
        );
      return;
    }

    setState(() {
      _isLaunchingPractice = true;
    });

    try {
      await _flowLauncher.launch(
        context: context,
        category: record.category,
        mode: record.mode,
        questions: questions,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('연습을 완료하면 면접 기록에서 바로 비교할 수 있어요.'),
          ),
        );
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLaunchingPractice = false;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.args.record;
    final controller = _controller;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('면접 다시보기'),
        actions: [
          IconButton(
            tooltip: '상세 결과 보기',
            onPressed: () {
              context.push(
                '/interview/summary',
                extra: InterviewSummaryPageArgs(
                  result: record.result,
                  category: record.category,
                  mode: record.mode,
                  questions: record.questions,
                  recordId: record.id,
                  shouldPersist: false,
                ),
              );
            },
            icon: const Icon(Icons.description_outlined),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ReplaySection(
              controller: controller,
              isInitializing: _isInitializing,
              errorMessage: _errorMessage,
              onRetry: _initializeVideo,
              record: record,
              onPracticeAgain: _handlePracticeAgain,
              isPracticeInProgress: _isLaunchingPractice,
            ),
            const SizedBox(height: 20),
            _InsightCard(
              title: '나아진 점',
              icon: Icons.trending_up,
              color: AppColors.mint,
              points: _strengths,
            ),
            const SizedBox(height: 16),
            _InsightCard(
              title: '아직 보완할 점',
              icon: Icons.flag_outlined,
              color: const Color(0xFFFF7A7A),
              points: _focusPoints,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReplaySection extends StatelessWidget {
  const _ReplaySection({
    required this.controller,
    required this.isInitializing,
    required this.errorMessage,
    required this.onRetry,
    required this.record,
    required this.onPracticeAgain,
    required this.isPracticeInProgress,
  });

  final VideoPlayerController? controller;
  final bool isInitializing;
  final String? errorMessage;
  final VoidCallback onRetry;
  final InterviewRecord record;
  final VoidCallback onPracticeAgain;
  final bool isPracticeInProgress;

  @override
  Widget build(BuildContext context) {
    final videoUrl = record.videoUrl;
    final hasQuestions = record.questions.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _InfoPill(
                label: '카테고리',
                value: record.category.title,
              ),
              const SizedBox(width: 8),
              _InfoPill(
                label: '면접 유형',
                value: record.mode.title,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (videoUrl == null || videoUrl.isEmpty)
            const _ReplayPlaceholder()
          else if (isInitializing)
            const Center(child: CircularProgressIndicator())
          else if (errorMessage != null)
            _ReplayError(errorMessage: errorMessage!, onRetry: onRetry)
          else if (controller != null)
            ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: controller!,
              builder: (context, value, _) {
                final aspectRatio =
                    value.isInitialized && value.aspectRatio != 0
                        ? value.aspectRatio
                        : 16 / 9;
                return Column(
                  children: [
                    AspectRatio(
                      aspectRatio: aspectRatio,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: VideoPlayer(controller!),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: () {
                            if (value.isPlaying) {
                              controller!.pause();
                            } else {
                              controller!.play();
                            }
                          },
                          icon: Icon(
                            value.isPlaying
                                ? Icons.pause_circle
                                : Icons.play_circle,
                          ),
                          label: Text(value.isPlaying ? '일시정지' : '재생'),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.tonalIcon(
                          onPressed: () {
                            controller!
                              ..seekTo(Duration.zero)
                              ..play();
                          },
                          icon: const Icon(Icons.replay),
                          label: const Text('처음부터'),
                        ),
                      ],
                    ),
                  ],
                );
              },
            )
          else
            const _ReplayPlaceholder(),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: !hasQuestions || isPracticeInProgress
                  ? null
                  : onPracticeAgain,
              icon: isPracticeInProgress
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  : const Icon(Icons.videocam_outlined),
              label: Text(
                hasQuestions ? '같은 질문으로 다시 연습하기' : '질문 정보를 찾을 수 없어요',
              ),
            ),
          ),
          if (!hasQuestions)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                '이 기록에는 질문이 저장되어 있지 않아 다시 연습을 시작할 수 없어요.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.subtext,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReplayPlaceholder extends StatelessWidget {
  const _ReplayPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F6F6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hide_image_outlined, color: AppColors.subtext, size: 40),
          SizedBox(height: 12),
          Text(
            '저장된 면접 영상이 없어요.',
            style: TextStyle(color: AppColors.subtext),
          ),
        ],
      ),
    );
  }
}

class _ReplayError extends StatelessWidget {
  const _ReplayError({required this.errorMessage, required this.onRetry});

  final String errorMessage;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
        const SizedBox(height: 8),
        Text(
          errorMessage,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        FilledButton(onPressed: onRetry, child: const Text('다시 시도')),
      ],
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.points,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<String> points;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...List.generate(points.length, (index) {
            final point = points[index];
            final isLast = index == points.length - 1;
            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• '),
                  Expanded(
                    child: Text(
                      point,
                      style: const TextStyle(height: 1.4),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(999),
      ),
      child: RichText(
        text: TextSpan(
          text: '$label  ',
          style: const TextStyle(color: AppColors.subtext, fontSize: 13),
          children: [
            TextSpan(
              text: value,
              style: const TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionDiff {
  const _QuestionDiff({
    required this.question,
    required this.difference,
    required this.score,
    required this.feedback,
  });

  final String question;
  final double difference;
  final double score;
  final String feedback;
}

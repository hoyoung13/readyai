import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ai/features/camera/interview_models.dart';
import 'package:ai/features/camera/interview_summary_page.dart';
import 'package:ai/features/camera/interview_flow_launcher.dart';
import 'package:ai/features/profile/interview_replay_page.dart';
import 'package:ai/features/profile/models/interview_folder.dart';
import 'package:ai/features/profile/models/interview_record.dart';
import 'package:ai/features/tabs/tabs_shared.dart';

class InterviewFolderPageArgs {
  const InterviewFolderPageArgs({required this.folder});

  final InterviewFolder folder;
}

class InterviewFolderPage extends StatefulWidget {
  const InterviewFolderPage({super.key, required this.args});

  final InterviewFolderPageArgs args;
  @override
  State<InterviewFolderPage> createState() => _InterviewFolderPageState();
}

class _InterviewFolderPageState extends State<InterviewFolderPage> {
  final InterviewFlowLauncher _flowLauncher = const InterviewFlowLauncher();
  bool _isLaunchingPractice = false;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('로그인이 필요합니다.')),
      );
    }

    final stream = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('interviews')
        .where('folderId', isEqualTo: widget.args.folder.id)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        var records = const <InterviewRecord>[];
        Widget body;

        if (snapshot.hasError) {
          body = const Center(
            child: Text('면접 기록을 불러오지 못했습니다.'),
          );
        } else if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          body = const Center(child: CircularProgressIndicator());
        } else {
          records = snapshot.data?.docs.map(InterviewRecord.fromDoc).toList() ??
              <InterviewRecord>[];

          records.sort((a, b) => b.createdAt.compareTo(a.createdAt));

          if (records.isEmpty) {
            body = const _EmptyFolderState();
          } else {
            body = ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
              itemCount: records.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final record = records[index];
                return _RecordTile(
                  record: record,
                  previousRecord:
                      index < records.length - 1 ? records[index + 1] : null,
                );
              },
            );
          }
        }

        return Scaffold(
          backgroundColor: AppColors.bg,
          appBar: AppBar(
            title: Text(widget.args.folder.displayName),
            backgroundColor: Colors.white,
            foregroundColor: AppColors.text,
            elevation: 0.5,
          ),
          body: body,
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: ElevatedButton(
              onPressed: records.isEmpty || _isLaunchingPractice
                  ? null
                  : () => _showReplayPicker(records),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: const Color(0xFFE9E9E9),
                foregroundColor: AppColors.text,
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: _isLaunchingPractice
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  : const Text('면접 다시보기'),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showReplayPicker(List<InterviewRecord> records) async {
    if (records.isEmpty) {
      return;
    }

    final selected = await showModalBottomSheet<InterviewRecord>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return _ReplayPickerSheet(records: records);
      },
    );
    if (!mounted || selected == null) {
      return;
    }

    await _startPractice(selected);
  }

  Future<void> _startPractice(InterviewRecord record) async {
    if (record.questions.isEmpty) {
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
        questions: record.questions,
        comparisonRecord: record,
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
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({
    required this.record,
    this.previousRecord,
  });

  final InterviewRecord record;
  final InterviewRecord? previousRecord;

  @override
  Widget build(BuildContext context) {
    final score = record.result.score?.overallScore;
    final practiceName = record.practiceName;
    final hasError = record.result.hasError;
    final errorMessage = record.result.evaluationError ??
        record.result.transcriptionError ??
        record.result.faceAnalysisError;
    final statusLabel =
        score != null ? '총점 ${score.toStringAsFixed(1)}점' : '평가 대기';

    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (practiceName != null && practiceName.isNotEmpty)
                          ? practiceName
                          : record.mode.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${record.mode.title} · ${_formatDate(record.createdAt)}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.subtext,
                      ),
                    ),
                  ],
                ),
              ),
              if (record.videoUrl != null)
                FilledButton.icon(
                  onPressed: () {
                    context.push(
                      '/profile/history/replay',
                      extra: InterviewReplayPageArgs(
                        record: record,
                        previousRecord: previousRecord,
                      ),
                    );
                  },
                  icon: const Icon(Icons.replay_circle_filled),
                  label: const Text('영상 보기'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                statusLabel,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              TextButton.icon(
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
                      practiceName: record.practiceName,
                    ),
                  );
                },
                icon: const Icon(Icons.description_outlined),
                label: const Text('결과 보기'),
              ),
            ],
          ),
          if (hasError && errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              errorMessage,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.redAccent,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReplayPickerSheet extends StatelessWidget {
  const _ReplayPickerSheet({required this.records});

  final List<InterviewRecord> records;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return FractionallySizedBox(
      heightFactor: 0.9,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: media.viewInsets.bottom + 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '어떤 면접을 기준으로 다시 연습할까요?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '질문이 저장된 영상만 선택할 수 있어요.',
                style: TextStyle(color: AppColors.subtext),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  itemCount: records.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final record = records[index];
                    final practiceName = record.practiceName;
                    final title =
                        (practiceName != null && practiceName.isNotEmpty)
                            ? practiceName
                            : record.mode.title;
                    final subtitle =
                        '${_formatDate(record.createdAt)} · ${record.mode.title}';
                    final score = record.result.score?.overallScore;
                    final scoreLabel = score != null
                        ? '${score.toStringAsFixed(1)}점'
                        : '평가 대기';
                    final hasQuestions = record.questions.isNotEmpty;
                    return ListTile(
                      onTap: hasQuestions
                          ? () => Navigator.of(context).pop(record)
                          : null,
                      title: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(subtitle),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            scoreLabel,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          if (!hasQuestions)
                            const Text(
                              '질문 없음',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.redAccent,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyFolderState extends StatelessWidget {
  const _EmptyFolderState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(
            Icons.folder_off_outlined,
            size: 48,
            color: AppColors.subtext,
          ),
          SizedBox(height: 16),
          Text(
            '아직 이 폴더에는 면접 기록이 없습니다.',
            style: TextStyle(color: AppColors.subtext),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime date) {
  final y = date.year.toString();
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  final hh = date.hour.toString().padLeft(2, '0');
  final mm = date.minute.toString().padLeft(2, '0');
  return '$y.$m.$d $hh:$mm';
}

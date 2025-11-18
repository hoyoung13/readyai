import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ai/features/camera/interview_models.dart';
import 'package:ai/features/camera/interview_summary_page.dart';
import 'package:ai/features/profile/interview_video_page.dart';
import 'package:ai/features/profile/interview_replay_page.dart';
import 'package:ai/features/profile/models/interview_folder.dart';
import 'package:ai/features/profile/models/interview_record.dart';
import 'package:ai/features/tabs/tabs_shared.dart';

class InterviewFolderPageArgs {
  const InterviewFolderPageArgs({required this.folder});

  final InterviewFolder folder;
}

class InterviewFolderPage extends StatelessWidget {
  const InterviewFolderPage({super.key, required this.args});

  final InterviewFolderPageArgs args;

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
        .where('categoryKey', isEqualTo: args.folder.id)
        .orderBy('createdAt', descending: true)
        .snapshots();
//.orderBy('createdAt', descending: true)
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(args.folder.displayName),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.text,
        elevation: 0.5,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('면접 기록을 불러오지 못했습니다.'),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
//const <InterviewRecord>[]; 두줄아래
          final records =
              snapshot.data?.docs.map(InterviewRecord.fromDoc).toList() ??
                  <InterviewRecord>[];

          records.sort((a, b) => b.createdAt.compareTo(a.createdAt));

          if (records.isEmpty) {
            return const _EmptyFolderState();
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            itemCount: records.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final record = records[index];
              return _RecordTile(
                record: record,
                previousRecord:
                    index < records.length - 1 ? records[index + 1] : null,
                canReplay: index == 0,
              );
            },
          );
        },
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({
    required this.record,
    this.previousRecord,
    required this.canReplay,
  });

  final InterviewRecord record;
  final InterviewRecord? previousRecord;
  final bool canReplay;

  @override
  Widget build(BuildContext context) {
    final score = record.result.score?.overallScore;
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
                      record.mode.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(record.createdAt),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.subtext,
                      ),
                    ),
                  ],
                ),
              ),
              if (record.videoUrl != null && canReplay)
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
                  label: const Text('면접 다시보기'),
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

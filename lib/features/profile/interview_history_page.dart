import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:ai/features/camera/interview_models.dart';
import 'package:ai/features/camera/interview_summary_page.dart';
import 'package:ai/features/profile/models/interview_record.dart';
import 'package:ai/features/tabs/tabs_shared.dart';

class InterviewHistoryPage extends StatelessWidget {
  const InterviewHistoryPage({super.key});

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
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('면접 영상 & 결과'),
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

          final records =
              snapshot.data?.docs.map(InterviewRecord.fromDoc).toList() ??
                  const <InterviewRecord>[];

          if (records.isEmpty) {
            return const _EmptyHistoryState();
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            itemCount: records.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return _HistoryTile(record: records[index]);
            },
          );
        },
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.record});

  final InterviewRecord record;

  @override
  Widget build(BuildContext context) {
    final score = record.result.score?.overallScore;
    final hasError = record.result.hasError;
    final statusLabel =
        score != null ? '총점 ${score.toStringAsFixed(1)}점' : '평가 대기';
    final errorMessage = record.result.evaluationError ??
        record.result.transcriptionError ??
        record.result.faceAnalysisError;

    return GestureDetector(
      onTap: () {
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
      child: Container(
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
            Text(
              record.category.title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${record.mode.title} · ${_formatDate(record.createdAt)}',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.subtext,
              ),
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
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.subtext,
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
      ),
    );
  }
}

class _EmptyHistoryState extends StatelessWidget {
  const _EmptyHistoryState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(
            Icons.play_circle_outline,
            size: 48,
            color: AppColors.subtext,
          ),
          SizedBox(height: 16),
          Text(
            '아직 저장된 면접 기록이 없습니다.',
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

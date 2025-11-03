import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ai/features/camera/interview_models.dart';
import 'package:ai/features/camera/interview_summary_page.dart';
import 'package:ai/features/profile/models/interview_record.dart';
import 'tabs_shared.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(
        child: Text('로그인이 필요합니다.'),
      );
    }

    final profileStream = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots();

    final interviewsStream = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('interviews')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: profileStream,
      builder: (context, profileSnapshot) {
        if (profileSnapshot.hasError) {
          print('🔥 프로필 로드 에러: ${profileSnapshot.error}');
          return const Center(
            child: Text('프로필 정보를 불러오지 못했습니다.'),
          );
        }

        if (profileSnapshot.connectionState == ConnectionState.waiting &&
            !profileSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final profileData = profileSnapshot.data?.data();
        final name = profileData?['name'] as String? ??
            user.displayName ??
            (user.email ?? '사용자');
        final resumePublic = profileData?['resumePublic'] as bool? ?? false;

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: interviewsStream,
          builder: (context, interviewsSnapshot) {
            if (interviewsSnapshot.hasError) {
              return const Center(
                child: Text('면접 기록을 불러오지 못했습니다.'),
              );
            }

            final records = interviewsSnapshot.data?.docs
                    .map(InterviewRecord.fromDoc)
                    .toList() ??
                const <InterviewRecord>[];

            final practiceCount = records.length;
            final scored = records
                .map((record) => record.result.score?.overallScore)
                .whereType<double>()
                .toList();
            final averageScore = scored.isEmpty
                ? null
                : scored.reduce((a, b) => a + b) / scored.length;

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
              children: [
                const Text(
                  '마이페이지',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 20),
                _ProfileHeaderCard(
                  name: name,
                  resumePublic: resumePublic,
                  onLogout: () => _handleLogout(context),
                ),
                const SizedBox(height: 24),
                const _ProfileActionCard(
                  title: '이력서',
                  description: '추가/수정 · 공개 설정',
                  buttonLabel: '관리',
                ),
                const SizedBox(height: 14),
                _ProfileActionCard(
                  title: '면접 영상 & 결과',
                  description: '저장한 기록 확인',
                  buttonLabel: '보기',
                  onPressed: () => context.push('/profile/history'),
                ),
                const SizedBox(height: 14),
                _ProfileActionCard(
                  title: '채용 공고',
                  description: '스크랩/지원 내역',
                  buttonLabel: '확인',
                  onPressed: () => context.push('/profile/jobs'),
                ),
                const SizedBox(height: 28),
                const Text(
                  '통계',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _ProfileStatCard(
                        title: '연습 횟수',
                        value: '${practiceCount}회',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ProfileStatCard(
                        title: '평균 점수',
                        value: averageScore != null
                            ? '${averageScore.toStringAsFixed(1)}점'
                            : '-',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                _RecentInterviewsSection(records: records),
              ],
            );
          },
        );
      },
    );
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard({
    required this.name,
    required this.resumePublic,
    required this.onLogout,
  });

  final String name;
  final bool resumePublic;
  final VoidCallback onLogout;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF9B748), Color(0xFFED4C92)],
              ),
            ),
            child: const Icon(
              Icons.camera_alt_outlined,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '이력서 공개: ${resumePublic ? 'ON' : 'OFF'}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.subtext,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onLogout,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.subtext,
              textStyle: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
  }
}

class _ProfileActionCard extends StatelessWidget {
  const _ProfileActionCard({
    required this.title,
    required this.description,
    required this.buttonLabel,
    this.onPressed,
  });

  final String title;
  final String description;
  final String buttonLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFEDEBFE),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.subtext,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: onPressed,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: const Color(0xFF6D5CFF),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
            child: Text(buttonLabel),
          ),
        ],
      ),
    );
  }
}

class _RecentInterviewsSection extends StatelessWidget {
  const _RecentInterviewsSection({required this.records});

  final List<InterviewRecord> records;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '최근 면접 기록',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 16),
        if (records.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Text(
              '아직 저장된 면접 기록이 없습니다.',
              style: TextStyle(color: AppColors.subtext),
            ),
          )
        else
          ...records.take(3).map(
                (record) => _InterviewPreviewTile(record: record),
              ),
      ],
    );
  }
}

class _InterviewPreviewTile extends StatelessWidget {
  const _InterviewPreviewTile({required this.record});

  final InterviewRecord record;

  @override
  Widget build(BuildContext context) {
    final score = record.result.score?.overallScore;
    final scoreLabel = score != null ? '${score.toStringAsFixed(1)}점' : '평가 대기';
    final date = record.createdAt;
    final formattedDate =
        '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';

    return InkWell(
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
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              record.category.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${record.mode.title} · $formattedDate',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.subtext,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '총점: $scoreLabel',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _handleLogout(BuildContext context) async {
  await FirebaseAuth.instance.signOut();
  if (!context.mounted) return;
  context.go('/login');
}

class _ProfileStatCard extends StatelessWidget {
  const _ProfileStatCard({
    required this.title,
    required this.value,
  });

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.subtext,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

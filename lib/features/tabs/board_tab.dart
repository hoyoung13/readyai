import 'package:flutter/material.dart';

import 'tabs_shared.dart';

class BoardTab extends StatelessWidget {
  const BoardTab({super.key});

  static const _categories = [
    _BoardCategory(
      name: '전체 게시판',
      description: '모든 글을 한눈에 확인',
      emoji: '🌐',
    ),
    _BoardCategory(
      name: '스터디/모임 모집',
      description: '함께 성장할 팀원 찾기',
      emoji: '🤝',
    ),
    _BoardCategory(
      name: '자유게시판',
      description: '일상 공유 & 잡담',
      emoji: '💬',
    ),
    _BoardCategory(
      name: '면접 후기/꿀팁',
      description: '실전 경험 아카이브',
      emoji: '📝',
    ),
    _BoardCategory(
      name: '질문 게시판',
      description: '궁금한 건 바로 질문',
      emoji: '❓',
    ),
  ];

  static const _features = [
    _BoardFeature(
      icon: Icons.edit_outlined,
      title: '누구나 글쓰기',
      description: '모든 가입 유저는 즉시 글 작성과 첨부 기능 사용 가능',
    ),
    _BoardFeature(
      icon: Icons.remove_red_eye_outlined,
      title: '조회수 추적',
      description: '게시글/댓글 열람 수를 실시간 카운트하여 인기 지표 제공',
    ),
    _BoardFeature(
      icon: Icons.thumb_up_off_alt,
      title: '좋아요/싫어요',
      description: '게시글·댓글에 감정 피드백과 정렬 옵션 제공',
    ),
    _BoardFeature(
      icon: Icons.chat_bubble_outline,
      title: '깊이 있는 댓글',
      description: '댓글에도 좋아요/싫어요와 실시간 대댓글 푸시 지원',
    ),
    _BoardFeature(
      icon: Icons.report_outlined,
      title: '신고/모니터링',
      description: '커뮤니티 가이드를 위반하면 바로 신고하고 관리자 알림',
    ),
  ];

  static const _posts = [
    _BoardPost(
      title: '면접 스터디 같이 하실 분 구합니다',
      author: '디자인토끼',
      category: '스터디/모임 모집',
      views: 412,
      likes: 35,
      dislikes: 2,
      comments: 18,
    ),
    _BoardPost(
      title: '오늘 받은 면접 질문 공유합니다 (대기업 SW)',
      author: '합격하고싶다',
      category: '면접 후기/꿀팁',
      views: 987,
      likes: 76,
      dislikes: 3,
      comments: 41,
    ),
    _BoardPost(
      title: '비동기 처리에서 setState 타이밍 질문',
      author: 'Flutter러버',
      category: '질문 게시판',
      views: 215,
      likes: 21,
      dislikes: 0,
      comments: 9,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '게시판',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.mint.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  '누구나 참여',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.notifications_outlined),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '스터디 모집부터 면접 후기, 궁금증까지 한 곳에서 공유하세요.',
            style: TextStyle(
              color: Colors.black.withOpacity(0.65),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          _BoardIntroCard(),
          const SizedBox(height: 28),
          const SectionHeader(title: '게시판 카테고리'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final category in _categories)
                _CategoryChip(category: category),
            ],
          ),
          const SizedBox(height: 28),
          const SectionHeader(title: '핵심 기능'),
          const SizedBox(height: 12),
          Column(
            children: [
              for (final feature in _features) ...[
                _FeatureTile(feature: feature),
                const SizedBox(height: 10),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          const SizedBox(height: 28),
          const SectionHeader(title: '실시간 인기 글'),
          const SizedBox(height: 12),
          Column(
            children: [
              for (final post in _posts) ...[
                _PostPreviewCard(post: post),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _BoardIntroCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7EE8FA), Color(0xFF80FF72)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '글쓰기로 커뮤니티 활성화',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '조회수, 좋아요/싫어요, 댓글 소통까지 한 눈에 확인하고\n맞춤 알림을 받아보세요.',
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('글쓰기'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.search),
                  label: const Text('전체게시판'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black,
                    side: const BorderSide(color: Colors.black54),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category});

  final _BoardCategory category;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(category.emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 8),
          Text(
            category.name,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            category.description,
            style: const TextStyle(fontSize: 12, color: AppColors.subtext),
          ),
        ],
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({required this.feature});

  final _BoardFeature feature;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 6),
          )
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.mint.withOpacity(0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(10),
            child: Icon(feature.icon, color: Colors.black87),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  feature.description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.subtext,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PostPreviewCard extends StatelessWidget {
  const _PostPreviewCard({required this.post});

  final _BoardPost post;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE9E9EC)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.mint.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  post.category,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                post.author,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.subtext,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            post.title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _StatChip(
                  icon: Icons.remove_red_eye_outlined, label: '${post.views}'),
              const SizedBox(width: 10),
              _StatChip(
                  icon: Icons.thumb_up_alt_outlined, label: '${post.likes}'),
              const SizedBox(width: 10),
              _StatChip(
                  icon: Icons.thumb_down_alt_outlined,
                  label: '${post.dislikes}'),
              const SizedBox(width: 10),
              _StatChip(
                  icon: Icons.chat_bubble_outline, label: '${post.comments}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.subtext),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.subtext),
          ),
        ],
      ),
    );
  }
}

class _BoardCategory {
  const _BoardCategory({
    required this.name,
    required this.description,
    required this.emoji,
  });

  final String name;
  final String description;
  final String emoji;
}

class _BoardFeature {
  const _BoardFeature({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}

class _BoardPost {
  const _BoardPost({
    required this.title,
    required this.author,
    required this.category,
    required this.views,
    required this.likes,
    required this.dislikes,
    required this.comments,
  });

  final String title;
  final String author;
  final String category;
  final int views;
  final int likes;
  final int dislikes;
  final int comments;
}

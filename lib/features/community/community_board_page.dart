import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ai/features/notifications/notification_service.dart';
import '../tabs/tabs_shared.dart';
import 'community_post.dart';
import 'community_post_service.dart';

const communityCategories = [
  '공지',
  '자유',
  'Q&A',
  '면접 후기',
  '스터디 구인',
  '취업 정보',
];

const _boardCategories = [
  _BoardCategory(
    name: '전체',
    description: '모든 글을 한눈에 확인',
    emoji: '🌐',
  ),
  _BoardCategory(
    name: '공지',
    description: '운영 소식 & 업데이트',
    emoji: '📢',
  ),
  _BoardCategory(
    name: '스터디 구인',
    description: '함께 성장할 팀원 찾기',
    emoji: '🤝',
  ),
  _BoardCategory(
    name: '자유',
    description: '일상 공유 & 잡담',
    emoji: '💬',
  ),
  _BoardCategory(
    name: '면접 후기',
    description: '실전 경험 아카이브',
    emoji: '📝',
  ),
  _BoardCategory(
    name: 'Q&A',
    description: '궁금한 건 바로 질문',
    emoji: '❓',
  ),
  _BoardCategory(
    name: '취업 정보',
    description: '채용 소식 & 준비',
    emoji: '💼',
  ),
];

class CommunityBoardPage extends StatefulWidget {
  const CommunityBoardPage({super.key});

  @override
  State<CommunityBoardPage> createState() => _CommunityBoardPageState();
}

class _CommunityBoardPageState extends State<CommunityBoardPage> {
  final CommunityPostService _service = CommunityPostService();
  String? _selectedCategory;
  bool _isAdmin = false;
  String? _currentUserId;
  StreamSubscription<User?>? _authSub;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _handleCompose,
        icon: const Icon(Icons.edit),
        label: const Text('글쓰기'),
      ),
      body: SafeArea(
        child: StreamBuilder<List<CommunityPost>>(
          stream: _service.watchPosts(category: _selectedCategory),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _ErrorView(error: snapshot.error);
            }

            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final posts = snapshot.data ?? const <CommunityPost>[];

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(onRefresh: () => setState(() {})),
                  const SizedBox(height: 20),
                  _IntroCard(
                    onCompose: _handleCompose,
                    onShowAll: () => _openListPage(),
                  ),
                  const SizedBox(height: 28),
                  _CategorySection(
                    categories: _boardCategories,
                    selectedCategory: _selectedCategory,
                    onSelected: (value) {
                      setState(() => _selectedCategory = value);
                      _openListPage(category: value);
                    },
                  ),
                  const SizedBox(height: 28),
                  _PopularSection(
                    service: _service,
                    currentUserId: _currentUserId,
                    isAdmin: _isAdmin,
                    onEdit: _handleEdit,
                    onDelete: (post) =>
                        _handleDelete(post, _currentUserId == post.authorId),
                    onOpen: _openPostDetail,
                  ),
                  if (posts.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    const _SectionTitle('최신 글'),
                    const SizedBox(height: 12),
                    ...posts.map((post) {
                      final isAuthor = _currentUserId != null &&
                          _currentUserId == post.authorId;
                      final canDelete = _isAdmin || isAuthor;
                      return _PostPreviewCard(
                        post: post,
                        canEdit: isAuthor,
                        canDelete: canDelete,
                        onEdit: () => _handleEdit(post),
                        onDelete: () => _handleDelete(post, isAuthor),
                        onTap: () => _openPostDetail(post),
                      );
                    }),
                  ] else ...[
                    const SizedBox(height: 24),
                    const _EmptyPostsView(),
                  ],
                  const SizedBox(height: 28),
                  const _GuideCard(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _loadUserRole(User user) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final role = snapshot.data()?['role'] as String?;
      if (!mounted) return;
      setState(() => _isAdmin = role == 'admin');
    } catch (_) {
      if (!mounted) return;
      setState(() => _isAdmin = false);
    }
  }

  Future<void> _handleEdit(CommunityPost post) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인 후 이용해 주세요.')),
      );
      return;
    }

    if (user.uid != post.authorId) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('본인이 작성한 글만 수정할 수 있어요.')),
      );
      return;
    }

    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: CommunityPostComposer(
          initialCategory: post.category,
          initialTitle: post.title,
          initialContent: post.content,
          submitLabel: '수정하기',
          onSubmit: (category, title, content) => _service.updatePost(
            post: post,
            editor: user,
            category: category,
            title: title,
            content: content,
          ),
        ),
      ),
    );

    if (updated == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('게시글을 수정했어요.')),
      );
    }
  }

  Future<void> _handleDelete(CommunityPost post, bool isAuthor) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인 후 이용해 주세요.')),
      );
      return;
    }

    if (!isAuthor && !_isAdmin) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('삭제 권한이 없습니다.')),
      );
      return;
    }

    final requiresReason = _isAdmin && user.uid != post.authorId;
    String blockedReason = '작성자에 의해 삭제되었습니다.';

    if (requiresReason) {
      final reason = await _showDeleteReasonDialog();
      if (reason == null) return;
      blockedReason =
          reason.trim().isNotEmpty ? reason.trim() : '관리자에 의해 삭제되었습니다.';
    }

    try {
      await _service.setVisibility(
        postId: post.id,
        visible: false,
        blockedReason: blockedReason,
        deletedByAdmin: requiresReason,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('게시글을 삭제했어요.')),
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('삭제에 실패했습니다: ${error.message}')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('삭제에 실패했습니다: $error')),
      );
    }
  }

  Future<String?> _showDeleteReasonDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('삭제 사유 입력'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: '삭제 사유를 입력해 주세요.',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result;
  }

  Future<void> _handleCompose() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인 후 글쓰기가 가능합니다.')),
      );
      return;
    }

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: CommunityPostComposer(
          onSubmit: (category, title, content) => _service.createPost(
            category: category,
            title: title,
            content: content,
            author: user,
          ),
        ),
      ),
    );

    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('게시글을 등록했어요.')),
      );
    }
  }

  void _openListPage({String? category}) {
    context.push('/community/list', extra: category);
  }

  void _openPostDetail(CommunityPost post) {
    context.push('/community/posts/${post.id}', extra: post);
  }

  @override
  void initState() {
    super.initState();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      setState(() {
        _currentUserId = user?.uid;
        _isAdmin = false;
      });
      if (user == null) {
        return;
      }
      _loadUserRole(user);
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
          tooltip: '새로고침',
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.onCompose, required this.onShowAll});

  final VoidCallback onCompose;
  final VoidCallback onShowAll;

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
                  onPressed: onCompose,
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
                  onPressed: onShowAll,
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

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.categories,
    required this.selectedCategory,
    required this.onSelected,
  });

  final List<_BoardCategory> categories;
  final String? selectedCategory;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('게시판 카테고리'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final category in categories)
              _CategoryCard(
                category: category,
                selected: category.name == selectedCategory ||
                    (category.name == '전체' && selectedCategory == null),
                onTap: () => onSelected(
                  category.name == '전체' ? null : category.name,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final _BoardCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? AppColors.mint : const Color(0xFFE9E9EC),
                width: selected ? 1.2 : 1,
              ),
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
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.subtext),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PopularSection extends StatelessWidget {
  const _PopularSection({
    required this.service,
    this.currentUserId,
    this.isAdmin = false,
    this.onEdit,
    this.onDelete,
    this.onOpen,
  });

  final CommunityPostService service;
  final String? currentUserId;
  final bool isAdmin;
  final ValueChanged<CommunityPost>? onEdit;
  final ValueChanged<CommunityPost>? onDelete;
  final ValueChanged<CommunityPost>? onOpen;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CommunityPost>>(
      stream: service.watchPopularPosts(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || (snapshot.data?.isEmpty ?? true)) {
          return const SizedBox.shrink();
        }

        final posts = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle('실시간 인기 글'),
            const SizedBox(height: 12),
            ...posts.map((post) {
              final isAuthor =
                  currentUserId != null && currentUserId == post.authorId;
              final canDelete = isAdmin || isAuthor;
              return _PopularPostCard(
                post: post,
                canEdit: isAuthor,
                canDelete: canDelete,
                onEdit: onEdit == null ? null : () => onEdit!(post),
                onDelete: onDelete == null ? null : () => onDelete!(post),
                onTap: onOpen == null ? null : () => onOpen!(post),
              );
            }),
          ],
        );
      },
    );
  }
}

class _PopularPostCard extends StatelessWidget {
  const _PopularPostCard({
    required this.post,
    this.canEdit = false,
    this.canDelete = false,
    this.onEdit,
    this.onDelete,
    this.onTap,
  });

  final CommunityPost post;
  final bool canEdit;
  final bool canDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE9E9EC)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                  post.authorName,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.subtext,
                  ),
                ),
                if (canEdit || canDelete) ...[
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    tooltip: '게시글 옵션',
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          onEdit?.call();
                          break;
                        case 'delete':
                          onDelete?.call();
                          break;
                      }
                    },
                    itemBuilder: (context) {
                      return [
                        if (canEdit)
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('수정'),
                          ),
                        if (canDelete)
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('삭제'),
                          ),
                      ];
                    },
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Text(
              post.title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _StatChip(
                  icon: Icons.chat_bubble_outline,
                  label: '${post.commentCount}',
                ),
                const SizedBox(width: 10),
                _StatChip(
                  icon: Icons.thumb_up_alt_outlined,
                  label: '${post.likeCount}',
                ),
                const SizedBox(width: 10),
                _StatChip(
                  icon: Icons.access_time,
                  label: _formatTimestamp(post.createdAt),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PostPreviewCard extends StatelessWidget {
  const _PostPreviewCard({
    required this.post,
    this.canEdit = false,
    this.canDelete = false,
    this.onEdit,
    this.onDelete,
    this.onTap,
  });

  final CommunityPost post;
  final bool canEdit;
  final bool canDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                  post.authorName,
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.subtext),
                ),
                if (canEdit || canDelete) ...[
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    tooltip: '게시글 옵션',
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          onEdit?.call();
                          break;
                        case 'delete':
                          onDelete?.call();
                          break;
                      }
                    },
                    itemBuilder: (context) {
                      return [
                        if (canEdit)
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('수정'),
                          ),
                        if (canDelete)
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('삭제'),
                          ),
                      ];
                    },
                  ),
                ],
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
                  icon: Icons.chat_bubble_outline,
                  label: '${post.commentCount}',
                ),
                const SizedBox(width: 10),
                _StatChip(
                  icon: Icons.thumb_up_alt_outlined,
                  label: '${post.likeCount}',
                ),
                const SizedBox(width: 10),
                _StatChip(
                  icon: Icons.access_time,
                  label: _formatTimestamp(post.createdAt),
                ),
              ],
            ),
          ],
        ),
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

class _GuideCard extends StatelessWidget {
  const _GuideCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.flag_outlined, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  '신고 및 커뮤니티 가이드',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '게시글·댓글 신고가 접수되면 운영진이 즉시 검토해 안전한 커뮤니티를 유지합니다.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {},
            child: const Text('가이드 보기'),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _EmptyPostsView extends StatelessWidget {
  const _EmptyPostsView();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
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
        children: const [
          Icon(Icons.forum_outlined, size: 40, color: AppColors.subtext),
          SizedBox(height: 12),
          Text(
            '아직 게시글이 없습니다.',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 4),
          Text(
            '첫 번째 글을 남겨 커뮤니티를 채워 주세요!',
            style: TextStyle(color: AppColors.subtext),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 40, color: Colors.redAccent),
            const SizedBox(height: 12),
            const Text('게시글을 불러오지 못했습니다.'),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(
                '$error',
                style: const TextStyle(color: AppColors.subtext, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _formatTimestamp(DateTime? time) {
  if (time == null) {
    return '방금 전';
  }
  final now = DateTime.now();
  final diff = now.difference(time);
  if (diff.inMinutes < 1) {
    return '방금 전';
  }
  if (diff.inHours < 1) {
    return '${diff.inMinutes}분 전';
  }
  if (diff.inDays < 1) {
    return '${diff.inHours}시간 전';
  }
  if (diff.inDays < 7) {
    return '${diff.inDays}일 전';
  }
  final month = time.month.toString().padLeft(2, '0');
  final day = time.day.toString().padLeft(2, '0');
  return '${time.year}.$month.$day';
}

class CommunityPostComposer extends StatefulWidget {
  const CommunityPostComposer({
    required this.onSubmit,
    this.initialCategory,
    this.initialTitle,
    this.initialContent,
    this.submitLabel,
    super.key,
  });

  final Future<void> Function(String category, String title, String content)
      onSubmit;
  final String? initialCategory;
  final String? initialTitle;
  final String? initialContent;
  final String? submitLabel;

  @override
  State<CommunityPostComposer> createState() => _CommunityPostComposerState();
}

class _CommunityPostComposerState extends State<CommunityPostComposer> {
  final _formKey = GlobalKey<FormState>();
  late String _category;
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _category = communityCategories.first;
    if (widget.initialCategory != null &&
        communityCategories.contains(widget.initialCategory)) {
      _category = widget.initialCategory!;
    }
    if (widget.initialTitle != null) {
      _titleController.text = widget.initialTitle!;
    }
    if (widget.initialContent != null) {
      _contentController.text = widget.initialContent!;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing =
        widget.initialTitle != null || widget.initialContent != null;
    final submitLabel = widget.submitLabel ?? (isEditing ? '수정하기' : '등록하기');
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  isEditing ? '게시글 수정' : '새 글 작성',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _submitting
                      ? null
                      : () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _category,
              items: [
                for (final item in communityCategories)
                  DropdownMenuItem(value: item, child: Text(item)),
              ],
              onChanged: _submitting
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() => _category = value);
                      }
                    },
              decoration: const InputDecoration(
                labelText: '카테고리',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _titleController,
              enabled: !_submitting,
              decoration: const InputDecoration(
                labelText: '제목',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '제목을 입력해 주세요.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _contentController,
              enabled: !_submitting,
              decoration: const InputDecoration(
                labelText: '내용',
                border: OutlineInputBorder(),
              ),
              minLines: 5,
              maxLines: 8,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '내용을 입력해 주세요.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitting ? null : _handleSubmit,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(submitLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    setState(() => _submitting = true);
    try {
      await widget.onSubmit(
        _category,
        _titleController.text.trim(),
        _contentController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on FirebaseException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('등록에 실패했습니다: ${error.message}')),
      );
      setState(() => _submitting = false);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('등록에 실패했습니다: $error')),
      );
      setState(() => _submitting = false);
    }
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

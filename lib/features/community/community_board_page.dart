import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

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

class CommunityBoardPage extends StatefulWidget {
  const CommunityBoardPage({super.key});

  @override
  State<CommunityBoardPage> createState() => _CommunityBoardPageState();
}

class _CommunityBoardPageState extends State<CommunityBoardPage> {
  final CommunityPostService _service = CommunityPostService();
  String? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('커뮤니티 게시판'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '새로고침',
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      backgroundColor: AppColors.bg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _handleCompose,
        icon: const Icon(Icons.edit),
        label: const Text('글쓰기'),
      ),
      body: StreamBuilder<List<CommunityPost>>(
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

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              _CategorySection(
                categories: communityCategories,
                selectedCategory: _selectedCategory,
                onSelected: (value) {
                  setState(() => _selectedCategory = value);
                },
              ),
              const SizedBox(height: 24),
              _PopularSection(service: _service),
              const SizedBox(height: 24),
              if (posts.isEmpty)
                const _EmptyPostsView()
              else ...[
                const _SectionTitle('최신 글'),
                const SizedBox(height: 12),
                ...posts.map((post) => _PostCard(post: post)),
              ],
              const SizedBox(height: 32),
              const _GuideCard(),
            ],
          );
        },
      ),
    );
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
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.categories,
    required this.selectedCategory,
    required this.onSelected,
  });

  final List<String> categories;
  final String? selectedCategory;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('게시판 카테고리'),
        const SizedBox(height: 12),
        _CategoryGrid(
          categories: categories,
          selectedCategory: selectedCategory,
          onSelected: onSelected,
        ),
      ],
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({
    required this.categories,
    required this.selectedCategory,
    required this.onSelected,
  });

  final List<String> categories;
  final String? selectedCategory;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final options = ['전체', ...categories];
    return LayoutBuilder(
      builder: (context, constraints) {
        const minWidth = 140.0;
        final maxWidth = constraints.maxWidth;
        final count = math.max(1, (maxWidth / minWidth).floor());
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: options.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count,
            mainAxisExtent: 48,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
          ),
          itemBuilder: (context, index) {
            final option = options[index];
            final bool isAll = option == '전체';
            final bool selected =
                isAll ? selectedCategory == null : selectedCategory == option;
            return _CategoryChip(
              label: option,
              selected: selected,
              onTap: () => onSelected(isAll ? null : option),
            );
          },
        );
      },
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: selected ? AppColors.mint.withOpacity(0.15) : Colors.white,
            border: Border.all(
              color: selected ? AppColors.mint : const Color(0xFFE1E1E5),
            ),
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.text : AppColors.subtext,
            ),
          ),
        ),
      ),
    );
  }
}

class _PopularSection extends StatelessWidget {
  const _PopularSection({required this.service});

  final CommunityPostService service;

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
            const _SectionTitle('실시간 인기글'),
            const SizedBox(height: 12),
            ...posts.map((post) => _PopularTile(post: post)),
          ],
        );
      },
    );
  }
}

class _PopularTile extends StatelessWidget {
  const _PopularTile({required this.post});

  final CommunityPost post;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.local_fire_department,
              color: Colors.orange.shade400, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${post.category} · ${_formatTimestamp(post.createdAt)}',
                  style:
                      const TextStyle(color: AppColors.subtext, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post});

  final CommunityPost post;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4FF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  post.category,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.subtext,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                _formatTimestamp(post.createdAt),
                style: const TextStyle(fontSize: 12, color: AppColors.subtext),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            post.title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            post.content,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, color: AppColors.text),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                post.authorName,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.subtext,
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.chat_bubble_outline,
                  size: 16, color: AppColors.subtext),
              const SizedBox(width: 4),
              Text('${post.commentCount}',
                  style: const TextStyle(color: AppColors.subtext)),
              const SizedBox(width: 12),
              const Icon(Icons.favorite_border,
                  size: 16, color: AppColors.subtext),
              const SizedBox(width: 4),
              Text('${post.likeCount}',
                  style: const TextStyle(color: AppColors.subtext)),
            ],
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
      padding: const EdgeInsets.all(20),
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
        children: const [
          Text(
            '신고 및 커뮤니티 가이드',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 12),
          _GuideItem('개인정보 노출, 욕설 등의 부적절한 게시물은 신고 버튼으로 알려주세요.'),
          _GuideItem('허위 정보 및 광고는 예고 없이 삭제될 수 있습니다.'),
          _GuideItem('서로를 존중하는 따뜻한 커뮤니티 문화를 만들어 주세요.'),
        ],
      ),
    );
  }
}

class _GuideItem extends StatelessWidget {
  const _GuideItem(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: AppColors.subtext)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppColors.subtext),
            ),
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
  const CommunityPostComposer({required this.onSubmit, super.key});

  final Future<void> Function(String category, String title, String content)
      onSubmit;

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
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                const Text(
                  '새 글 작성',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
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
                    : const Text('등록하기'),
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

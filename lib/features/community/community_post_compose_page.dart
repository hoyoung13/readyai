import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../tabs/tabs_shared.dart';
import 'community_post_composer.dart';

class CommunityPostComposeArgs {
  CommunityPostComposeArgs({
    required this.onSubmit,
    this.isAdmin = false,
    this.title,
    this.initialCategory,
    this.initialTitle,
    this.initialContent,
    this.submitLabel,
  });

  final Future<void> Function(String category, String title, String content)
      onSubmit;
  final bool isAdmin;
  final String? title;
  final String? initialCategory;
  final String? initialTitle;
  final String? initialContent;
  final String? submitLabel;
}

class CommunityPostComposePage extends StatelessWidget {
  const CommunityPostComposePage({
    required this.args,
    super.key,
  });

  final CommunityPostComposeArgs args;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(args.title ?? '새 글 작성'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(false),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: CommunityPostComposer(
                  onSubmit: args.onSubmit,
                  allowNotice: args.isAdmin,
                  initialCategory: args.initialCategory,
                  initialTitle: args.initialTitle,
                  initialContent: args.initialContent,
                  submitLabel: args.submitLabel,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

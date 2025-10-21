import 'package:flutter/material.dart';
import 'package:ai/features/camera/interview_flow_launcher.dart';
import 'package:ai/features/camera/interview_models.dart';
import 'package:ai/features/camera/interview_question_bank.dart';
import 'tabs_shared.dart';

class CameraTab extends StatelessWidget {
  const CameraTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: IconButton(
              onPressed: () => _handleStartInterview(context),
              iconSize: 42,
              icon: const Icon(Icons.photo_camera),
            ),
          ),
          const SizedBox(height: 12),
          const Text('AI 면접 시작', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text(
            '카테고리와 면접 유형을 선택해 주세요.',
            style: TextStyle(color: AppColors.subtext),
          ),
        ],
      ),
    );
  }
}

Future<void> _handleStartInterview(BuildContext context) async {
  final category = await _showJobCategorySheet(context);
  if (category == null || !context.mounted) return;

  final mode = await _showInterviewModeSheet(context, category);
  if (mode == null || !context.mounted) return;
  final questions = InterviewQuestionBank.getQuestions(
    category: category,
    mode: mode,
  );
  await const InterviewFlowLauncher().launch(
    context: context,
    category: category,
    mode: mode,
    questions: questions,
  );
}

Future<JobCategory?> _showJobCategorySheet(BuildContext context) {
  return showModalBottomSheet<JobCategory>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) {
      JobCategory? selected;
      return StatefulBuilder(
        builder: (context, setState) {
          return SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '연결 카테고리 선택',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '분야를 선택하면 카메라 화면으로 넘어갑니다.',
                    style: TextStyle(color: AppColors.subtext, fontSize: 13),
                  ),
                  const SizedBox(height: 22),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _jobCategories.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.6,
                    ),
                    itemBuilder: (context, index) {
                      final category = _jobCategories[index];
                      return _SelectableCard(
                        title: category.title,
                        subtitle: category.subtitle,
                        isSelected: selected == category,
                        onTap: () => setState(() => selected = category),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.mint,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: selected == null
                          ? null
                          : () => Navigator.of(context).pop(selected),
                      child: const Text('선택하고 계속 (카메라)'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

Future<InterviewMode?> _showInterviewModeSheet(
  BuildContext context,
  JobCategory category,
) {
  return showModalBottomSheet<InterviewMode>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '선택: ${category.title}',
                style: const TextStyle(color: AppColors.subtext, fontSize: 13),
              ),
              const SizedBox(height: 4),
              const Text(
                '면접 유형 선택',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 16),
              ...InterviewMode.values.map(
                (mode) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _SelectableCard(
                    title: mode.title,
                    subtitle: mode.description,
                    isSelected: false,
                    onTap: () => Navigator.of(context).pop(mode),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

const _jobCategories = [
  JobCategory(title: 'IT · 소프트웨어', subtitle: '웹/앱/데이터'),
  JobCategory(title: '모바일 앱', subtitle: 'Android/iOS'),
  JobCategory(title: '웹 프론트엔드', subtitle: 'React/Vue'),
  JobCategory(title: '백엔드/서버', subtitle: 'Node/Java/Spring'),
  JobCategory(title: '데이터/AI', subtitle: '분석/머신러닝'),
  JobCategory(title: '클라우드/DevOps', subtitle: 'AWS/GCP/K8s'),
  JobCategory(title: '보안(Security)', subtitle: 'Sec/Infra'),
  JobCategory(title: '금융/핀테크', subtitle: '뱅킹/결제'),
  JobCategory(title: '서비스/플랫폼', subtitle: 'UX/서비스기획'),
  JobCategory(title: '디자인/UX', subtitle: 'UI/UX/Product'),
  JobCategory(title: '제조/품질', subtitle: '생산/SCM'),
  JobCategory(title: '공공/공기업', subtitle: '정책/행정'),
];

class _SelectableCard extends StatelessWidget {
  const _SelectableCard({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected ? AppColors.mint : const Color(0xFFE5E5EA);
    final background =
        isSelected ? AppColors.mint.withOpacity(0.15) : Colors.white;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12.5, color: AppColors.subtext),
            ),
          ],
        ),
      ),
    );
  }
}

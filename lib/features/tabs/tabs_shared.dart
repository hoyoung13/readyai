import 'package:flutter/material.dart';

/// 앱 공통 컬러
class AppColors {
  static const bg = Color(0xFFF7F7F7);
  static const mint = Color(0xFF2EE8A5);
  static const text = Color(0xFF191919);
  static const subtext = Color(0xFF7C7C7C);
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            height: 1.2,
          ),
        ),
        const Spacer(),
        TextButton(
          onPressed: () {},
          child: const Text('전체보기'),
        ),
      ],
    );
  }
}

class JobMiniCard extends StatelessWidget {
  const JobMiniCard({
    required this.title,
    required this.company,
    required this.tag,
    super.key,
  });

  final String title;
  final String company;
  final String tag;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 6),
          )
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          const CircleAvatar(radius: 18, backgroundColor: Color(0xFFE9E9EC)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$company · $tag',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.subtext,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.chevron_right),
          )
        ],
      ),
    );
  }
}

class ProfileTile extends StatelessWidget {
  const ProfileTile({
    required this.icon,
    required this.title,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

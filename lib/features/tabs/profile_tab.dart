import 'package:flutter/material.dart';

import 'tabs_shared.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      children: [
        Row(
          children: const [
            CircleAvatar(radius: 24, backgroundColor: Color(0xFFE9E9EC)),
            SizedBox(width: 12),
            Text(
              '홍길동',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ProfileTile(
          icon: Icons.description_outlined,
          title: '이력서 업로드',
          onTap: () {},
        ),
        ProfileTile(
          icon: Icons.public_outlined,
          title: '이력서 공개 설정',
          onTap: () {},
        ),
        ProfileTile(icon: Icons.logout, title: '로그아웃', onTap: () {}),
      ],
    );
  }
}

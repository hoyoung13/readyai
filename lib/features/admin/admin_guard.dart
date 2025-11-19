/// 사용자 역할을 확인해 관리자 전용 페이지 접근을 제한하는 라우트 가드 위젯.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/router/app_router.dart';

class AdminRouteGuard extends StatelessWidget {
  const AdminRouteGuard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cachedRole = userRoleCache.value;
    if (cachedRole == 'admin') {
      return child;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return _AdminError(message: '관리자 로그인이 필요합니다.');
    }

    final docRef =
        FirebaseFirestore.instance.collection('users').doc(currentUser.uid);

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: docRef.get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final data = snapshot.data?.data();
        final role = data?['role'] as String?;
        if (role == 'admin') {
          userRoleCache.value = 'admin';
          return child;
        }

        return const _AdminError(
          message: '관리자 전용 페이지입니다. 접근 권한이 없습니다.',
        );
      },
    );
  }
}

class _AdminError extends StatelessWidget {
  const _AdminError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('접근 제한')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.block, size: 56, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

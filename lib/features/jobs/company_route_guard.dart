import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/utils/role_utils.dart';
import '../../core/router/app_router.dart';

class CompanyRouteGuard extends StatelessWidget {
  const CompanyRouteGuard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cached = userRoleCache.value;
    if (isCompanyRole(cached)) {
      return child;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const _CompanyGuardError(message: '기업 계정으로 로그인해 주세요.');
    }

    final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: docRef.get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final role = snapshot.data?.data()?['role'] as String?;
        if (isCompanyRole(role)) {
          userRoleCache.value = normalizeRole(role);
          return child;
        }

        return const _CompanyGuardError(
          message: '기업 전용 페이지입니다. 접근 권한이 없습니다.',
        );
      },
    );
  }
}

class _CompanyGuardError extends StatelessWidget {
  const _CompanyGuardError({required this.message});

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
              const Icon(Icons.lock_outline, size: 56, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(
                message,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

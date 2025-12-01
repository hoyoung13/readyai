import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:firebase_auth/firebase_auth.dart'; // ✅ 추가
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ai/core/router/app_router.dart';
import 'package:ai/core/utils/role_utils.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _idCtl = TextEditingController(); // 이메일(아이디)
  final _pwCtl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _idCtl.dispose();
    _pwCtl.dispose();
    super.dispose();
  }

  void _msg(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _emailLogin() async {
    final email = _idCtl.text.trim().toLowerCase();
    final pw = _pwCtl.text;

    if (email.isEmpty || pw.isEmpty) {
      _msg('아이디/비밀번호를 입력하세요.');
      return;
    }

    setState(() => _loading = true);
    try {
      // ✅ Firebase Auth 이메일/비밀번호 로그인
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: pw,
      );
      final uid = cred.user!.uid;
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = userDoc.data();
      final role = normalizeRole((data?['role'] as String?) ?? 'user');

      final bool isApproved =
          isCompanyRole(role) ? (data?['isApproved'] == true) : true;

      if (!isApproved) {
        await FirebaseAuth.instance.signOut();
        userRoleCache.value = null;
        _msg('관리자 승인 후 이용할 수 있습니다.');
        return;
      }

      userRoleCache.value = role;

      if (mounted) {
        if (role == 'admin') {
          context.go('/admin');
        } else if (isCompanyRole(role)) {
          context.go('/company');
        } else {
          context.go('/tabs');
        }
      }
    } on FirebaseAuthException catch (e) {
      String human = '로그인에 실패했어요.';
      switch (e.code) {
        case 'invalid-email':
          human = '이메일 형식이 올바르지 않아요.';
          break;
        case 'user-not-found':
          human = '존재하지 않는 계정이에요.';
          break;
        case 'wrong-password':
          human = '비밀번호가 일치하지 않아요.';
          break;
        case 'user-disabled':
          human = '비활성화된 계정이에요.';
          break;
      }
      _msg(human);
    } catch (_) {
      _msg('네트워크 또는 알 수 없는 오류입니다.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _kakaoLogin() async {
    try {
      setState(() => _loading = true);

      final installed = await isKakaoTalkInstalled();
      if (installed) {
        await UserApi.instance.loginWithKakaoTalk();
      } else {
        await UserApi.instance.loginWithKakaoAccount();
      }

      // ⚠️ 참고: Kakao로 Firebase에 로그인하려면 서버에서 커스텀 토큰 발급이 필요합니다.
      // 지금은 Kakao만 성공 시 바로 이동(임시).
      if (mounted) context.go('/tabs');
    } catch (e) {
      _msg('카카오 로그인에 실패했어요. 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const mint = Color(0xFF2EE8A5); // 로그인 버튼 색
    const kakao = Color(0xFFFEE500); // 카카오 버튼 색
    const borderRadius = 16.0;

    InputDecoration inputStyle(String hint) => InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            borderSide: const BorderSide(color: Color(0xFFBABABA)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            borderSide: const BorderSide(color: Color(0xFF7C7C7C), width: 1.2),
          ),
        );

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: AbsorbPointer(
          absorbing: _loading,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    // 상단 타이틀
                    const Text(
                      '면접을 도와주는\n ReadyAI',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 중앙 로고 (assets/logo.png 사용)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset(
                        'assets/login.png',
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 아이디 / 비밀번호 입력
                    TextField(
                      controller: _idCtl,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: inputStyle('아이디(이메일)를 입력하세요'),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _pwCtl,
                      obscureText: true,
                      decoration: inputStyle('비밀번호를 입력하세요'),
                      onSubmitted: (_) => _emailLogin(), // 엔터로 로그인
                    ),
                    const SizedBox(height: 18),

                    // 로그인 버튼 (민트색, 둥근)
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _emailLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: mint,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(borderRadius),
                            side: const BorderSide(
                              color: Color(0xFF2CBF8E),
                              width: 1,
                            ),
                          ),
                        ),
                        child: const Text(
                          '로그인',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 카카오 로그인 버튼 (노란색, 둥근)
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _kakaoLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kakao,
                          foregroundColor: const Color(0xFF191600),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(borderRadius),
                            side: const BorderSide(color: Color(0xFF7C7C7C)),
                          ),
                        ),
                        child: const Text(
                          '카카오 로그인',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 80),

                    // 하단 회원가입 문구
                    GestureDetector(
                      onTap: () => context.go('/signup'),
                      child: const Text(
                        '아이디가 없으신가요? 회원가입',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      // 로딩 인디케이터
      floatingActionButton: _loading
          ? const IgnorePointer(
              child: SizedBox(
                width: 0,
                height: 0,
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          : null,
    );
  }
}

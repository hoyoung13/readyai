import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});
  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _nameCtl = TextEditingController();
  final _emailCtl = TextEditingController(); // 아이디(이메일)
  final _pwCtl = TextEditingController();
  final _nickCtl = TextEditingController();

  DateTime? _birthDate;

  bool _loading = false;
  bool? _emailOk; // true=사용가능, false=중복, null=미확인
  bool? _nickOk;

  @override
  void dispose() {
    _nameCtl.dispose();
    _emailCtl.dispose();
    _pwCtl.dispose();
    _nickCtl.dispose();
    super.dispose();
  }

  void _msg(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  InputDecoration _input(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFBABABA)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF7C7C7C), width: 1.2),
        ),
      );

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 20, 1, 1),
      firstDate: DateTime(1950, 1, 1),
      lastDate: now,
      helpText: '생년월일 선택',
      cancelText: '취소',
      confirmText: '확인',
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _checkEmailDup() async {
    final email = _emailCtl.text.trim().toLowerCase();
    if (email.isEmpty) return _msg('아이디(이메일)를 입력하세요.');
    setState(() => _loading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('usernames')
          .doc(email)
          .get();
      setState(() => _emailOk = !doc.exists);
      _msg(doc.exists ? '이미 사용 중인 아이디예요.' : '사용 가능한 아이디예요.');
    } catch (_) {
      _msg('아이디 확인 중 오류가 발생했어요.');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _checkNickDup() async {
    final nickname = _nickCtl.text.trim();
    if (nickname.isEmpty) return _msg('닉네임을 입력하세요.');
    setState(() => _loading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('nicknames')
          .doc(nickname)
          .get();
      setState(() => _nickOk = !doc.exists);
      _msg(doc.exists ? '이미 사용 중인 닉네임이에요.' : '사용 가능한 닉네임이에요.');
    } catch (_) {
      _msg('닉네임 확인 중 오류가 발생했어요.');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _signup() async {
    final name = _nameCtl.text.trim();
    final email = _emailCtl.text.trim().toLowerCase();
    final pw = _pwCtl.text;
    final nickname = _nickCtl.text.trim();

    if ([name, email, pw, nickname].any((v) => v.isEmpty) ||
        _birthDate == null) {
      return _msg('모든 항목을 입력/선택하세요.');
    }
    if (_emailOk == false || _nickOk == false) {
      return _msg('아이디/닉네임 중복을 확인해주세요.');
    }

    setState(() => _loading = true);
    try {
      // 1) Auth 사용자 생성
      final cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: pw);
      final uid = cred.user!.uid;

      final db = FirebaseFirestore.instance;

      // 2) usernames / nicknames 예약 + 3) users/{uid} 프로필 저장 (트랜잭션)
      await db.runTransaction((tx) async {
        final uRef = db.collection('usernames').doc(email);
        final nRef = db.collection('nicknames').doc(nickname);
        final userRef = db.collection('users').doc(uid);

        if ((await tx.get(uRef)).exists) {
          throw Exception('아이디가 이미 예약되었습니다.');
        }
        if ((await tx.get(nRef)).exists) {
          throw Exception('닉네임이 이미 예약되었습니다.');
        }

        tx.set(uRef, {'uid': uid, 'at': FieldValue.serverTimestamp()});
        tx.set(nRef, {'uid': uid, 'at': FieldValue.serverTimestamp()});
        tx.set(userRef, {
          'name': name,
          'birthDate': Timestamp.fromDate(_birthDate!), // YYYY-MM-DD 전체 저장
          'birthDateStr': _birthDate!.toIso8601String().split('T').first,
          'email': email,
          'nickname': nickname,
          'resumePublic': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      _msg('회원가입이 완료되었습니다.');
      if (mounted) context.go('/login'); // 가입tjdrhd 로그인 화면 이동
    } on FirebaseAuthException catch (e) {
      _msg(e.message ?? '회원가입 실패');
    } catch (e) {
      _msg('회원가입 중 오류가 발생했어요.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _rowWithCheck({
    required TextEditingController controller,
    required String hint,
    required VoidCallback onCheck,
    bool? ok,
    TextInputType? keyboardType,
    bool obscure = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            obscureText: obscure,
            keyboardType: keyboardType,
            decoration: _input(hint).copyWith(
              suffixIcon: ok == null
                  ? null
                  : Icon(ok ? Icons.check_circle : Icons.error,
                      color: ok ? Colors.green : Colors.red),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 52,
          child: OutlinedButton(
            onPressed: onCheck,
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text('중복확인'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    const mint = Color(0xFF2EE8A5);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(title: const Text('회원가입')),
      body: SafeArea(
        child: AbsorbPointer(
          absorbing: _loading,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Column(
                  children: [
                    // 이름
                    TextField(
                      controller: _nameCtl,
                      decoration: _input('이름'),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),

                    // 생년월일 (DatePicker)
                    InkWell(
                      onTap: _pickBirthDate,
                      child: InputDecorator(
                        decoration: _input('생년월일 (YYYY-MM-DD)'),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _birthDate == null
                                  ? '날짜를 선택하세요'
                                  : _birthDate!
                                      .toIso8601String()
                                      .split('T')
                                      .first,
                              style: TextStyle(
                                fontSize: 16,
                                color: _birthDate == null
                                    ? Colors.black54
                                    : Colors.black,
                              ),
                            ),
                            const Icon(Icons.calendar_today_outlined, size: 18),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 아이디(이메일) + 중복확인
                    _rowWithCheck(
                      controller: _emailCtl,
                      hint: '아이디 (이메일 형식 권장)',
                      keyboardType: TextInputType.emailAddress,
                      onCheck: _checkEmailDup,
                      ok: _emailOk,
                    ),
                    const SizedBox(height: 14),

                    // 비밀번호
                    TextField(
                      controller: _pwCtl,
                      obscureText: true,
                      decoration: _input('비밀번호'),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),

                    // 닉네임 + 중복확인
                    _rowWithCheck(
                      controller: _nickCtl,
                      hint: '닉네임',
                      onCheck: _checkNickDup,
                      ok: _nickOk,
                    ),
                    const SizedBox(height: 24),

                    // 회원가입 버튼
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _signup,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: mint,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(
                                color: Color(0xFF2CBF8E), width: 1),
                          ),
                        ),
                        child: const Text(
                          '회원가입',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextButton(
                      onPressed: () => context.go('/'),
                      child: const Text('이미 계정이 있으신가요? 로그인'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: _loading ? const CircularProgressIndicator() : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

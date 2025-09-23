import 'package:go_router/go_router.dart';
import 'package:ai/features/auth/login_page.dart';
import 'package:ai/features/auth/signup_page.dart';
import 'package:ai/features/tabs/tabs_page.dart';

final router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, __) => const LoginPage()),
    GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
    GoRoute(path: '/signup', builder: (_, __) => const SignupPage()),
    GoRoute(path: '/tabs', builder: (_, __) => const TabsPage()),
  ],
);

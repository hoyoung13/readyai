import 'package:flutter/material.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class TheReadyApp extends StatelessWidget {
  const TheReadyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: 'The Ready',
        theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
        routerConfig: router,
      );
}

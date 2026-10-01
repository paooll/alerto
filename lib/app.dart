import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'services/auth_service.dart';
import 'ui/screens/root_shell.dart';
import 'ui/screens/auth_screen.dart';
import 'ui/theme.dart';

class AlertoApp extends ConsumerWidget {
  const AlertoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return MaterialApp(
      title: 'Alerto',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: authState.when(
        data: (user) => user == null ? const AuthScreen() : const RootShell(),
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => const AuthScreen(),
      ),
    );
  }
}

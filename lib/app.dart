import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'services/auth_service.dart';
import 'ui/screens/root_shell.dart';
import 'ui/screens/auth_screen.dart';
import 'ui/theme.dart';

class PriceAlertApp extends ConsumerWidget {
  const PriceAlertApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return MaterialApp(
      title: 'PriceAlert',
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

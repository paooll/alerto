import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/market_providers.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'ui/screens/auth_screen.dart';
import 'ui/screens/instrument_detail_screen.dart';
import 'ui/screens/root_shell.dart';
import 'ui/theme.dart';
import 'ui/widgets/alert_banner.dart';
import 'domain/instrument.dart';

class AlertoApp extends ConsumerStatefulWidget {
  const AlertoApp({super.key});

  @override
  ConsumerState<AlertoApp> createState() => _AlertoAppState();
}

class _AlertoAppState extends ConsumerState<AlertoApp> {
  StreamSubscription<AlertPayload>? _tapSub;
  User? _lastUser;

  @override
  void initState() {
    super.initState();
    _tapSub = NotificationService.tapStream.listen(_onTap);
  }

  Future<void> _onTap(AlertPayload payload) async {
    if (!mounted || payload.symbol == null) return;
    final catalog = await ref.read(catalogProvider.future);
    Instrument? match;
    for (final i in catalog) {
      if (i.symbol == payload.symbol) {
        match = i;
        break;
      }
    }
    if (!mounted) return;
    if (match != null) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => InstrumentDetailScreen(instrument: match!),
      ));
    }
  }

  @override
  void dispose() {
    _tapSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    // Register/unregister the FCM device on auth changes.
    authState.whenData((user) {
      if (user != null && _lastUser?.uid != user.uid) {
        NotificationService.registerForCurrentUser();
      }
      _lastUser = user;
    });

    return MaterialApp(
      title: 'Alerto',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: authState.when(
        data: (user) => user == null
            ? const AuthScreen()
            : AlertBanner(
                onTap: (symbol) =>
                    symbol != null ? _onTap(AlertPayload(type: 'alertTriggered', symbol: symbol)) : null,
                child: const RootShell(),
              ),
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => const AuthScreen(),
      ),
    );
  }
}

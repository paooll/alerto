import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/auth_service.dart';

final currentUserProvider = Provider<User?>((ref) {
  final state = ref.watch(authStateProvider);
  return state.value;
});

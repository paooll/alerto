import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/alert.dart';
import '../services/firestore_service.dart';
import 'auth_provider.dart';

/// Firestore service scoped to the signed-in user.
final firestoreServiceProvider = Provider<FirestoreService?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return FirestoreService(user.uid);
});

/// All alerts of the current user (streamed; no artificial limit).
final alertsProvider = StreamProvider<List<Alert>>((ref) {
  final svc = ref.watch(firestoreServiceProvider);
  if (svc == null) return const Stream.empty();
  return svc.watchAlerts();
});

/// Enabled, unexpired alerts.
final activeAlertsProvider = StreamProvider<List<Alert>>((ref) {
  final svc = ref.watch(firestoreServiceProvider);
  if (svc == null) return const Stream.empty();
  return svc.watchActiveAlerts();
});

/// Alerts grouped by symbol (for instrument detail screens).
final alertsBySymbolProvider =
    StreamProvider.family<List<Alert>, String>((ref, symbol) {
  final svc = ref.watch(firestoreServiceProvider);
  if (svc == null) return const Stream.empty();
  return svc
      .watchAlerts()
      .map((list) => list.where((a) => a.symbol == symbol).toList());
});

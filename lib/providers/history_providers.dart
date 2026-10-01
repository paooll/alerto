import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/alert_history_entry.dart';
import 'alert_providers.dart';

/// Triggered-alert history for the signed-in user (newest first).
final historyProvider = StreamProvider<List<AlertHistoryEntry>>((ref) {
  final svc = ref.watch(firestoreServiceProvider);
  if (svc == null) return const Stream.empty();
  return svc
      .watchHistory()
      .map((snap) => snap.docs
          .map((d) => AlertHistoryEntry.fromMap(d.id, d.data()))
          .toList());
});

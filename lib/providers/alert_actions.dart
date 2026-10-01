import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/alert.dart';
import '../domain/instrument.dart';
import 'alert_providers.dart';
import 'auth_provider.dart';
import 'market_providers.dart';

final _uuidCounter = Random();

String _newId() {
  final ms = DateTime.now().millisecondsSinceEpoch;
  return 'alert_${ms}_${_uuidCounter.nextInt(1 << 32).toRadixString(36)}';
}


/// Creates (persists) a new alert; returns the alert id.
Future<String> createAlert(
  WidgetRef ref, {
  required Instrument instrument,
  required String? name,
  required List<Condition> conditions,
  required Logic logic,
  required AlertMode mode,
  required int cooldownMinutes,
  required bool enabled,
  DateTime? expiresAt,
  double? referencePrice,
}) async {
  final user = ref.read(currentUserProvider);
  final svc = ref.read(firestoreServiceProvider);
  if (user == null || svc == null) {
    throw StateError('Not signed in');
  }
  final alert = Alert(
    id: _newId(),
    userId: user.uid,
    symbol: instrument.symbol,
    displayName: instrument.displayName,
    assetClass: instrument.assetClass,
    name: name,
    conditions: conditions
        .map((c) => referencePrice != null
            ? Condition(
                type: c.type,
                value: c.value,
                value2: c.value2,
                referencePrice: referencePrice)
            : c)
        .toList(),
    logic: logic,
    mode: mode,
    cooldownMinutes: cooldownMinutes,
    enabled: enabled,
    createdAt: DateTime.now().toUtc(),
    expiresAt: expiresAt,
  );
  await svc.createAlert(alert);
  return alert.id;
}

Future<void> toggleAlert(WidgetRef ref, Alert alert, bool enabled) async {
  final svc = ref.read(firestoreServiceProvider);
  if (svc == null) return;
  await svc.setAlertEnabled(alert.id, enabled);
}

Future<void> deleteAlert(WidgetRef ref, Alert alert) async {
  final svc = ref.read(firestoreServiceProvider);
  if (svc == null) return;
  await svc.deleteAlert(alert.id);
}

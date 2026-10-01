import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/alert.dart';
import '../domain/instrument.dart';

/// All Firestore access for the signed-in user.
/// Paths: users/{uid}/alerts, users/{uid}/alertHistory, users/{uid}/devices.
class FirestoreService {
  FirestoreService(this.uid);
  final String uid;

  CollectionReference<Map<String, dynamic>> get _alerts =>
      FirebaseFirestore.instance.collection('users').doc(uid).collection('alerts');

  CollectionReference<Map<String, dynamic>> get _history =>
      FirebaseFirestore.instance.collection('users').doc(uid).collection('alertHistory');

  CollectionReference<Map<String, dynamic>> get _devices =>
      FirebaseFirestore.instance.collection('users').doc(uid).collection('devices');

  // ---------- Alerts ----------

  /// No artificial limit: stream all alerts for the user.
  Stream<List<Alert>> watchAlerts() => _alerts
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => Alert.fromMap(d.id, d.data())).toList());

  Stream<List<Alert>> watchActiveAlerts() => watchAlerts().map((list) =>
      list.where((a) => a.enabled && !a.isExpired).toList());

  Future<void> createAlert(Alert alert) =>
      _alerts.doc(alert.id).set(alert.toMap());

  Future<void> updateAlert(Alert alert) =>
      _alerts.doc(alert.id).update(alert.toMap());

  Future<void> setAlertEnabled(String id, bool enabled) =>
      _alerts.doc(id).update({'enabled': enabled});

  Future<void> deleteAlert(String id) => _alerts.doc(id).delete();

  // ---------- History ----------

  Stream<QuerySnapshot<Map<String, dynamic>>> watchHistory({int limit = 200}) =>
      _history.orderBy('triggeredAt', descending: true).limit(limit).snapshots();

  Future<void> deleteHistoryEntry(String id) => _history.doc(id).delete();

  // ---------- Devices (FCM tokens) ----------

  Future<void> registerDevice(String token, {String? platform}) =>
      _devices.doc(token).set({
        'token': token,
        'platform': platform ?? _platformName(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  Future<void> removeDevice(String token) => _devices.doc(token).delete();

  // ---------- Settings ----------

  Future<void> updateSettings(Map<String, dynamic> data) => FirebaseFirestore
      .instance
      .collection('users')
      .doc(uid)
      .set(data, SetOptions(merge: true));
}

String _platformName() {
  if (Platform.isAndroid) return 'android';
  if (Platform.isIOS) return 'ios';
  return 'other';
}

// ---------- Instruments catalog cache (client-side convenience) ----------

class CatalogRepository {
  CatalogRepository(this._load);
  final Future<List<Instrument>> Function() _load;

  List<Instrument>? _cache;

  Future<List<Instrument>> all() async {
    if (_cache != null) return _cache!;
    return _cache = await _load();
  }

  List<Instrument> searchLocal(String query, List<Instrument> catalog) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return catalog;
    return catalog
        .where((i) =>
            i.symbol.toLowerCase().contains(q) ||
            i.displayName.toLowerCase().contains(q))
        .toList();
  }
}

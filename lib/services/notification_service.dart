import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'firestore_service.dart';

/// Payload keys sent by the backend's FCM dispatch.
class AlertPayload {
  const AlertPayload({this.type, this.symbol, this.price});

  factory AlertPayload.fromMap(Map<String, dynamic> data) => AlertPayload(
        type: data['type'] as String?,
        symbol: data['symbol'] as String?,
        price: double.tryParse('${data['price'] ?? ''}'),
      );

  final String? type;
  final String? symbol;
  final double? price;

  bool get isAlertTriggered => type == 'alertTriggered';
}

/// An in-app (foreground) notification event.
class ForegroundNotification {
  const ForegroundNotification(this.title, this.body, this.payload);
  final String title;
  final String body;
  final AlertPayload payload;
}

/// Requests notification permission, keeps the FCM token registered under
/// users/{uid}/devices, and exposes foreground messages + notification taps
/// as streams. Background/terminated delivery is handled by the OS from the
/// same FCM message shape the backend sends.
class NotificationService {
  static final StreamController<ForegroundNotification> _foreground =
      StreamController.broadcast();
  static final StreamController<AlertPayload> _taps =
      StreamController.broadcast();

  static Stream<ForegroundNotification> get foregroundStream => _foreground.stream;
  static Stream<AlertPayload> get tapStream => _taps.stream;

  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final messaging = FirebaseMessaging.instance;

    await messaging.requestPermission(
      alert: true, badge: true, sound: true, provisional: false,
    );

    // App in foreground: FCM does NOT show a system banner, so surface it
    // through the stream (the app renders an in-app banner).
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final n = message.notification;
      if (n == null) return;
      _foreground.add(ForegroundNotification(
        n.title ?? 'Alerto',
        n.body ?? '',
        AlertPayload.fromMap(message.data),
      ));
    });

    // User tapped a notification that opened the app from background.
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _taps.add(AlertPayload.fromMap(message.data));
    });

    // App was terminated and opened by tapping the notification.
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      _taps.add(AlertPayload.fromMap(initial.data));
    }

    // Keep the token fresh in Firestore when it rotates.
    messaging.onTokenRefresh.listen(_registerToken);
    await _registerToken(await messaging.getToken());
  }

  static Future<void> _registerToken(String? token) async {
    if (token == null) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return; // registered after sign-in instead
    await FirestoreService(user.uid).registerDevice(token);
  }

  /// Call right after sign-in or when auth state becomes signed-in.
  static Future<void> registerForCurrentUser() async {
    final messaging = FirebaseMessaging.instance;
    final token = await messaging.getToken();
    await _registerToken(token);
    await messaging.setAutoInitEnabled(true);
  }

  /// Called on sign-out so the backend stops targeting this device.
  static Future<void> unregisterForCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    final token = await FirebaseMessaging.instance.getToken();
    if (user != null && token != null) {
      await FirestoreService(user.uid).removeDevice(token);
    }
  }
}

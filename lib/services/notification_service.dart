import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'firestore_service.dart';

/// Requests notification permission and keeps the FCM token registered
/// under users/{uid}/devices for the Cloud Functions to target.
class NotificationService {
  static Future<void> init() async {
    final messaging = FirebaseMessaging.instance;

    await messaging.requestPermission(
      alert: true, badge: true, sound: true, provisional: false,
    );

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // Foreground: show an in-app banner (system tray is handled by FCM
      // when the app is backgrounded/terminated).
      final n = message.notification;
      if (n != null) {
        _showForeground(n.title ?? 'Price alert', n.body ?? '');
      }
    });

    messaging.onTokenRefresh.listen(_registerToken);
    await _registerToken(await messaging.getToken());
  }

  static Future<void> _registerToken(String? token) async {
    if (token == null) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return; // registered after sign-in instead
    await FirestoreService(user.uid).registerDevice(token);
  }

  /// Call right after sign-in / app start with a user.
  static Future<void> registerForCurrentUser() async {
    final messaging = FirebaseMessaging.instance;
    final token = await messaging.getToken();
    await _registerToken(token);
    // Ensure the subscription topics exist per-user if we later switch
    // from direct token sends to topics.
  }

  static final List<void Function(String title, String body)> _listeners = [];

  static void addForegroundListener(void Function(String, String) fn) =>
      _listeners.add(fn);

  static void _showForeground(String title, String body) {
    for (final fn in _listeners) {
      fn(title, body);
    }
  }
}

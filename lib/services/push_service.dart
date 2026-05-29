import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'auth_service.dart';
import 'chat_service.dart';

/// Android FCM 注册（需 google-services.json）
class PushService {
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized || kIsWeb || !Platform.isAndroid) return;
    try {
      await Firebase.initializeApp();
      _initialized = true;
      FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
      await FirebaseMessaging.instance.requestPermission();
    } catch (e) {
      debugPrint('PushService init skipped: $e');
    }
  }

  static Future<void> registerIfLoggedIn(AuthSession? session) async {
    if (!_initialized || session == null || session.isGuest) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      await chatService.registerDeviceToken(
        session: session,
        platform: 'android',
        token: token,
      );
      FirebaseMessaging.instance.onTokenRefresh.listen((t) async {
        if (session.isGuest) return;
        await chatService.registerDeviceToken(
          session: session,
          platform: 'android',
          token: t,
        );
      });
    } catch (e) {
      debugPrint('FCM register failed: $e');
    }
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';

class PushNotificationService {
  PushNotificationService._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static Future<void> initialize() async {
    final NotificationSettings settings = await _requestPermission();

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedAppMessage);

    // Capture background delivery when app is launched from terminated state.
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleOpenedAppMessage(initialMessage);
    }

    _messaging.onTokenRefresh.listen((token) {
      if (token.isNotEmpty) {
        print('FCM token (refresh): $token');
      }
    });

    if (Platform.isIOS) {
      final apnsToken = await _messaging.getAPNSToken();
      if (apnsToken == null) {
        print(
          'APNS token is not available yet. Waiting for APNS registration callback before requesting FCM token.',
        );
        return;
      }

      print('APNS token: $apnsToken');

      try {
        final token = await _messaging.getToken();
        print('FCM token: $token');
      } on FirebaseException catch (e) {
        if (e.plugin == 'firebase_messaging' &&
            e.code == 'apns-token-not-set') {
          print(
            'FCM token unavailable: APNS token not set yet (possible notification registration issue).',
          );
        } else {
          rethrow;
        }
      }
    } else if (Platform.isAndroid) {
      final token = await _messaging.getToken();
      print('FCM token: $token');
    } else {
      print('Push notifications are not configured for this platform.');
    }
  }

  static Future<NotificationSettings> _requestPermission() async {
    return _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: true,
      sound: true,
    );
  }

  static void _handleForegroundMessage(RemoteMessage message) {
    print('FCM foreground message: ${message.messageId}');
  }

  static void _handleOpenedAppMessage(RemoteMessage message) {
    print('FCM opened app from notification: ${message.messageId}');
  }
}

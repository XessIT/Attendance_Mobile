import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    print("Handling a background message: ${message.messageId}");
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    // Request permission
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      if (kDebugMode) {
        print('User granted permission');
      }
    } else {
      if (kDebugMode) {
        print('User declined or has not accepted permission');
      }
    }

    // Set background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Initialize local notifications
    // Using the custom notification icon
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@drawable/notication');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings();

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        // Handle notification tap
        if (kDebugMode) {
          print("Notification tapped: ${details.payload}");
        }
        _handleNotificationTap(details.payload);
      },
    );

    // Create channel for Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel', // id
      'High Importance Notifications', // title
      description: 'This channel is used for important notifications.',
      importance: Importance.max,
    );

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null) {
        _flutterLocalNotificationsPlugin.show(
          id: notification.hashCode,
          title: notification.title,
          body: notification.body,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channelDescription: channel.description,
              // Using the custom notification icon
              icon: '@drawable/notication',
            ),
          ),
        );
      }
    });

    // Handle token
    try {
      String? token = await _firebaseMessaging.getToken();
      if (kDebugMode) {
        print("FCM Token: $token");
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error getting FCM Token: $e");
      }
    }

    // Handle notification clicks when app is in background or terminated
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (kDebugMode) {
        print("Notification clicked when app was in background: ${message.messageId}");
      }
      _handleNotificationMessage(message);
    });

    // Handle notification clicks when app was completely terminated
    RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      if (kDebugMode) {
        print("Notification clicked when app was terminated: ${initialMessage.messageId}");
      }
      _handleNotificationMessage(initialMessage);
    }
  }

  void _handleNotificationTap(String? payload) {
    // Navigate based on payload or default to home
    if (navigatorKey.currentContext != null) {
      _navigateToNotificationScreen(navigatorKey.currentContext!, payload);
    }
  }

  void _handleNotificationMessage(RemoteMessage message) {
    // Navigate based on message data or default to home
    if (navigatorKey.currentContext != null) {
      String? screen = message.data['screen'];
      String? payload = message.data['payload'];
      _navigateToNotificationScreen(navigatorKey.currentContext!, screen ?? payload);
    }
  }

  void _navigateToNotificationScreen(BuildContext context, String? payload) {
    // Default navigation logic - you can customize this based on your app structure
    if (payload != null) {
      if (kDebugMode) {
        print("Navigating with payload: $payload");
      }
      
      // You can add custom navigation logic based on payload
      // For example:
      // if (payload == 'attendance') {
      //   Navigator.pushNamed(context, '/attendance');
      // } else if (payload == 'profile') {
      //   Navigator.pushNamed(context, '/profile');
      // } else {
      //   // Default to home screen
      //   Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      // }
    }

    // Default behavior: Navigate to home screen and clear all previous routes
    Navigator.pushNamedAndRemoveUntil(
      context, 
      '/home', 
      (route) => false,
    );
  }
}

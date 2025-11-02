import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

typedef NotificationClickCallback = void Function(RemoteMessage message);

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  // GlobalKey untuk navigator agar bisa navigasi dari luar context
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // Callback untuk klik notifikasi
  static NotificationClickCallback? onFCMMessageClicked;

  // Instance FlutterLocalNotificationsPlugin
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Handler untuk background/terminated message
  @pragma('vm:entry-point')
  static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    debugPrint("Handling a background message: ${message.messageId}");

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings);
    await flutterLocalNotificationsPlugin.initialize(initSettings);

    if (message.notification != null) {
      await flutterLocalNotificationsPlugin.show(
        0,
        message.notification!.title,
        message.notification!.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'channel_id',
            'channel_name',
            channelDescription: 'Notifikasi chat dari WebProfil',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
        payload: message.data.toString(), // simpan data mentah sebagai payload
      );
    }
  }

  Future<void> initialize() async {
    // 1. Setup background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 2. Request permission notifikasi
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('User granted permission: ${settings.authorizationStatus}');

    // 3. Inisialisasi flutter_local_notifications
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings);

    await flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Local notification clicked. Payload: ${response.payload}');
        // Jika perlu, parse payload ke RemoteMessage sesuai kebutuhan
      },
    );

    // 4. Dapatkan FCM token
    String? token = await _fcm.getToken();
    debugPrint("FCM Token: $token");

    // 5. Handle notifikasi saat foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Pesan diterima di foreground: ${message.notification?.title}');

      if (message.notification != null) {
        flutterLocalNotificationsPlugin.show(
          message.hashCode, // id unik untuk setiap notifikasi
          message.notification!.title,
          message.notification!.body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'channel_id',
              'channel_name',
              channelDescription: 'Notifikasi chat dari WebProfil',
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
          payload: message.data.toString(),
        );
      }
    });

    // 6. Handle klik notifikasi saat background / app terbuka
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('FCM Notification clicked (background/foreground)');

      if (onFCMMessageClicked != null) {
        onFCMMessageClicked!(message);
      }
    });

    // 7. Subscribe ke topik umum
    _fcm.subscribeToTopic('webprofil');
  }
}

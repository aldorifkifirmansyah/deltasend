import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Singleton: dipakai dari main() & AuthViewModel, jadi listener (onTokenRefresh
/// & onMessage) tidak menumpuk tiap kali di-instantiate.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'deltasend_default_channel',
    'Notifikasi DeltaSend',
    description: 'Notifikasi status order & pesan DeltaSend',
    importance: Importance.high,
  );

  bool _tokenRefreshAttached = false;
  // uid aktif terkini; dipakai saat token refresh supaya nulis ke dokumen benar
  String? _activeUid;

  Future<void> initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _localNotifications.initialize(settings: initSettings);

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
  }

  Future<void> registerTokenForUser(String uid) async {
    if (uid.isEmpty) return;
    _activeUid = uid;

    try {
      await _messaging.requestPermission();

      final token = await _messaging.getToken();
      if (token != null) {
        await _writeToken(uid, token);
      }

      if (!_tokenRefreshAttached) {
        _tokenRefreshAttached = true;
        _messaging.onTokenRefresh.listen((newToken) {
          final current = _activeUid;
          if (current != null && current.isNotEmpty) {
            _writeToken(current, newToken);
          }
        });
      }
    } catch (e) {
      debugPrint('registerTokenForUser gagal: $e');
    }
  }

  // hapus token dari dokumen user saat logout, supaya notif gak nyasar ke
  // device ini setelah ganti akun.
  Future<void> clearTokenForUser(String uid) async {
    _activeUid = null;
    if (uid.isEmpty) return;
    try {
      await _db.collection('users').doc(uid).set({
        'fcm_token': FieldValue.delete(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('clearTokenForUser gagal: $e');
    }
  }

  Future<void> _writeToken(String uid, String token) async {
    await _db.collection('users').doc(uid).set({
      'fcm_token': token,
    }, SetOptions(merge: true));
  }

  // FCM tidak otomatis menampilkan notif saat app foreground → tampilkan manual.
  void setupForegroundListener() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification == null) return;

      _localNotifications.show(
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
      );
    });
  }
}

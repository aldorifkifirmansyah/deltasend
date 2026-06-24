import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'utils/theme.dart';
import 'package:deltasend/viewmodels/map_viewmodel.dart';
import 'package:deltasend/viewmodels/auth_viewmodel.dart';
import 'package:deltasend/viewmodels/admin_viewmodel.dart';
import 'package:deltasend/views/auth/splash_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:deltasend/services/notification_service.dart';

// farell: nambahin import package buat firebase karena pake FlutterFire config
import 'firebase_options.dart';

// Handler pesan FCM saat app background/terminated. FCM otomatis menampilkan
// notif selama payload pakai field "notification" (bukan cuma "data").
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // ignore: avoid_print
  print('FCM background message: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // farell: ubah ini, nyesuaikan import dari firebase
  // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await NotificationService().initLocalNotifications();
    NotificationService().setupForegroundListener();
  } catch (e) {
    // ignore: avoid_print
    print('Error initializing Firebase: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MapViewModel()),
        ChangeNotifierProvider(create: (_) => AuthViewModel()),
        ChangeNotifierProvider(
          create: (_) => AdminViewModel()..initAdminDashboard(),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Deltasend',
      theme: appTheme,
      home: const SplashScreen(),
    );
  }
}

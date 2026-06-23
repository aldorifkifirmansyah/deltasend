import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'utils/theme.dart';

import 'package:deltasend/viewmodels/map_viewmodel.dart';
import 'package:deltasend/viewmodels/auth_viewmodel.dart';
import 'package:deltasend/viewmodels/admin_viewmodel.dart';

import 'package:deltasend/views/auth/splash_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // ignore: avoid_print
    print('Error initializing Firebase: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MapViewModel()),
        ChangeNotifierProvider(create: (_) => AuthViewModel()),
        ChangeNotifierProvider(create: (_) => AdminViewModel()),
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
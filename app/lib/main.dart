import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';
import 'services/notification_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  NotificationService().init();
  runApp(const ChampApp());
}

class ChampApp extends StatelessWidget {
  const ChampApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Champ 视频温湿度监测',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        cardTheme: const CardThemeData(
          elevation: 1,
          margin: EdgeInsets.zero,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

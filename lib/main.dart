import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/game_screen.dart';
import 'services/ad_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AdService.initialize();
  AdService.instance.preloadInterstitial();

  // Edge-to-edge, dark status/nav bar icons to match the game's dark theme.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0A0F17),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const BouncingBallApp());
}

class BouncingBallApp extends StatelessWidget {
  const BouncingBallApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFE53935),
      brightness: Brightness.dark,
      primary: const Color(0xFFFF5A52),
      secondary: const Color(0xFF64FFDA),
      tertiary: const Color(0xFFFFC857),
      surface: const Color(0xFF121C29),
    );

    return MaterialApp(
      title: 'Ricochet Pop',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: baseScheme,
        scaffoldBackgroundColor: const Color(0xFF0A0F17),
        fontFamily: 'Roboto',
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
            color: Colors.white,
          ),
          titleLarge: TextStyle(
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
          bodyMedium: TextStyle(color: Colors.white70),
        ),
        splashFactory: InkRipple.splashFactory,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      home: const GameScreen(),
    );
  }
}

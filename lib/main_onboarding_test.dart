import 'package:flutter/material.dart';
import 'screens/onboarding_screen.dart';
import 'screens/demo_chat_screen.dart';

void main() {
  runApp(const OnboardingTestApp());
}

class OnboardingTestApp extends StatelessWidget {
  const OnboardingTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Onboarding Test',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const OnboardingScreen(),
      },
    );
  }
}
import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const TrashMapApp());
}

class TrashMapApp extends StatelessWidget {
  const TrashMapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TRASHMAP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFFFF6B35),
          secondary: const Color(0xFFF7C948),
          surface: Colors.black,
        ),
        scaffoldBackgroundColor: Colors.black,
        visualDensity: VisualDensity.compact,
      ),
      home: const HomeScreen(),
    );
  }
}

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
      builder: (context, child) {
        final size = MediaQuery.of(context).size;
        final isDesktop = size.width >= 600;
        if (isDesktop) {
          return Center(
            child: Transform.scale(
              scale: 1.5,
              child: SizedBox(
                width: size.width / 1.5,
                height: size.height / 1.5,
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    size: Size(size.width / 1.5, size.height / 1.5),
                  ),
                  child: child!,
                ),
              ),
            ),
          );
        }
        return child!;
      },
      home: const HomeScreen(),
    );
  }
}

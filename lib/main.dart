import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const SpaceJunkApp());
}

class SpaceJunkApp extends StatelessWidget {
  const SpaceJunkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SpaceJunk',
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
        // Use shortestSide to differentiate true desktop/tablet from mobile devices
        // This prevents applying the desktop scale on phones in landscape mode.
        final isDesktop = size.shortestSide >= 600;
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

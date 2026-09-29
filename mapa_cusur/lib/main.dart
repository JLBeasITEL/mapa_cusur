import 'package:flutter/material.dart';

import 'ui/screens/campus_map_screen.dart';
import 'ui/theme/poppins.dart';

void main() {
  runApp(const CampusNavigationApp());
}

class CampusNavigationApp extends StatelessWidget {
  const CampusNavigationApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(useMaterial3: true);
    return MaterialApp(
      title: 'CUSur Campus Nav',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3B82F6)),
        useMaterial3: true,
        textTheme: poppinsTextTheme(base.textTheme),
      ),
      home: const CampusMapScreen(),
    );
  }
}

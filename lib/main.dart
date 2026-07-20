import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() => runApp(const ECGViewer());

class ECGViewer extends StatelessWidget {
  const ECGViewer({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomeScreen(),
    );
  }
}
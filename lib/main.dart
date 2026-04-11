import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // flutterfire configure ile oluşan dosya
import 'screens/main_screen/login.dart'; // Senin login dosyan

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase'i başlatan kritik satır
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Workify',
      theme: ThemeData(brightness: Brightness.dark),
      home: const LoginPage(),
    );
  }
}

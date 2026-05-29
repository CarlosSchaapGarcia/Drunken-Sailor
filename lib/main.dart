import 'package:drunken_sailor/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    name: "demo-drunken-sailor",
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Drunken Sailor',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0f172a),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1e293b),
          elevation: 0,
        ),
        useMaterial3: true,
      ),
      home: const DrunkenSailorApp(),
    );
  }
}

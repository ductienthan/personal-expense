import 'package:flutter/material.dart';
import 'app_root.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        colorScheme: ColorScheme.light(
          background: Colors.grey.shade100, 
          onBackground: Colors.black, 
          primary: const Color(0xFF00B2E7), 
          secondary: const Color(0xFFE064F7), 
          tertiary: const Color(0xFFFF8D6C), 
          outline: Colors.grey),
      ),
      home: const AppRoot(),
    );
  }
}

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   // This widget is the root of your application.
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       debugShowCheckedModeBanner: false,
//       home: const AppRoot(),
//     );
//   }
// }

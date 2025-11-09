import 'package:flutter/material.dart';
import '../screens/splash_screen.dart';
import '../screens/home_screen.dart';
import '../screens/history_screen.dart';
import '../screens/about_screen.dart';

void main() {
  runApp(DeepfakeBusterApp());
}

class DeepfakeBusterApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Deepfake Buster',
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.red,
        hintColor: Colors.redAccent,
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: AppBarTheme(
          color: Colors.black,
          iconTheme: IconThemeData(color: Colors.red),
        ),
        buttonTheme: ButtonThemeData(
          buttonColor: Colors.red,
          textTheme: ButtonTextTheme.primary,
        ),
        cardTheme: CardThemeData(
          color: Colors.grey[900],
          elevation: 5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      home: SplashScreen(),
      routes: {
        '/home': (context) => HomeScreen(),
        '/history': (context) => HistoryScreen(historyItems: []),
        '/about': (context) => AboutScreen(),
      },
    );
  }
}
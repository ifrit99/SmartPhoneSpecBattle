import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'presentation/screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // ステータスバーを透明に
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  runApp(SpecBattleApp());
}

class SpecBattleApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spec Battle',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Color(0xFF6C5CE7),
        accentColor: Color(0xFF00B894),
        scaffoldBackgroundColor: Color(0xFF0D1B2A),
        fontFamily: 'Roboto',
        appBarTheme: AppBarTheme(
          color: Color(0xFF1B2838),
          elevation: 0,
        ),
      ),
      home: HomeScreen(),
    );
  }
}

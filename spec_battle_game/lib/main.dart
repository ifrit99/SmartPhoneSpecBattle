import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'data/sound_service.dart';
import 'presentation/screens/title_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // ステータスバーを透明に
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  runApp(const SpecBattleApp());
}

class SpecBattleApp extends StatefulWidget {
  const SpecBattleApp({super.key});

  @override
  State<SpecBattleApp> createState() => _SpecBattleAppState();
}

class _SpecBattleAppState extends State<SpecBattleApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    // アプリのライフサイクル変化を監視
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // アプリ終了時にサウンドリソースを解放
    SoundService().dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // アプリが完全に終了したときにも解放する
    if (state == AppLifecycleState.detached) {
      SoundService().dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spec Battle',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF6C5CE7),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6C5CE7),
          secondary: Color(0xFF00B894),
        ),
        scaffoldBackgroundColor: const Color(0xFF0D1B2A),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1B2838),
          elevation: 0,
        ),
      ),
      home: const TitleScreen(),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'data/sound_service.dart';
import 'domain/services/service_locator.dart';
import 'presentation/screens/title_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ステータスバーを透明に
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // サービスロケータの初期化
  await ServiceLocator().init();

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
    SoundService().dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      SoundService().pauseBgm();
    } else if (state == AppLifecycleState.resumed) {
      SoundService().resumeBgm();
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

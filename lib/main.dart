import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'data/sound_service.dart';
import 'domain/services/service_locator.dart';
import 'domain/services/qr_battle_service.dart';
import 'presentation/screens/title_screen.dart';
import 'presentation/screens/qr_guest_preview_screen.dart';

/// グローバルナビゲーターキー（URL対戦からの画面遷移に使用）
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// 起動時のURL対戦パラメータ（Webのみ）
QrBattleGuest? _initialBattleGuest;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ステータスバーを透明に
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // サービスロケータの初期化
  await ServiceLocator().init();

  // Web: URLパラメータから対戦データを検出
  if (kIsWeb) {
    final battleParam = QrBattleService.extractBattleParam(Uri.base);
    if (battleParam != null && battleParam.isNotEmpty) {
      try {
        _initialBattleGuest =
            ServiceLocator().qrBattleService.decodeAsGuest(battleParam);
      } catch (e) {
        debugPrint('Invalid battle param in URL: $e');
      }
    }
  }

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
    WidgetsBinding.instance.addObserver(this);

    // URL対戦パラメータがあれば、初回フレーム後にプレビュー画面へ遷移
    if (_initialBattleGuest != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final guest = _initialBattleGuest!;
        _initialBattleGuest = null;
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => QrGuestPreviewScreen(guest: guest),
          ),
        );
      });
    }
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
      navigatorKey: navigatorKey,
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

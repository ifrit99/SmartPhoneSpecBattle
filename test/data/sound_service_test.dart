import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spec_battle_game/data/local_storage_service.dart';
import 'package:spec_battle_game/data/sound_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('xyz.luan/audioplayers.global'),
    _mockAudioMethodCall,
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('xyz.luan/audioplayers'),
    _mockAudioMethodCall,
  );

  late LocalStorageService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalStorageService();
    await storage.resetForTest();
  });

  test('保存済みのBGM/SEミュート設定を読み込む', () async {
    await storage.setBgmMuted(true);
    await storage.setSeMuted(true);

    await SoundService().init(storage);

    expect(SoundService().isBgmMuted, isTrue);
    expect(SoundService().isSeMuted, isTrue);
  });

  test('ミュート設定変更を保存する', () async {
    await SoundService().init(storage);

    await SoundService().setBgmMuted(true);
    await SoundService().setSeMuted(true);

    expect(storage.isBgmMuted(), isTrue);
    expect(storage.isSeMuted(), isTrue);

    await SoundService().setBgmMuted(false);
    await SoundService().setSeMuted(false);

    expect(storage.isBgmMuted(), isFalse);
    expect(storage.isSeMuted(), isFalse);
  });
}

Future<Object?> _mockAudioMethodCall(MethodCall call) async => null;

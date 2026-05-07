import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'local_storage_service.dart';
import 'web_se_player_stub.dart'
    if (dart.library.js_interop) 'web_se_player_web.dart';

/// ゲーム内のサウンドエフェクトを一元管理するサービス（シングルトン）
///
/// Web 環境では、ブラウザの AutoPlay ポリシーにより、
/// ユーザージェスチャー（タップ/クリック）前の音声再生はブロックされる。
/// 最初のユーザー操作で [unlockAudio] を呼ぶことで AudioContext を有効化する。
///
/// ## Web SE 再生方式
/// audioplayers_web は SE 再生に根本的な問題がある:
///   - play(AssetSource(...)) を繰り返すと内部で <audio> 要素が蓄積しリソース枯渇
///   - seek() + resume() が Web 環境で確実に動作しない
///
/// 解決策: Web の SE 再生のみ JavaScript の Audio API を直接使用する。
/// SEファイルごとに Audio オブジェクトを1つ保持し、
/// currentTime = 0 → play() で確実に再利用する。
/// BGM は audioplayers のまま（ループ再生が安定しているため）。
class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  // ネイティブ用: 効果音プレイヤー（複数音の同時再生用）
  AudioPlayer? _player1;
  AudioPlayer? _player2;
  int _playerIndex = 0;

  // Web用: HTML5 Audio APIを直接使用するSEプレイヤー
  final WebSePlayer _webSePlayer = WebSePlayer();

  // BGM用プレイヤー（Web/ネイティブ共通で audioplayers を使用）
  AudioPlayer? _bgmPlayer;
  bool _isFadingOut = false;

  LocalStorageService? _storage;
  bool _isBgmMuted = false;
  bool _isSeMuted = false;

  /// Web 環境で AudioContext がアンロック済みか
  bool _audioUnlocked = !kIsWeb; // ネイティブは常にアンロック済み

  /// BGMミュート状態
  bool get isBgmMuted => _isBgmMuted;

  /// SEミュート状態
  bool get isSeMuted => _isSeMuted;

  /// AudioContext がアンロック済みか（Web のみ関連）
  bool get isAudioUnlocked => _audioUnlocked;

  AudioPlayer get _nativePlayer1 => _player1 ??= AudioPlayer();
  AudioPlayer get _nativePlayer2 => _player2 ??= AudioPlayer();
  AudioPlayer get _bgm => _bgmPlayer ??= AudioPlayer();

  /// 保存済みのサウンド設定を読み込む。
  Future<void> init(LocalStorageService storage) async {
    _storage = storage;
    _isBgmMuted = storage.isBgmMuted();
    _isSeMuted = storage.isSeMuted();
    if (_isBgmMuted) {
      await pauseBgm();
    }
  }

  /// BGMミュートのトグル
  Future<void> toggleBgmMute() => setBgmMuted(!_isBgmMuted);

  Future<void> setBgmMuted(bool muted) async {
    _isBgmMuted = muted;
    await _storage?.setBgmMuted(muted);
    if (_isBgmMuted) {
      await pauseBgm();
    } else {
      await resumeBgm();
    }
  }

  /// SEミュートのトグル
  Future<void> toggleSeMute() => setSeMuted(!_isSeMuted);

  Future<void> setSeMuted(bool muted) async {
    _isSeMuted = muted;
    await _storage?.setSeMuted(muted);
  }

  /// Web の AudioContext をユーザージェスチャー内で有効化する。
  /// タイトル画面の初回タップ等で呼び出すこと。
  Future<void> unlockAudio() async {
    if (_audioUnlocked) return;
    AudioPlayer? tempPlayer;
    try {
      // 一時的なプレイヤーで無音再生し AudioContext を resume させる
      tempPlayer = AudioPlayer();
      await tempPlayer.setVolume(0);
      await tempPlayer
          .play(AssetSource('sounds/button.wav'))
          .timeout(const Duration(milliseconds: 900));
      await tempPlayer.stop().timeout(const Duration(milliseconds: 300));
      _audioUnlocked = true;
      debugPrint('[SoundService] Web AudioContext unlocked');
    } catch (e) {
      debugPrint('[SoundService] Failed to unlock AudioContext: $e');
    } finally {
      try {
        await tempPlayer?.dispose().timeout(const Duration(milliseconds: 300));
      } catch (_) {
        // dispose失敗でタイトル画面の進行を止めない
      }
    }
  }

  @visibleForTesting
  void setAudioUnlockedForTest(bool unlocked) {
    _audioUnlocked = unlocked;
  }

  /// アセットの効果音を再生する（ファイル未存在時は無視）
  Future<void> _play(String fileName) async {
    if (_isSeMuted) return;
    if (kIsWeb) {
      // Web: HTML5 Audio API を直接使用（audioplayers をバイパス）
      await _webSePlayer.play(fileName);
    } else {
      // ネイティブ: 既存の2プレイヤー交互方式（低オーバーヘッド）
      await _playNative(fileName);
    }
  }

  /// ネイティブ用: 2プレイヤー交互再生
  Future<void> _playNative(String fileName) async {
    try {
      final useFirstPlayer = _playerIndex.isEven;
      _playerIndex++;
      final audioPlayer = useFirstPlayer ? _nativePlayer1 : _nativePlayer2;
      await audioPlayer.stop();
      await audioPlayer.play(AssetSource('sounds/$fileName'));
    } catch (e) {
      debugPrint('[SoundService] Failed to play $fileName: $e');
    }
  }

  /// バトル開始音
  Future<void> playBattleStart() => _play('battle_start.wav');

  /// 通常攻撃音
  Future<void> playAttack() => _play('attack.wav');

  /// スキル発動音
  Future<void> playSkill() => _play('skill.wav');

  /// 防御音
  Future<void> playDefend() => _play('defend.wav');

  /// 回復音
  Future<void> playHeal() => _play('heal.wav');

  /// 勝利音
  Future<void> playVictory() => _play('victory.wav');

  /// 敗北音
  Future<void> playDefeat() => _play('defeat.wav');

  /// ボタン操作音
  Future<void> playButton() => _play('button.wav');

  /// BGMをループ再生する（タイトル・バトル共通）
  Future<void> playBgm() async {
    if (_isBgmMuted) return;
    try {
      await _bgm.stop();
      await _bgm.setVolume(1.0);
      await _bgm.setReleaseMode(ReleaseMode.loop);
      await _bgm.play(AssetSource('sounds/Crimson_Gauntlet.mp3'));
    } catch (e) {
      debugPrint('[SoundService] Failed to play BGM: $e');
    }
  }

  /// 後方互換: タイトルBGM再生（playBgm へ委譲）
  Future<void> playTitleBgm() => playBgm();

  /// 現在再生中のBGMをフェードアウトして止める
  Future<void> stopBgm() async {
    if (_bgmPlayer == null) return;
    if (_isFadingOut) return;
    _isFadingOut = true;
    try {
      for (int i = 10; i >= 0; i--) {
        await Future.delayed(const Duration(milliseconds: 100));
        await _bgm.setVolume(i / 10);
      }
      await _bgm.stop();
      await _bgm.setVolume(1.0);
    } catch (_) {
      // プラットフォーム非対応の場合は無視
    } finally {
      _isFadingOut = false;
    }
  }

  /// BGMを即座に停止する（フェードなし）
  Future<void> stopBgmImmediate() async {
    if (_bgmPlayer == null) return;
    try {
      await _bgm.stop();
      await _bgm.setVolume(1.0);
    } catch (_) {}
  }

  /// BGMを一時停止する（アプリがバックグラウンドに移行した時）
  Future<void> pauseBgm() async {
    if (_bgmPlayer == null) return;
    try {
      await _bgm.pause().timeout(const Duration(milliseconds: 300));
    } catch (_) {}
  }

  /// BGMを再開する（アプリがフォアグラウンドに復帰した時）
  Future<void> resumeBgm() async {
    if (_isBgmMuted) return;
    if (_bgmPlayer == null) return;
    try {
      await _bgm.resume().timeout(const Duration(milliseconds: 300));
    } catch (_) {}
  }

  /// リソースを解放する（アプリ終了時に呼ぶ）
  Future<void> dispose() async {
    await _player1?.dispose();
    await _player2?.dispose();
    await _bgmPlayer?.dispose();
    _webSePlayer.disposeAll();
  }
}

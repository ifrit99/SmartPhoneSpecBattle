import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

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
  final AudioPlayer _player1 = AudioPlayer();
  final AudioPlayer _player2 = AudioPlayer();
  int _playerIndex = 0;

  // Web用: HTML5 Audio APIを直接使用するSEプレイヤー
  final WebSePlayer _webSePlayer = WebSePlayer();

  // BGM用プレイヤー（Web/ネイティブ共通で audioplayers を使用）
  final AudioPlayer _bgmPlayer = AudioPlayer();
  bool _isFadingOut = false;

  bool _isBgmMuted = false;
  bool _isSeMuted = false;

  /// Web 環境で AudioContext がアンロック済みか
  bool _audioUnlocked = !kIsWeb; // ネイティブは常にアンロック済み

  /// BGMミュート状態
  bool get isBgmMuted => _isBgmMuted;

  /// SEミュート状態
  bool get isSeMuted => _isSeMuted;

  /// 全体ミュート状態（後方互換）
  bool get isMuted => _isBgmMuted && _isSeMuted;

  /// AudioContext がアンロック済みか（Web のみ関連）
  bool get isAudioUnlocked => _audioUnlocked;

  /// BGMミュートのトグル
  void toggleBgmMute() {
    _isBgmMuted = !_isBgmMuted;
    if (_isBgmMuted) {
      _bgmPlayer.pause();
    } else {
      _bgmPlayer.resume();
    }
  }

  /// SEミュートのトグル
  void toggleSeMute() {
    _isSeMuted = !_isSeMuted;
  }

  /// 全体ミュートのトグル（後方互換）
  void toggleMute() {
    final newState = !isMuted;
    _isBgmMuted = newState;
    _isSeMuted = newState;
    if (_isBgmMuted) {
      _bgmPlayer.pause();
    } else {
      _bgmPlayer.resume();
    }
  }

  /// ミュートの設定（後方互換）
  void setMute(bool value) {
    _isBgmMuted = value;
    _isSeMuted = value;
  }

  /// Web の AudioContext をユーザージェスチャー内で有効化する。
  /// タイトル画面の初回タップ等で呼び出すこと。
  Future<void> unlockAudio() async {
    if (_audioUnlocked) return;
    try {
      // 一時的なプレイヤーで無音再生し AudioContext を resume させる
      final tempPlayer = AudioPlayer();
      await tempPlayer.setVolume(0);
      await tempPlayer.play(AssetSource('sounds/button.wav'));
      await tempPlayer.stop();
      await tempPlayer.dispose();
      _audioUnlocked = true;
      debugPrint('[SoundService] Web AudioContext unlocked');
    } catch (e) {
      debugPrint('[SoundService] Failed to unlock AudioContext: $e');
    }
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
      final player = _playerIndex.isEven ? _player1 : _player2;
      _playerIndex++;
      await player.stop();
      await player.play(AssetSource('sounds/$fileName'));
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
      await _bgmPlayer.stop();
      await _bgmPlayer.setVolume(1.0);
      await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer.play(AssetSource('sounds/Crimson_Gauntlet.mp3'));
    } catch (e) {
      debugPrint('[SoundService] Failed to play BGM: $e');
    }
  }

  /// 後方互換: タイトルBGM再生（playBgm へ委譲）
  Future<void> playTitleBgm() => playBgm();

  /// 現在再生中のBGMをフェードアウトして止める
  Future<void> stopBgm() async {
    if (_isFadingOut) return;
    _isFadingOut = true;
    try {
      for (int i = 10; i >= 0; i--) {
        await Future.delayed(const Duration(milliseconds: 100));
        await _bgmPlayer.setVolume(i / 10);
      }
      await _bgmPlayer.stop();
      await _bgmPlayer.setVolume(1.0);
    } catch (_) {
      // プラットフォーム非対応の場合は無視
    } finally {
      _isFadingOut = false;
    }
  }

  /// BGMを即座に停止する（フェードなし）
  Future<void> stopBgmImmediate() async {
    try {
      await _bgmPlayer.stop();
      await _bgmPlayer.setVolume(1.0);
    } catch (_) {}
  }

  /// BGMを一時停止する（アプリがバックグラウンドに移行した時）
  Future<void> pauseBgm() async {
    try {
      await _bgmPlayer.pause();
    } catch (_) {}
  }

  /// BGMを再開する（アプリがフォアグラウンドに復帰した時）
  Future<void> resumeBgm() async {
    if (_isBgmMuted) return;
    try {
      await _bgmPlayer.resume();
    } catch (_) {}
  }

  /// リソースを解放する（アプリ終了時に呼ぶ）
  Future<void> dispose() async {
    await _player1.dispose();
    await _player2.dispose();
    await _bgmPlayer.dispose();
    _webSePlayer.disposeAll();
  }
}

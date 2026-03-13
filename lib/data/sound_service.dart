import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// ゲーム内のサウンドエフェクトを一元管理するサービス（シングルトン）
///
/// Web 環境では、ブラウザの AutoPlay ポリシーにより、
/// ユーザージェスチャー（タップ/クリック）前の音声再生はブロックされる。
/// 最初のユーザー操作で [unlockAudio] を呼ぶことで AudioContext を有効化する。
class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  // 効果音用プレイヤー（複数音の同時再生を可能にするため複数インスタンス）
  final AudioPlayer _player1 = AudioPlayer();
  final AudioPlayer _player2 = AudioPlayer();
  int _playerIndex = 0;

  // BGM用プレイヤー
  final AudioPlayer _bgmPlayer = AudioPlayer();
  bool _isFadingOut = false;

  bool _isMuted = false;

  /// Web 環境で AudioContext がアンロック済みか
  bool _audioUnlocked = !kIsWeb; // ネイティブは常にアンロック済み

  /// ミュート状態
  bool get isMuted => _isMuted;

  /// AudioContext がアンロック済みか（Web のみ関連）
  bool get isAudioUnlocked => _audioUnlocked;

  /// ミュートのトグル
  void toggleMute() {
    _isMuted = !_isMuted;
  }

  /// ミュートの設定
  void setMute(bool value) {
    _isMuted = value;
  }

  /// Web の AudioContext をユーザージェスチャー内で有効化する。
  /// タイトル画面の初回タップ等で呼び出すこと。
  Future<void> unlockAudio() async {
    if (_audioUnlocked) return;
    try {
      // 無音の再生を試みることで AudioContext を resume させる
      await _player1.setVolume(0);
      await _player1.play(AssetSource('sounds/button.wav'));
      await _player1.stop();
      await _player1.setVolume(1.0);
      _audioUnlocked = true;
      debugPrint('[SoundService] Web AudioContext unlocked');
    } catch (e) {
      debugPrint('[SoundService] Failed to unlock AudioContext: $e');
    }
  }

  /// アセットの効果音を再生する（ファイル未存在時は無視）
  Future<void> _play(String fileName) async {
    if (_isMuted) return;
    try {
      // 交互にプレイヤーを使うことで連続した音の重なりを防ぐ
      final player = _playerIndex.isEven ? _player1 : _player2;
      _playerIndex++;
      await player.play(AssetSource('sounds/$fileName'));
    } catch (e) {
      // サウンドファイルが見つからない場合やプラットフォーム非対応の場合
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

  /// タイトルBGMをループ再生する
  Future<void> playTitleBgm() async {
    if (_isMuted) return;
    try {
      await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer.play(AssetSource('sounds/Crimson_Gauntlet.mp3'));
    } catch (_) {
      // 無視
    }
  }

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

  /// BGMを一時停止する（アプリがバックグラウンドに移行した時）
  Future<void> pauseBgm() async {
    try {
      await _bgmPlayer.pause();
    } catch (_) {}
  }

  /// BGMを再開する（アプリがフォアグラウンドに復帰した時）
  Future<void> resumeBgm() async {
    if (_isMuted) return;
    try {
      await _bgmPlayer.resume();
    } catch (_) {}
  }

  /// リソースを解放する（アプリ終了時に呼ぶ）
  Future<void> dispose() async {
    await _player1.dispose();
    await _player2.dispose();
    await _bgmPlayer.dispose();
  }
}

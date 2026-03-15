import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// ゲーム内のサウンドエフェクトを一元管理するサービス（シングルトン）
///
/// Web 環境では、ブラウザの AutoPlay ポリシーにより、
/// ユーザージェスチャー（タップ/クリック）前の音声再生はブロックされる。
/// 最初のユーザー操作で [unlockAudio] を呼ぶことで AudioContext を有効化する。
///
/// ## Web SE 再生方式
/// Web の AudioPlayer は同一インスタンスで **異なるソース** を切り替えると
/// 2回目以降がサイレントに失敗する問題がある。
/// また、使い捨て AudioPlayer 方式ではブラウザの audio 要素数上限に到達し
/// 数秒後にすべてのSEが無音になる。
///
/// 解決策: SEファイルごとに専用の AudioPlayer を1つ保持し、
/// 同じソースを stop() → play() で再利用する。
/// これにより「ソース切替問題」と「リソース枯渇問題」の両方を回避する。
class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  // ネイティブ用: 効果音プレイヤー（複数音の同時再生用）
  final AudioPlayer _player1 = AudioPlayer();
  final AudioPlayer _player2 = AudioPlayer();
  int _playerIndex = 0;

  // Web用: SEファイルごとの専用プレイヤー（遅延作成）
  // 同一ソースの stop→play なので Web でも確実に再生される
  final Map<String, AudioPlayer> _webPlayers = {};

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
    if (_isMuted) {
      // ミュート時はBGMも即座に一時停止
      _bgmPlayer.pause();
    } else {
      // ミュート解除時はBGMを再開
      _bgmPlayer.resume();
    }
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
      // 一時的なプレイヤーで無音再生し AudioContext を resume させる
      // （メインの _player1/_player2 を汚染しない）
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
    if (_isMuted) return;
    if (kIsWeb) {
      // Web: 毎回新しいプレイヤーを生成し、再生完了後に破棄
      // audioplayers の Web 実装はソース切り替えで失敗するため
      await _playWeb(fileName);
    } else {
      // ネイティブ: 既存の2プレイヤー交互方式（低オーバーヘッド）
      await _playNative(fileName);
    }
  }

  /// Web用: SEファイルごとの専用プレイヤーで再生
  /// 同じソースを stop→play するのでソース切替問題を回避しつつ、
  /// プレイヤー数も SE 種類数（8個）で固定されリソース枯渇しない。
  Future<void> _playWeb(String fileName) async {
    try {
      var player = _webPlayers[fileName];
      if (player == null) {
        player = AudioPlayer();
        _webPlayers[fileName] = player;
      }
      await player.stop();
      await player.play(AssetSource('sounds/$fileName'));
    } catch (e) {
      debugPrint('[SoundService] Failed to play $fileName (web): $e');
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
    if (_isMuted) return;
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
    for (final player in _webPlayers.values) {
      await player.dispose();
    }
    _webPlayers.clear();
  }
}

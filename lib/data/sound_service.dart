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
  // 初回のみ play() でソースを設定し、2回目以降は seek+resume で再利用する
  final Map<String, AudioPlayer> _webPlayers = {};
  // ソース設定済みのファイルを追跡（2回目以降は seek+resume で再生）
  final Set<String> _webSourceSet = {};

  // BGM用プレイヤー
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
    if (_isSeMuted) return;
    if (kIsWeb) {
      // Web: SEファイルごとの専用プレイヤーで seek+resume 再利用
      await _playWeb(fileName);
    } else {
      // ネイティブ: 既存の2プレイヤー交互方式（低オーバーヘッド）
      await _playNative(fileName);
    }
  }

  /// Web用: SEファイルごとの専用プレイヤーで再生
  ///
  /// audioplayers_web は `play(AssetSource(...))` を呼ぶたびに内部で
  /// 新しい HTML `<audio>` 要素を生成する。同じ AudioPlayer でも
  /// 繰り返し play() するとリソースが枯渇し無音になる。
  ///
  /// 解決策: 初回のみ play() でソースを設定し、2回目以降は
  /// stop() → seek(0) → resume() で同一ソースを再利用する。
  /// これにより `<audio>` 要素は SE 種類数（8個）で固定される。
  Future<void> _playWeb(String fileName) async {
    try {
      var player = _webPlayers[fileName];
      if (player == null) {
        player = AudioPlayer();
        _webPlayers[fileName] = player;
        debugPrint('[SoundService] Created web player for $fileName');
      }

      if (!_webSourceSet.contains(fileName)) {
        // 初回: ソースを設定して再生（<audio> 要素が1つ作られる）
        debugPrint('[SoundService] Web first play: $fileName');
        await player.play(AssetSource('sounds/$fileName'));
        _webSourceSet.add(fileName);
      } else {
        // 2回目以降: 既存の <audio> 要素を再利用
        debugPrint('[SoundService] Web replay (seek+resume): $fileName');
        await player.stop();
        await player.seek(Duration.zero);
        await player.resume();
      }
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
    for (final player in _webPlayers.values) {
      await player.dispose();
    }
    _webPlayers.clear();
    _webSourceSet.clear();
  }
}

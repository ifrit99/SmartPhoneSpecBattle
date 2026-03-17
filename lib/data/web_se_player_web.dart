import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:flutter/foundation.dart';

/// Web SE プレイヤー — HTML5 Audio API を直接使用
///
/// audioplayers_web は SE 再生に根本的な問題がある:
///   - play(AssetSource(...)) を繰り返すと <audio> 要素が蓄積しリソース枯渇
///   - seek() + resume() が Web 環境で確実に動作しない
///
/// この実装は document.createElement('audio') で <audio> 要素を作成し、
/// currentTime = 0 → play() で同一要素を確実に再利用する。
///
/// 注意: @JS('Audio') external function は new なしで Audio() を呼び出すため、
/// ブラウザの strict mode で TypeError になる。
/// document.createElement('audio') + src 設定で確実に動作させる。

class WebSePlayer {
  /// SEファイルごとにキャッシュされた JS Audio オブジェクト（最大 ~10 ファイル想定）
  final Map<String, JSObject> _cache = {};

  // ── ホットパスで毎回変換しないよう JS 値をキャッシュ ──
  static final JSString _jsCurrentTime = 'currentTime'.toJS;
  static final JSString _jsPlay = 'play'.toJS;
  static final JSString _jsPause = 'pause'.toJS;
  static final JSNumber _jsZero = (0).toJS;

  /// document オブジェクト（グローバルで不変なためキャッシュ）
  static final JSObject _document =
      globalContext.getProperty('document'.toJS) as JSObject;

  /// document.createElement('audio') で <audio> 要素を作成する
  JSObject _createAudioElement(String src) {
    final audio =
        _document.callMethod<JSObject>('createElement'.toJS, 'audio'.toJS);
    audio.setProperty('src'.toJS, src.toJS);
    return audio;
  }

  /// SE を再生する（fire-and-forget: JS の play() Promise は待機しない）
  ///
  /// 初回は <audio> 要素を生成してキャッシュし、
  /// 2回目以降は currentTime = 0 → play() で即座に再利用する。
  Future<void> play(String fileName) async {
    try {
      var audio = _cache[fileName];
      if (audio == null) {
        // Flutter Web のアセットパス: assets/assets/sounds/ファイル名
        final src = 'assets/assets/sounds/$fileName';
        audio = _createAudioElement(src);
        _cache[fileName] = audio;
        debugPrint('[WebSePlayer] Created <audio> element for $fileName');
      }
      // currentTime = 0 で先頭に巻き戻し（キャッシュ済み JS 値を使用）
      audio.setProperty(_jsCurrentTime, _jsZero);
      // play() は fire-and-forget（ゲームループをブロックしない）
      final promise = audio.callMethod<JSPromise<JSAny?>>(_jsPlay);
      unawaited(promise.toDart.catchError((e) {
        debugPrint('[WebSePlayer] play() rejected for $fileName: $e');
        return null;
      }));
    } catch (e) {
      debugPrint('[WebSePlayer] Error playing $fileName: $e');
    }
  }

  /// 全ての Audio オブジェクトを停止し解放する
  void disposeAll() {
    for (final entry in _cache.entries) {
      try {
        entry.value.callMethod<JSAny?>(_jsPause);
      } catch (e) {
        debugPrint('[WebSePlayer] Warning during dispose ${entry.key}: $e');
      }
    }
    _cache.clear();
  }
}

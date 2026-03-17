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
/// この実装は JavaScript の Audio オブジェクトを直接操作し、
/// currentTime = 0 → play() で同一要素を確実に再利用する。

/// JavaScript の Audio コンストラクタを呼び出す
@JS('Audio')
external JSObject _jsNewAudio(String src);

class WebSePlayer {
  /// SEファイルごとにキャッシュされた JS Audio オブジェクト
  final Map<String, JSObject> _cache = {};

  /// SE を再生する（fire-and-forget: JS の play() Promise は待機しない）
  ///
  /// 初回は Audio オブジェクトを生成してキャッシュし、
  /// 2回目以降は currentTime = 0 → play() で即座に再利用する。
  Future<void> play(String fileName) async {
    try {
      var audio = _cache[fileName];
      if (audio == null) {
        // Flutter Web のアセットパス: assets/assets/sounds/ファイル名
        audio = _jsNewAudio('assets/assets/sounds/$fileName');
        _cache[fileName] = audio;
        debugPrint('[WebSePlayer] Created Audio element for $fileName');
      }
      // currentTime = 0 で先頭に巻き戻し
      audio.setProperty('currentTime'.toJS, (0).toJS);
      // play() は fire-and-forget（ゲームループをブロックしない）
      final promise = audio.callMethod<JSPromise<JSAny?>>('play'.toJS);
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
    for (final audio in _cache.values) {
      try {
        audio.callMethod<JSAny?>('pause'.toJS);
      } catch (_) {}
    }
    _cache.clear();
  }
}

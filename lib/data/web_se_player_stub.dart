/// Web SE プレイヤーのスタブ（非Web環境用）
///
/// ネイティブ環境では使用されない。
/// SoundService は kIsWeb == false のとき audioplayers を直接使用する。
class WebSePlayer {
  Future<void> play(String fileName) async {}
  void disposeAll() {}
}

import 'package:flutter_test/flutter_test.dart';
import 'package:spec_battle_game/domain/data/character_bios.dart';

/// docs/plans/character-art-detail.md の表と一字一句一致させる。
const _expectedBios = {
  'fire_0':
      '熱設計チームを率いる指揮官。限界ぎりぎりまでクロックを上げても、排熱の計算だけは一度も外したことがない。怒鳴らず、迷わず、決めたら最短で走る。耐熱ジャケットの内側には、焼き付いた基板の破片をお守りとして縫い込んでいる。',
  'water_0':
      '液冷システムの設計を統括する指揮官。どれだけ負荷が跳ねても内部温度を一定に保つのが自分の仕事だと言い切る。声を荒げることはなく、冷えた判断で全体の流れを整える。ガラス質のコートの中を、常に一定のリズムで冷却液が巡っている。',
  'earth_0':
      'アーカイブ保管庫を預かる指揮官。一度受け取った記録は、どれほど古くても消さずに積層プレートへ収めていく。動きは遅いが、判断を覆すことはさらに少ない。金属板の装甲コートの重さを「持てる記憶の量だ」と穏やかに言う。',
  'wind_0':
      '通信網の司令塔を務める指揮官。混雑した帯域の中でも、いちばん軽く速い経路を見つけて全員をつなぎ直す。じっとしているのが苦手で、話しながら次の中継点を探している。フライトウェアの襟元のアンテナは、いつも一歩先の信号を拾っている。',
  'light_0':
      '撮影クルーの現場を取り仕切る指揮官。どんな暗さの中でも被写体のいちばん良い面を捉えることにこだわる。白いテックベストの胸元には、カメラレンズを模したブローチが光る。撮ったものは誰かのために残すのが役目だと考えている。',
  'dark_0':
      'セキュリティ部門を束ねる指揮官。鍵は掛けるより「見せない」ほうが確実だと考え、どこにも自分の記録を残さない。口数は少なく、必要なことだけを正確に伝える。ダークテーラードのバックルには、まだ誰も解いていない暗号が刻まれている。',
};

const _forbiddenWords = ['学園', '学校', '制服', '生徒', 'ヘイロー', '光輪'];

void main() {
  test('指揮官6体のキーすべてに紹介文がある', () {
    expect(characterBios.length, 6);
    expect(characterBios.keys, unorderedEquals(_expectedBios.keys));
    for (final entry in _expectedBios.entries) {
      expect(characterBioFor(entry.key), entry.value);
    }
  });

  test('各紹介文は「。」区切りで2〜4文で、禁止語を含まない', () {
    for (final entry in characterBios.entries) {
      final sentences = entry.value
          .split('。')
          .where((part) => part.trim().isNotEmpty)
          .toList();
      expect(
        sentences.length,
        inInclusiveRange(2, 4),
        reason: '${entry.key}: ${sentences.length}文',
      );
      for (final word in _forbiddenWords) {
        expect(
          entry.value.contains(word),
          isFalse,
          reason: '${entry.key} に禁止語「$word」',
        );
      }
    }
  });

  test('未登録キーは null を返す', () {
    expect(characterBioFor('fire_2'), isNull);
  });
}

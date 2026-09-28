import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spec_battle_game/data/firestore_ranking_backend.dart';

void main() {
  test('コンストラクタは Firebase.apps が空でも .instance に触れない', () {
    expect(Firebase.apps, isEmpty);
    expect(FirestoreRankingBackend.new, returnsNormally);
  });
}

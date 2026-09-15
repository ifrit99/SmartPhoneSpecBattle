import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/services/ranking_service.dart';

/// Firestore / 匿名認証へのランキング読み書き。Firebase 依存はこのファイルに閉じる。
///
/// コンストラクタでは `FirebaseAuth.instance` / `FirebaseFirestore.instance` に
/// 触らない。`hasConfig` 時の ServiceLocator.init で構築されるため、
/// `.instance` は `ensureFirebaseInitialized` 成功後の遅延 getter で取る。
class FirestoreRankingBackend implements RankingBackend {
  FirestoreRankingBackend({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _authOverride = auth,
        _dbOverride = firestore;

  final FirebaseAuth? _authOverride;
  final FirebaseFirestore? _dbOverride;

  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;

  @override
  String? get currentUid => _auth.currentUser?.uid;

  @override
  Future<String> signInAnonymously() async {
    final existing = _auth.currentUser;
    if (existing != null) {
      return existing.uid;
    }
    final credential = await _auth.signInAnonymously();
    final uid = credential.user?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('匿名サインインに失敗しました');
    }
    return uid;
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> submitEntry({
    required String weekId,
    required String uid,
    required int powerRating,
    required String characterCode,
    required String title,
    required DateTime expiresAt,
  }) async {
    await _entries(weekId).doc(uid).set({
      'uid': uid,
      'powerRating': powerRating,
      'characterCode': characterCode,
      'title': title,
      'updatedAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(expiresAt),
    });
  }

  @override
  Future<List<RankingBackendEntry>> loadTopEntries(String weekId) async {
    final snapshot = await _entries(weekId)
        .orderBy('powerRating', descending: true)
        .limit(50)
        .get();
    return snapshot.docs.map(_entryFrom).toList();
  }

  @override
  Future<int> countAbove({
    required String weekId,
    required int powerRating,
  }) async {
    final snapshot = await _entries(weekId)
        .where('powerRating', isGreaterThan: powerRating)
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  @override
  Future<int> countAll(String weekId) async {
    final snapshot = await _entries(weekId).count().get();
    return snapshot.count ?? 0;
  }

  @override
  Future<void> deleteAllOwnEntries() async {
    final uid = currentUid;
    if (uid == null) {
      return;
    }

    final snapshot =
        await _db.collectionGroup('entries').where('uid', isEqualTo: uid).get();
    const chunkSize = 400;
    for (var i = 0; i < snapshot.docs.length; i += chunkSize) {
      final end = (i + chunkSize).clamp(0, snapshot.docs.length);
      final batch = _db.batch();
      for (final doc in snapshot.docs.sublist(i, end)) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  CollectionReference<Map<String, dynamic>> _entries(String weekId) {
    return _db.collection('rankings').doc(weekId).collection('entries');
  }

  RankingBackendEntry _entryFrom(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return RankingBackendEntry(
      uid: _asString(data['uid'], doc.id),
      powerRating: _asInt(data['powerRating']),
      characterCode: _asString(data['characterCode'], ''),
      title: _asString(data['title'], ''),
    );
  }

  static String _asString(Object? value, String fallback) {
    return value is String ? value : fallback;
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return 0;
  }
}

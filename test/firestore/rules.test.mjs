import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  deleteDoc,
  doc,
  getDoc,
  serverTimestamp,
  setDoc,
  Timestamp,
} from 'firebase/firestore';

const rulesPath = resolve(
  dirname(fileURLToPath(import.meta.url)),
  '../../firestore.rules',
);
const rules = readFileSync(rulesPath, 'utf8');

const projectId = 'demo-smartphone-spec-battle';
const msDay = 24 * 60 * 60 * 1000;

/// Dart の `LocalLeagueService.weekIdAt` と同じ（端末ローカル日付の月曜）。
const thisMonday = mondayOf(new Date());

const validEntry = (uid, { expiresAt } = {}) => ({
  uid,
  powerRating: 150,
  characterCode: 'abc',
  title: 'ルーキー',
  updatedAt: serverTimestamp(),
  expiresAt:
    expiresAt ?? Timestamp.fromDate(new Date(Date.now() + 30 * msDay)),
});

const run = async () => {
  const testEnv = await initializeTestEnvironment({
    projectId,
    firestore: { rules },
  });

  try {
    const alice = testEnv.authenticatedContext('alice');
    const bob = testEnv.authenticatedContext('bob');
    const guest = testEnv.unauthenticatedContext();
    const aliceDb = alice.firestore();
    const bobDb = bob.firestore();
    const guestDb = guest.firestore();
    const aliceDoc = doc(aliceDb, `rankings/${thisMonday}/entries/alice`);
    const bobAsAlice = doc(bobDb, `rankings/${thisMonday}/entries/alice`);
    const guestDoc = doc(guestDb, `rankings/${thisMonday}/entries/alice`);

    // 既存 1〜6
    await assertFails(setDoc(bobAsAlice, validEntry('alice')));
    console.log('PASS 1 他人 uid への書き込み拒否');

    await assertSucceeds(setDoc(aliceDoc, validEntry('alice')));
    await assertFails(deleteDoc(bobAsAlice));
    console.log('PASS 2 他人 entry の削除拒否');

    await assertSucceeds(deleteDoc(aliceDoc));
    console.log('PASS 3 自分の entry 削除許可');

    await assertFails(
      setDoc(aliceDoc, { ...validEntry('alice'), powerRating: 9999 }),
    );
    console.log('PASS 4 値域外 powerRating 拒否');

    const missingTtl = { ...validEntry('alice') };
    delete missingTtl.expiresAt;
    await assertFails(setDoc(aliceDoc, missingTtl));
    console.log('PASS 5 expiresAt 欠落拒否');

    await assertFails(getDoc(guestDoc));
    console.log('PASS 6 未認証の read 拒否');

    // 7: weekId が今週の月曜
    await assertSucceeds(setDoc(aliceDoc, validEntry('alice')));
    console.log(`PASS 7 weekId 今週の月曜（${thisMonday}）許可`);

    // 8: 形式違い
    for (const weekId of ['abc', '2026-5-4', '2026/05/04']) {
      const badDoc = doc(aliceDb, `rankings/${weekId}/entries/alice`);
      await assertFails(setDoc(badDoc, validEntry('alice')));
    }
    console.log('PASS 8 weekId 形式違い（abc / 2026-5-4 / 2026/05/04）拒否');

    // 9: 月曜以外（今週の火曜）
    const thisTuesday = shiftYmd(thisMonday, 1);
    await assertFails(
      setDoc(
        doc(aliceDb, `rankings/${thisTuesday}/entries/alice`),
        validEntry('alice'),
      ),
    );
    console.log(`PASS 9 weekId 月曜以外（${thisTuesday}）拒否`);

    // 10: 実在しない日。timestamp.date がエラーなら拒否、繰り上がっても窓外で拒否。
    await assertFails(
      setDoc(
        doc(aliceDb, 'rankings/2026-02-30/entries/alice'),
        validEntry('alice'),
      ),
    );
    console.log('PASS 10 weekId 実在しない日（2026-02-30）拒否');

    // 11: 3 週間前 / 2 週間後の月曜（前週の月曜は実行曜日で結果が変わるので見ない）
    const threeWeeksAgo = shiftYmd(thisMonday, -21);
    const twoWeeksLater = shiftYmd(thisMonday, 14);
    await assertFails(
      setDoc(
        doc(aliceDb, `rankings/${threeWeeksAgo}/entries/alice`),
        validEntry('alice'),
      ),
    );
    await assertFails(
      setDoc(
        doc(aliceDb, `rankings/${twoWeeksLater}/entries/alice`),
        validEntry('alice'),
      ),
    );
    console.log(
      `PASS 11 weekId 窓外（${threeWeeksAgo} / ${twoWeeksLater}）拒否`,
    );

    // 12: expiresAt 今＋30 日（観点 7 の成功書き込みと同じ形。明示する）
    await assertSucceeds(
      setDoc(
        aliceDoc,
        validEntry('alice', {
          expiresAt: Timestamp.fromDate(new Date(Date.now() + 30 * msDay)),
        }),
      ),
    );
    console.log('PASS 12 expiresAt 今＋30 日 許可');

    // 13: expiresAt 今＋40 日 / 過去 / 文字列
    await assertFails(
      setDoc(
        aliceDoc,
        validEntry('alice', {
          expiresAt: Timestamp.fromDate(new Date(Date.now() + 40 * msDay)),
        }),
      ),
    );
    await assertFails(
      setDoc(
        aliceDoc,
        validEntry('alice', {
          expiresAt: Timestamp.fromDate(new Date(Date.now() - 60 * 1000)),
        }),
      ),
    );
    await assertFails(
      setDoc(aliceDoc, { ...validEntry('alice'), expiresAt: 'not-a-timestamp' }),
    );
    console.log('PASS 13 expiresAt 今＋40 日 / 過去 / 文字列 拒否');
  } finally {
    await testEnv.cleanup();
  }
};

function mondayOf(date) {
  const local = new Date(date.getFullYear(), date.getMonth(), date.getDate());
  const jsDay = local.getDay();
  const dartWeekday = jsDay === 0 ? 7 : jsDay;
  local.setDate(local.getDate() - (dartWeekday - 1));
  return formatYmd(local.getFullYear(), local.getMonth() + 1, local.getDate());
}

function shiftYmd(ymd, days) {
  const [year, month, day] = ymd.split('-').map(Number);
  const utc = new Date(Date.UTC(year, month - 1, day + days));
  return formatYmd(utc.getUTCFullYear(), utc.getUTCMonth() + 1, utc.getUTCDate());
}

function formatYmd(year, month, day) {
  return `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
}

run().catch((error) => {
  console.error(error);
  process.exit(1);
});

import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  deleteDoc,
  doc,
  getDoc,
  setDoc,
  Timestamp,
} from 'firebase/firestore';

const rules = readFileSync(resolve('firestore.rules'), 'utf8');

const projectId = 'demo-smartphone-spec-battle';

const validEntry = (uid) => ({
  uid,
  powerRating: 150,
  characterCode: 'abc',
  title: 'ルーキー',
  updatedAt: Timestamp.now(),
  expiresAt: Timestamp.fromDate(new Date(Date.now() + 30 * 24 * 60 * 60 * 1000)),
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
    const aliceDoc = doc(aliceDb, 'rankings/2026-05-04/entries/alice');
    const bobAsAlice = doc(bobDb, 'rankings/2026-05-04/entries/alice');
    const guestDoc = doc(guestDb, 'rankings/2026-05-04/entries/alice');

    await assertFails(setDoc(bobAsAlice, validEntry('alice')));
    console.log('PASS 他人 uid への書き込み拒否');

    await assertSucceeds(setDoc(aliceDoc, validEntry('alice')));
    await assertFails(deleteDoc(bobAsAlice));
    console.log('PASS 他人 entry の削除拒否');

    await assertSucceeds(deleteDoc(aliceDoc));
    console.log('PASS 自分の entry 削除許可');

    await assertFails(
      setDoc(aliceDoc, { ...validEntry('alice'), powerRating: 9999 }),
    );
    console.log('PASS 値域外 powerRating 拒否');

    const missingTtl = { ...validEntry('alice') };
    delete missingTtl.expiresAt;
    await assertFails(setDoc(aliceDoc, missingTtl));
    console.log('PASS expiresAt 欠落拒否');

    await assertFails(getDoc(guestDoc));
    console.log('PASS 未認証の read 拒否');
  } finally {
    await testEnv.cleanup();
  }
};

run().catch((error) => {
  console.error(error);
  process.exit(1);
});

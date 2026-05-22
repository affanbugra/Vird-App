/**
 * migrate_invite_codes.js
 *
 * Mevcut tüm gizli ekiplerin davet kodlarını inviteCodes koleksiyonuna taşır.
 * inviteCodes/{code} → { teamId: '...' }
 *
 * KULLANIM:
 *   SERVICE_ACCOUNT=./serviceAccountKey.json node scripts/migrate_invite_codes.js
 *
 * Güvenli: tekrar çalıştırılabilir, zaten varsa üzerine yazar (set).
 */

const admin = require('firebase-admin');
const path = require('path');

const keyPath = process.env.SERVICE_ACCOUNT || path.join(__dirname, 'serviceAccountKey.json');
admin.initializeApp({
  credential: admin.credential.cert(require(keyPath)),
});

const db = admin.firestore();

async function main() {
  console.log('migrate_invite_codes başlıyor…\n');

  const teamsSnap = await db.collection('teams').get();
  console.log(`${teamsSnap.size} ekip yüklendi.\n`);

  let written = 0;
  let skipped = 0;
  const BATCH_SIZE = 400;
  let batch = db.batch();
  let batchCount = 0;

  for (const doc of teamsSnap.docs) {
    const data = doc.data();
    const inviteCode = data.inviteCode;

    if (!inviteCode || inviteCode.trim().length === 0) {
      skipped++;
      continue;
    }

    const codeRef = db.collection('inviteCodes').doc(inviteCode.trim());
    batch.set(codeRef, { teamId: doc.id });
    batchCount++;
    written++;
    console.log(`[${doc.id}] "${data.name}" → inviteCodes/${inviteCode}`);

    if (batchCount >= BATCH_SIZE) {
      await batch.commit();
      console.log(`\n${batchCount} kayıt yazıldı (ara commit).\n`);
      batch = db.batch();
      batchCount = 0;
    }
  }

  if (batchCount > 0) await batch.commit();

  console.log(`\nMigration tamamlandı.`);
  console.log(`  Yazılan:  ${written}`);
  console.log(`  Atlanan:  ${skipped} (açık ekip veya kodu yok)`);
}

main().catch(err => {
  console.error('Hata:', err);
  process.exit(1);
});

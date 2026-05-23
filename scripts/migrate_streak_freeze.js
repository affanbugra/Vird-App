/**
 * migrate_streak_freeze.js
 *
 * streakFreezes alanı olmayan tüm kullanıcılara başlangıç hediyesi olarak
 * 1 dondurma hakkı atar. Alan zaten varsa (≥ 0) dokunmaz.
 *
 * KULLANIM:
 *   1. Firebase Console > Proje Ayarları > Hizmet Hesapları
 *      > "Yeni özel anahtar oluştur" butonuna tıkla
 *   2. İndirilen JSON dosyasını scripts/ klasörüne koy,
 *      adını "serviceAccountKey.json" yap
 *   3. Terminalde scripts/ klasöründe:
 *        npm install firebase-admin
 *        node migrate_streak_freeze.js
 */

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function migrate() {
  const usersRef = db.collection('users');
  const snap = await usersRef.get();

  const BATCH_SIZE = 400;
  let batch = db.batch();
  let count = 0;
  let skipped = 0;
  let batchCount = 0;

  for (const doc of snap.docs) {
    const data = doc.data();

    // Alan zaten varsa atla
    if (data.streakFreezes !== undefined && data.streakFreezes !== null) {
      skipped++;
      continue;
    }

    batch.update(doc.ref, { streakFreezes: 1 });
    count++;

    // Firestore batch limiti 500 — güvenli taraf 400
    if (count % BATCH_SIZE === 0) {
      await batch.commit();
      batchCount++;
      console.log(`  Batch ${batchCount} commit edildi (${count} kullanıcı güncellendi)...`);
      batch = db.batch();
    }
  }

  // Kalan kayıtları commit et
  if (count % BATCH_SIZE !== 0) {
    await batch.commit();
    batchCount++;
  }

  console.log(`\nTamamlandı!`);
  console.log(`  Güncellenen : ${count} kullanıcı`);
  console.log(`  Atlanan     : ${skipped} kullanıcı (alan zaten vardı)`);
  console.log(`  Toplam      : ${snap.size} kullanıcı`);
}

migrate().catch((err) => {
  console.error('Hata:', err);
  process.exit(1);
});

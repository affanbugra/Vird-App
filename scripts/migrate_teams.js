/**
 * migrate_teams.js
 *
 * Mevcut kullanıcıları eski tek-ekip şemasından yeni çoklu-ekip şemasına taşır:
 *   - teamId  (string) → teamIds (array)
 *   - developerTeamIds (array) → teamIds'e eklenir, alan silinir
 *   - adminTeamIds: kullanıcının kurduğu ekipler için doldurulur
 *
 * KULLANIM:
 *   1. Firebase Console > Proje Ayarları > Hizmet Hesapları
 *      > "Yeni özel anahtar oluştur" → JSON'u scripts/ klasörüne koy
 *   2. npm install firebase-admin   (bir kez)
 *   3. SERVICE_ACCOUNT=./serviceAccountKey.json node scripts/migrate_teams.js
 *
 * Güvenli: sadece ihtiyaç duyan kullanıcıları günceller; tekrar çalıştırılabilir.
 */

const admin = require('firebase-admin');
const path = require('path');

const keyPath = process.env.SERVICE_ACCOUNT || path.join(__dirname, 'serviceAccountKey.json');
admin.initializeApp({
  credential: admin.credential.cert(require(keyPath)),
});

const db = admin.firestore();

async function main() {
  console.log('Migration başlıyor…\n');

  // 1. Tüm ekipleri çek — adminUid → teamId mapping'i kur
  const teamsSnap = await db.collection('teams').get();
  /** @type {Map<string, string[]>} uid → kurduğu ekip id'leri */
  const adminTeamMap = new Map();
  for (const doc of teamsSnap.docs) {
    const adminUid = doc.data().adminUid;
    if (!adminUid) continue;
    if (!adminTeamMap.has(adminUid)) adminTeamMap.set(adminUid, []);
    adminTeamMap.get(adminUid).push(doc.id);
  }
  console.log(`${teamsSnap.size} ekip yüklendi. ${adminTeamMap.size} farklı ekip kurucusu var.\n`);

  // 2. Tüm kullanıcıları çek ve taşıma gereken olanları güncelle
  const usersSnap = await db.collection('users').get();
  console.log(`${usersSnap.size} kullanıcı kontrol edilecek.\n`);

  let updatedCount = 0;
  let skippedCount = 0;
  const BATCH_SIZE = 400;
  let batch = db.batch();
  let batchCount = 0;

  for (const doc of usersSnap.docs) {
    const data = doc.data();
    const uid = doc.id;

    const oldTeamId = data.teamId;                // string | undefined
    const oldDevTeamIds = data.developerTeamIds;  // array | undefined
    const existingTeamIds = data.teamIds;         // array | undefined (yeni şema)

    // Zaten taşınmış — teamIds varsa ve eski alanlar yoksa atla
    const alreadyMigrated =
      Array.isArray(existingTeamIds) &&
      !oldTeamId &&
      !oldDevTeamIds;

    if (alreadyMigrated) {
      // adminTeamIds'in doğru olup olmadığını yine de kontrol et
      const expectedAdmin = adminTeamMap.get(uid) || [];
      const currentAdmin = data.adminTeamIds || [];
      const adminNeedsUpdate = expectedAdmin.some(id => !currentAdmin.includes(id))
        || currentAdmin.some(id => !expectedAdmin.includes(id));

      if (!adminNeedsUpdate) {
        skippedCount++;
        continue;
      }
    }

    // Yeni teamIds hesapla
    const mergedTeamIds = new Set();
    if (Array.isArray(existingTeamIds)) existingTeamIds.forEach(id => mergedTeamIds.add(id));
    if (oldTeamId) mergedTeamIds.add(oldTeamId);
    if (Array.isArray(oldDevTeamIds)) oldDevTeamIds.forEach(id => mergedTeamIds.add(id));

    // adminTeamIds: bu kullanıcının kurduğu ekipler
    const newAdminTeamIds = adminTeamMap.get(uid) || [];

    const update = {
      teamIds: Array.from(mergedTeamIds),
      adminTeamIds: newAdminTeamIds,
      teamId: admin.firestore.FieldValue.delete(),
      developerTeamIds: admin.firestore.FieldValue.delete(),
    };

    batch.update(doc.reference, update);
    batchCount++;
    updatedCount++;

    console.log(
      `[${uid}] teamIds: [${Array.from(mergedTeamIds).join(', ')}]` +
      ` | adminTeamIds: [${newAdminTeamIds.join(', ')}]` +
      (oldTeamId ? ` (eski teamId: ${oldTeamId})` : '') +
      (oldDevTeamIds ? ` (eski devTeamIds: ${oldDevTeamIds.join(', ')})` : '')
    );

    if (batchCount >= BATCH_SIZE) {
      await batch.commit();
      console.log(`\n${batchCount} kayıt yazıldı (ara commit).\n`);
      batch = db.batch();
      batchCount = 0;
    }
  }

  if (batchCount > 0) {
    await batch.commit();
  }

  console.log(`\nMigration tamamlandı.`);
  console.log(`  Güncellenen: ${updatedCount}`);
  console.log(`  Atlanan:     ${skippedCount}`);
}

main().catch(err => {
  console.error('Hata:', err);
  process.exit(1);
});

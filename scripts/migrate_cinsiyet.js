/**
 * migrate_cinsiyet.js
 *
 * Firestore'da 'cinsiyet' alanı olmayan tüm kullanıcılara
 * varsayılan olarak 'bey' atar.
 *
 * KULLANIM:
 *   1. Firebase Console > Proje Ayarları > Hizmet Hesapları
 *      > "Yeni özel anahtar oluştur" butonuna tıkla
 *   2. İndirilen JSON dosyasını bu scripts/ klasörüne koy
 *      ve adını "serviceAccountKey.json" yap
 *   3. Terminalde bu klasörde:
 *        npm install firebase-admin
 *        node migrate_cinsiyet.js
 */

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'vird-fc834',
});

const db = admin.firestore();

async function migrateCinsiyet() {
  console.log('🔍 Kullanıcılar taranıyor...');

  const usersSnap = await db.collection('users').get();

  const batch = db.batch();
  let guncellenenSayisi = 0;
  let atlanananSayisi = 0;

  for (const doc of usersSnap.docs) {
    const data = doc.data();

    // Zaten cinsiyet alanı varsa atla
    if (data.cinsiyet !== undefined && data.cinsiyet !== null) {
      atlanananSayisi++;
      continue;
    }

    // Cinsiyet alanı yoksa 'bey' olarak ata
    batch.update(doc.ref, { cinsiyet: 'bey' });
    guncellenenSayisi++;

    console.log(`  ✏️  Güncelleniyor: ${data.name || data.email || doc.id}`);
  }

  if (guncellenenSayisi === 0) {
    console.log('✅ Güncellenecek kullanıcı bulunamadı (hepsinde zaten cinsiyet var).');
    process.exit(0);
  }

  console.log(`\n📝 ${guncellenenSayisi} kullanıcı güncellenecek, ${atlanananSayisi} kullanıcı atlandı.`);
  console.log('💾 Firestore\'a yazılıyor...');

  await batch.commit();

  console.log(`\n✅ Tamamlandı! ${guncellenenSayisi} kullanıcıya cinsiyet: 'bey' eklendi.`);
  console.log('ℹ️  Kadın olan 5 hesabı Firebase Console\'dan manuel olarak cinsiyet: hanim yapabilirsin.');
  process.exit(0);
}

migrateCinsiyet().catch((err) => {
  console.error('❌ Hata:', err);
  process.exit(1);
});

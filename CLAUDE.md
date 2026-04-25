# Vird — Claude Çalışma Kuralları

## Dokümantasyon Sistemi

README/ klasöründe 4 dosya var. Her birinin **tek** bir sorumluluğu var.

| Dosya | Soru | Ne zaman okunur |
|---|---|---|
| `README/STATUS.md` | Neredeyiz? Ne öğrendik? | **Her oturum başında — zorunlu** |
| `README/todo.md` | Şu an ne yapılıyor? | Görev alırken / modül başlarken |
| `README/vird_proje_dokumani.md` | Ne yapıyoruz? (Spec) | Yeni özellik, mimari soru |
| `README/vird_tasarim.md` | Nasıl görünmeli? | **Her UI işinde — zorunlu** |
| `README/lessons.md` | Ne öğrendik? (Teknik dersler) | Hata tekrarı önleme |

### STATUS.md
Projenin hafızası. Şunları içerir:
- Modül tablosu: hangi modül bitti, hangisi sırada
- Tamamlanan modüllerin teknik kararları ve dosya yapısı
- Kuran veri sistemi dökümantasyonu (`lib/data/quran_cuz.dart`)
- Öğrenilen dersler — tekrar edilmeyecek hatalar

### todo.md
Tüm yapılacaklar — aktif görevler, MVP backlog, MVP sonrası fikirler, açık kararlar. Tamamlanan modüller buradan silinir, STATUS.md'ye taşınır.

### vird_proje_dokumani.md
Uygulamanın neyi, neden yaptığı. MVP özellikleri, ekran yapıları, iş kuralları. Değişmez referans — bir karar netleşince buraya girer.

### vird_tasarim.md
Renkler, tipografi, spacing, animasyon, her bileşenin tam tasarım kararları. **UI yazmadan önce okunmadan kod yazılmaz.** Tasarım dışına çıkıldıysa geri dönülür.

---

## Stack

Flutter + Firebase. Test ortamı: `flutter run -d chrome` (emülatör RAM sorunu nedeniyle kullanılmıyor).

---

## Mimari Kararlar

> Bu kararlar netleşmiş — yeniden tartışmaya açma, maliyeti ve karmaşıklığı göz önünde tutarak verildi.

| Konu | Karar | Sebep |
|---|---|---|
| Kuran Haritası verisi | `{sayfa: okumaAdedi}` map, tek dokümanda | 604 ayrı doküman = gereksiz okuma maliyeti |
| Liderboard | Cloud Function haftalık snapshot alır, istemci sadece okur | Gerçek zamanlı sıralama hesabı pahalı |
| Seri / hasanat hesabı | Client'ta hesapla, sonucu Firestore'a yaz | Her açılışta sunucuya sorgu atmamak için |
| Offline mode | Firestore cache açık (`persistenceEnabled`) | Ayrı local storage mantığı yazmaya gerek yok |
| Realtime Database | Kullanılmıyor — her şey Firestore'da | İki veritabanı = fazladan karmaşıklık ve maliyet |
| Kuran veri sistemi | `QuranData` static const (`data/quran_cuz.dart`) | JSON+Provider'dan daha verimli, runtime yükü yok |
| Log & Hatim batch | `batch.commit()` ile atomik yazma | Race condition önlenir, tek ağ çağrısı |

**Firestore güvenlik kuralları notu:** Test modu 30 günde sürüyor. Yeni koleksiyon eklerken kurallara da ekle, yoksa yazma işlemleri hata verir.

**Firestore Şeması (Log & Hatim):**
```
users/{uid}/hatims/{hatimId}
  type: 'arapca' | 'meal'
  currentPage: int
  totalPages: 604
  createdAt, updatedAt: Timestamp

users/{uid}/logs/{logId}
  type: 'arapca' | 'meal'
  method: 'hatim' | 'surah' | 'pages'
  pagesRead: int
  surahId, startPage, endPage: int?
  hatimId: string?
  createdAt: Timestamp

users/{uid} (root doc fields)
  hasanat: int (FieldValue.increment ile güncellenir)
  totalPages: int (FieldValue.increment ile güncellenir)
  seri: int
```

---

## 1. Plan Önce, Kod Sonra

- 3+ adım veya mimari karar içeren her görev için önce plan yaz
- Belirsizlik varsa spec netleşmeden koda girme
- Bir şeyler ters giderse DUR, yeniden planla
- Doğrulama adımları da plana dahil edilir

## 2. Bitmeden Doğrula

- Çalıştığını kanıtlamadan görevi tamamlandı sayma
- Kendine sor: "Kıdemli bir Flutter geliştirici bunu onaylar mıydı?"
- Seri, hasanat, offline sync gibi kritik modüllerde test koş
- Logları kontrol et, doğruluğu kanıtla

## 3. Zarafet — Dengeli

- Önemsiz olmayan değişikliklerde: "Daha temiz bir yol var mı?" diye sor
- Hacky bir fix varsa: şu an bildiklerinle zarif çözümü uygula
- Basit fixlerde bunu atlat — aşırı mühendislik yapma

## 4. Bug Düzeltme — Otonom

- Bug geldiğinde: düzelt, el tutma isteme
- Log, hata, failing test — bak ve çöz
- Root cause bul, geçici fix koyma

## 5. Öz-İyileştirme

- Her düzeltme veya tamamlanan modül sonrası `README/STATUS.md` güncelle
- Öğrenilen dersi yaz, aynı hatanın tekrarını önle
- Oturum başında STATUS.md oku

---

## Görev Yönetimi

1. `README/todo.md`'ye checkable maddeler olarak plan yaz
2. Uygulamaya başlamadan önce planı doğrula
3. Giderken tamamlananları işaretle
4. Modül bitince: STATUS.md güncelle → todo.md temizle
5. Her adımda kısa özet ver

---

## Commit Kuralları

- Commit mesajı Türkçe
- Format: `tip: kısa açıklama` — örn: `feat: seri freeze sistemi eklendi`
- Tipler: `feat` (yeni özellik), `fix` (hata), `style` (UI), `refactor`, `docs`
- Mesaj 50 karakteri geçmesin
- **Sen sormadan commit atma** — sadece "commit at" deyince at

---

## Temel Prensipler

- **Önce basitlik:** Her değişikliği minimal tut
- **Root cause:** Geçici fix yok, gerçek sebebi bul
- **Tasarıma sadık:** Her UI kararı `README/vird_tasarim.md`'e uygun olmalı
- **Dinî hassasiyet:** Metin ve ton her zaman `README/vird_tasarim.md` Bölüm 13'e göre
- **UI metni yazmadan önce sor:** Buton, açıklama, başlık gibi kullanıcıya gösterilen metinler yazılacaksa önce öneriyi sun ve onay al. "Şu şekilde yazmayı düşünüyorum, uygun mu?" — onaylanmadan koda yazma.

---

## Skill Kullanım Rehberi

| Durum | Skill |
|---|---|
| Yeni büyük özellik başlamadan önce | `/grill-me` |
| Bir şey bozuldu, neden bilinmiyor | `/systematic-debugging` |
| Kritik iş mantığı (seri, hasanat) | `/tdd` |
| Flutter widget tasarımı | `/frontend-design` |

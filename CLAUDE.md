# Vird â€” Claude Ã‡alÄ±ÅŸma KurallarÄ±

## DokÃ¼mantasyon Sistemi

README/ klasÃ¶rÃ¼nde 4 dosya var. Her birinin **tek** bir sorumluluÄŸu var.

| Dosya | Soru | Ne zaman okunur |
|---|---|---|
| `README/STATUS.md` | Neredeyiz? Ne Ã¶ÄŸrendik? | **Her oturum baÅŸÄ±nda â€” zorunlu** |
| `README/todo.md` | Åu an ne yapÄ±lÄ±yor? | GÃ¶rev alÄ±rken / modÃ¼l baÅŸlarken |
| `README/vird_proje_dokumani.md` | Ne yapÄ±yoruz? (Spec) | Yeni Ã¶zellik, mimari soru |
| `README/vird_tasarim.md` | NasÄ±l gÃ¶rÃ¼nmeli? | **Her UI iÅŸinde â€” zorunlu** |
| `README/lessons.md` | Ne Ã¶ÄŸrendik? (Teknik dersler) | Hata tekrarÄ± Ã¶nleme |

### STATUS.md
Projenin hafÄ±zasÄ±. ÅunlarÄ± iÃ§erir:
- ModÃ¼l tablosu: hangi modÃ¼l bitti, hangisi sÄ±rada
- Tamamlanan modÃ¼llerin teknik kararlarÄ± ve dosya yapÄ±sÄ±
- Kuran veri sistemi dÃ¶kÃ¼mantasyonu (`lib/data/quran_cuz.dart`)
- Ã–ÄŸrenilen dersler â€” tekrar edilmeyecek hatalar

### todo.md
TÃ¼m yapÄ±lacaklar â€” aktif gÃ¶revler, MVP backlog, MVP sonrasÄ± fikirler, aÃ§Ä±k kararlar. Tamamlanan modÃ¼ller buradan silinir, STATUS.md'ye taÅŸÄ±nÄ±r.

### vird_proje_dokumani.md
UygulamanÄ±n neyi, neden yaptÄ±ÄŸÄ±. MVP Ã¶zellikleri, ekran yapÄ±larÄ±, iÅŸ kurallarÄ±. DeÄŸiÅŸmez referans â€” bir karar netleÅŸince buraya girer.

### vird_tasarim.md
Renkler, tipografi, spacing, animasyon, her bileÅŸenin tam tasarÄ±m kararlarÄ±. **UI yazmadan Ã¶nce okunmadan kod yazÄ±lmaz.** TasarÄ±m dÄ±ÅŸÄ±na Ã§Ä±kÄ±ldÄ±ysa geri dÃ¶nÃ¼lÃ¼r.

---

## Stack

Flutter + Firebase. Test ortamÄ±: `flutter run -d chrome` (emÃ¼latÃ¶r RAM sorunu nedeniyle kullanÄ±lmÄ±yor).

---

## Mimari Kararlar

> Bu kararlar netleÅŸmiÅŸ â€” yeniden tartÄ±ÅŸmaya aÃ§ma, maliyeti ve karmaÅŸÄ±klÄ±ÄŸÄ± gÃ¶z Ã¶nÃ¼nde tutarak verildi.

| Konu | Karar | Sebep |
|---|---|---|
| Kuran HaritasÄ± verisi | `{sayfa: okumaAdedi}` map, tek dokÃ¼manda | 604 ayrÄ± dokÃ¼man = gereksiz okuma maliyeti |
| Liderboard | Cloud Function haftalÄ±k snapshot alÄ±r, istemci sadece okur | GerÃ§ek zamanlÄ± sÄ±ralama hesabÄ± pahalÄ± |
| Seri / hasanat hesabÄ± | Client'ta hesapla, sonucu Firestore'a yaz | Her aÃ§Ä±lÄ±ÅŸta sunucuya sorgu atmamak iÃ§in |
| Offline mode | Firestore cache aÃ§Ä±k (`persistenceEnabled`) | AyrÄ± local storage mantÄ±ÄŸÄ± yazmaya gerek yok |
| Realtime Database | KullanÄ±lmÄ±yor â€” her ÅŸey Firestore'da | Ä°ki veritabanÄ± = fazladan karmaÅŸÄ±klÄ±k ve maliyet |
| Kuran veri sistemi | `QuranData` static const (`data/quran_cuz.dart`) | JSON+Provider'dan daha verimli, runtime yÃ¼kÃ¼ yok |
| Log & Hatim batch | `batch.commit()` ile atomik yazma | Race condition Ã¶nlenir, tek aÄŸ Ã§aÄŸrÄ±sÄ± |

**Firestore gÃ¼venlik kurallarÄ± notu:** Test modu 30 gÃ¼nde sÃ¼rÃ¼yor. Yeni koleksiyon eklerken kurallara da ekle, yoksa yazma iÅŸlemleri hata verir.

**Firestore ÅemasÄ± (Log & Hatim):**
```
users/{uid}/hatims/{hatimId}
  type: 'arapca' | 'meal'
  name: string?          (opsiyonel Ã¶zel isim)
  currentPage: int
  lastReadPage: int
  totalPages: 604
  createdAt, updatedAt: Timestamp
  â€” NOT: updatedAt FieldValue.serverTimestamp() ile yazÄ±lÄ±r; fromFirestore'da null-safe cast gerekli

users/{uid}/logs/{logId}
  type: 'arapca' | 'meal'
  method: 'hatim' | 'surah' | 'pages' | 'cuz'
  pagesRead: int
  surahId, startPage, endPage: int?
  hatimId: string?
  createdAt: Timestamp

users/{uid} (root doc fields)
  hasanat: int (FieldValue.increment ile gÃ¼ncellenir)
  totalPages: int (FieldValue.increment ile gÃ¼ncellenir)
  seri: int
```

**Hatim limitleri:** ArapÃ§a â‰¤ 3, Meal â‰¤ 1 (toplam max 4 aktif hatim)

---

## 1. Plan Ã–nce, Kod Sonra

- 3+ adÄ±m veya mimari karar iÃ§eren her gÃ¶rev iÃ§in Ã¶nce plan yaz
- Belirsizlik varsa spec netleÅŸmeden koda girme
- Bir ÅŸeyler ters giderse DUR, yeniden planla
- DoÄŸrulama adÄ±mlarÄ± da plana dahil edilir

## 2. Bitmeden DoÄŸrula

- Ã‡alÄ±ÅŸtÄ±ÄŸÄ±nÄ± kanÄ±tlamadan gÃ¶revi tamamlandÄ± sayma
- Kendine sor: "KÄ±demli bir Flutter geliÅŸtirici bunu onaylar mÄ±ydÄ±?"
- Seri, hasanat, offline sync gibi kritik modÃ¼llerde test koÅŸ
- LoglarÄ± kontrol et, doÄŸruluÄŸu kanÄ±tla

## 3. Zarafet â€” Dengeli

- Ã–nemsiz olmayan deÄŸiÅŸikliklerde: "Daha temiz bir yol var mÄ±?" diye sor
- Hacky bir fix varsa: ÅŸu an bildiklerinle zarif Ã§Ã¶zÃ¼mÃ¼ uygula
- Basit fixlerde bunu atlat â€” aÅŸÄ±rÄ± mÃ¼hendislik yapma

## 4. Bug DÃ¼zeltme â€” Otonom

- Bug geldiÄŸinde: dÃ¼zelt, el tutma isteme
- Log, hata, failing test â€” bak ve Ã§Ã¶z
- Root cause bul, geÃ§ici fix koyma

## 5. Ã–z-Ä°yileÅŸtirme

- Her dÃ¼zeltme veya tamamlanan modÃ¼l sonrasÄ± `README/STATUS.md` gÃ¼ncelle
- Ã–ÄŸrenilen dersi yaz, aynÄ± hatanÄ±n tekrarÄ±nÄ± Ã¶nle
- Oturum baÅŸÄ±nda STATUS.md oku

---

## GÃ¶rev YÃ¶netimi

1. `README/todo.md`'ye checkable maddeler olarak plan yaz
2. Uygulamaya baÅŸlamadan Ã¶nce planÄ± doÄŸrula
3. Giderken tamamlananlarÄ± iÅŸaretle
4. ModÃ¼l bitince: STATUS.md gÃ¼ncelle â†’ todo.md temizle
5. Her adÄ±mda kÄ±sa Ã¶zet ver

---

## Commit KurallarÄ±

- Commit mesajÄ± TÃ¼rkÃ§e
- Format: `tip: kÄ±sa aÃ§Ä±klama` â€” Ã¶rn: `feat: seri freeze sistemi eklendi`
- Tipler: `feat` (yeni Ã¶zellik), `fix` (hata), `style` (UI), `refactor`, `docs`
- Mesaj 50 karakteri geÃ§mesin
- **Sen sormadan commit atma** â€” sadece "commit at" deyince at

---

## Temel Prensipler

- **Ã–nce basitlik:** Her deÄŸiÅŸikliÄŸi minimal tut
- **Root cause:** GeÃ§ici fix yok, gerÃ§ek sebebi bul
- **TasarÄ±ma sadÄ±k:** Her UI kararÄ± `README/vird_tasarim.md`'e uygun olmalÄ±
- **DinÃ® hassasiyet:** Metin ve ton her zaman `README/vird_tasarim.md` BÃ¶lÃ¼m 13'e gÃ¶re
- **UI metni yazmadan Ã¶nce sor:** Buton, aÃ§Ä±klama, baÅŸlÄ±k gibi kullanÄ±cÄ±ya gÃ¶sterilen metinler yazÄ±lacaksa Ã¶nce Ã¶neriyi sun ve onay al. "Åu ÅŸekilde yazmayÄ± dÃ¼ÅŸÃ¼nÃ¼yorum, uygun mu?" â€” onaylanmadan koda yazma.

---

## Skill KullanÄ±m Rehberi

| Durum | Skill |
|---|---|
| Yeni bÃ¼yÃ¼k Ã¶zellik baÅŸlamadan Ã¶nce | `/grill-me` |
| Bir ÅŸey bozuldu, neden bilinmiyor | `/systematic-debugging` |
| Kritik iÅŸ mantÄ±ÄŸÄ± (seri, hasanat) | `/tdd` |
| Flutter widget tasarÄ±mÄ± | `/frontend-design` |

## Antigravity Çalışma Kuralları
- **ÖNCEDEN ONAY AL:** Metinler, tasarımlar veya sloganlar gibi subjektif değişiklikler yapmadan önce HER ZAMAN kullanıcıya fikir sun ve onay bekle.
- **OTOMATİK HOT RELOAD:** Flutter arka planda çalışırken kod değişirse, kullanıcıdan talimat beklemeden daima otomatik olarak 'r' gönder (hot reload yap).


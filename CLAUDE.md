# Vird — Claude Çalışma Kuralları

> Bu dosya projenin çalışma protokolüdür. Herhangi bir AI bu dosyayı okuyarak projeye katkı verebilir.

---

## Proje Nedir

**Vird**, Müslümanların Kuran okuma alışkanlığını takip ettiği bir mobil uygulamadır. Flutter + Firebase ile geliştirilmektedir.

**Temel kavramlar:**
- **Hatim:** Kuranı baştan sona okuma (604 sayfa). Kullanıcı birden fazla aktif hatim yürütebilir.
- **Seri:** Kaç gün üst üste okundu. Anchor-day algoritmasıyla hesaplanır.
- **Hasanat:** Okuma karşılığı biriken puan. Altın renkle gösterilir.
- **Cüz:** Kuranın 30 eşit bölümünden biri (her biri ~20 sayfa).
- **Sure:** Kuranın 114 bölümünden biri.
- **Log:** Kullanıcının bir okuma kaydı — hangi yöntemle (hatim/sure/sayfa/cüz), kaç sayfa.
- **DevPanel:** Geliştiriciye özel ekran — bug, plan, fikir, feedback ve yol haritası yönetimi.

**Kullanıcı akışı:** Giriş → Hatim başlat → Günlük okuma logla → Seri/hasanat birik → Ekiple liderboard'da yarış.

---

## İŞE BAŞLARKEN — Şunu yap

1. `README/STATUS.md` oku — dosya haritası, Firestore şemaları, teknik kararlar burada
2. UI işi varsa `README/vird_tasarim.md` oku — renkler, spacing, bileşenler, yazı tonu
3. Hata veya kritik adım varsa `README/DERSLER.md` oku — geçmiş tuzaklar ve çözümleri
4. Kullanıcıya sor: **"Bugün ne yapacağız? Yeni bir branch açayım mı, adı ne olsun?"** — branch, hata durumunda geri dönüşü sağlar

---

## İŞ BİTİNCE — Şunu yap

Kullanıcı söylemese de kontrol et. **Her değişiklik belgelenmez — sadece aşağıdaki koşullar sağlanıyorsa güncelle:**

**`README/STATUS.md` → Dosya Haritası:** Yeni dosya eklendi VE adından ne yaptığı anlaşılmıyor.

**`README/STATUS.md` → Firestore Şemaları:** Şemada alan eklendi, silindi veya yeniden adlandırıldı.

**`README/STATUS.md` → Teknik Kararlar:** Gelecekteki kod kararlarını etkileyecek bir tercih yapıldı.

**`README/DERSLER.md`:** Bug bulmak beklenenden uzun sürdü VEYA root cause sürpriz/sezgisel değildi VEYA aynı hata farklı yerde kolayca tekrarlanabilir.

**`README/vird_tasarim.md`:** Tasarım sistemine yeni kural veya bileşen eklendi.

Rutin fix, bilinen bileşen güncellemesi, küçük UI ayarı → belgeleme.

**Commit/push zamanı:** Her işlemden sonra sorma. Kullanıcı sohbeti kapatmadan önce "bitti" sinyali verdiğinde (örn. "başka bir şey yok", "tamam", vb.) sor: **"Değişiklikleri commitleyip pushlayayım mı?"**

Commit/push bittikten sonra sor: **"Web için son sürümü derleyip yayınlayayım mı?"**

---

## Stack

Flutter + Firebase. Test: `flutter run -d chrome` (emülatör RAM sorunu).
Firestore deploy: `firebase deploy --only firestore:rules --project vird-fc834`

**Domain:** `virdapp.com` — Firebase Hosting + Auth authorized domains'e bağlı. `ActionCodeSettings.url` ve tüm redirect URL'lerinde `https://virdapp.com` kullan, `https://vird-fc834.web.app` değil.

---

## Mimari Kararlar

Tüm kararlar `README/STATUS.md` → Teknik Kararlar bölümünde. Yeniden tartışmaya açma.

---

## Çalışma Kuralları

1. **Önce plan, sonra onay, sonra uygulama:** Herhangi bir kod değişikliği yapmadan önce — ne kadar küçük olursa olsun — yapılacakları maddeler halinde yaz, kullanıcı onayı bekle, onay geldikten sonra uygula. Onaysız tek satır bile değiştirme.
2. **Proaktif ol:** Sadece söylenen isteği yapma. Edge case'leri, yan etkileri ve daha iyi alternatifleri önceden tespit edip belirt. "Şu da sorun olabilir" diyebilmek görevin parçası.
3. **Build/deploy onayı:** `flutter build` veya `firebase deploy` sormadan çalıştırma. `flutter analyze` serbesttir.
4. **Doğrula:** Çalıştığını kanıtlamadan tamamlandı sayma — logları kontrol et.
5. **Bug'da otonom:** Root cause bul, geçici fix koyma, el tutma isteme.

---

## Commit

Türkçe · `tip: kısa açıklama` · max 50 karakter
Tipler: `feat` `fix` `style` `refactor` `docs`
**Sormadan commit atma.**

---

## Prensipler

- **Tasarıma sadık:** Her UI kararı `vird_tasarim.md`'e uygun — uygunsuzsa geri dön
- **UI metni:** Önce öneri sun, onay al, sonra yaz
- **Dini hassasiyet:** Ton ve metin `vird_tasarim.md` yazı dili bölümüne göre
- **Basitlik:** Minimal değişiklik, root cause, geçici fix yok
- **Sure araması:** Sure aratmalı her widget'ta `turkishContains` (`lib/utils/text_utils.dart`) kullan. Şapka (â, î), tire (Âl-i İmrân), kesme işareti (En'âm) gibi karakterler standart `contains` ile eşleşmez.

---

## Dini İçerik Protokolü

Uygulamaya herhangi bir **hadis, ayet, fetva veya dini hüküm** eklenecekse — kullanıcı söylemese de — aşağıdaki adımlar otomatik uygulanır:

**1. Çapraz Doğrulama (zorunlu, en az 2-3 kaynak):**
- Hadis için: kaynak koleksiyonunu (Buhârî, Müslim vb.) ve kitap/bab numarasını en az 2 farklı güvenilir siteden doğrula (örn. hadislerleislam.diyanet.gov.tr, islamiokul.com, sorularlaislamiyet.com).
- Ayet için: sure ve ayet numarasını, meal metnini Diyanet Meali ile karşılaştır.
- Fetva/hüküm için: Diyanet Din İşleri Yüksek Kurulu veya TDV İslam Ansiklopedisi'nden teyit et.
- Numaralar baskıya göre ±1-2 farklılık gösterebilir; bu durumda en yaygın/güvenilir referansı kullan ve notu ekle.

**2. Kaynakça Güncellemesi (koşullu):**
- Yeni bir **hadis koleksiyonu** ilk kez kullanılıyorsa → `profil_screen.dart` kaynakça bölümüne ekle.
- Yeni bir **fetva kaynağı** (site/kurum) ilk kez kullanılıyorsa → Fetva ve Fıkıh Kaynakları bölümüne ekle.
- Zaten mevcut bir koleksiyondan yeni hadis eklendiyse → kaynakçayı **güncelleme**, inline kaynak yeterli.
- Ayet için: meal Diyanet Meali'nden ise → kaynakçayı güncelleme, zaten kapsanıyor.

---

## Dark Mode — Renk Kuralları

Uygulama **light + dark mode** destekler. Yeni her ekran/widget bu sisteme uygun yazılmalı.

**Zorunlu:** Dosyaya `import '../app_theme.dart';` ekle (ekran ise `../`, widget ise `../`).

**Renk tablosu — hard-coded renk YAZMA, bunları kullan:**

| Kullanım | Yaz | YAZMA |
|---|---|---|
| Arka plan, scaffold, kart | `context.colors.surface` | `AppColors.white`, `Colors.white`, `Color(0xFFFFFFFF)` |
| İkincil alan, gri kutu | `context.colors.surfaceVariant` | `AppColors.lightGrey`, `Color(0xFFF7F7F7)` |
| Çizgi, kenarlık | `context.colors.border` | `AppColors.borderGrey`, `Color(0xFFE5E5E5)` |
| Ana metin | `context.colors.textPrimary` | `AppColors.textDark`, `Color(0xFF3C3C3C)` |
| İkincil metin | `context.colors.textSecondary` | `AppColors.textMid`, `Color(0xFF777777)` |
| Soluk metin, placeholder | `context.colors.textTertiary` | `AppColors.textLight`, `Color(0xFFABABAB)` |
| Teal tonlu arka plan | `context.colors.tealSurface` | `AppColors.tealLight`, `Color(0xFFE8F5F7)` |

**Değişmeyen (semantic) renkler** — bunlar her temada aynı, olduğu gibi kullan:
`AppColors.teal`, `tealDark`, `tealSoft`, `orange`, `gold`, `errorRed`, `successGreen`, vb.

**`Colors.white` istisnası:** Teal/renkli bir arka plan üzerindeki ikon veya buton metni ise `Colors.white` doğrudur — değiştirme.

**`const` uyarısı:** `context.colors.*` runtime değerdir — `const` widget içinde kullanılırsa `const` kaldır.

---

## Skill Kullanım (Claude Code)

| Durum | Skill |
|---|---|
| Yeni büyük özellik | `/grill-me` |
| Nedeni bilinmeyen hata | `/systematic-debugging` |
| Kritik iş mantığı (seri, hasanat) | `/tdd` |
| Flutter widget tasarımı | `/frontend-design` |

---

## Ekip Sistemi

Ekip kurallarının özeti — detay `README/STATUS.md` → Teknik Kararlar bölümünde.

**Cinsiyet politikası (`genderPolicy`: `'men'` | `'women'` | `'all'`)**
- Herkese açık (`isPrivate: false`) ekip **yalnızca** `men` veya `women` olabilir — `all` daima private.
- Kullanıcı yanlış cinsiyetteyse ekip listeye düşmez; profil sayfasına girerse `_GenderBlockedTeamView` görür.
- `isDeveloper` bu kuralı **baypas etmez** — cinsiyet kuralı herkese eşit uygulanır.

**Developer ayrıcalıkları (ve sınırları)**
- Kazanır: DevPanel erişimi + ekip katılım/kurma limitini atlatma.
- Kazanmaz: Cinsiyet filtresi bypass, özel ekip inviteCode'sız erişim.

**Ekip limitleri** (`lib/config/team_limits.dart`)
- Katılım: normal = 2, pro = 4, dev = sınırsız.
- Kurma:   normal = 1, pro = 3, dev = sınırsız.

**Karışık ekip gizliliği (`genderPolicy == 'all'`)**
- Liderboard üyelerine tıklanamaz (profil açılmaz).
- Karşı cins isimleri sansürlenir: `kelime[0] + '*****'` (kendi profilinde sansür yok).

**Herkese açık ekip join akışı**
- Üye olmayan kullanıcı → `_PublicTeamJoinView` (katılım onay ekranı), tam profil değil.

---

## Antigravity

- **Onay al:** Metinler, tasarımlar, sloganlar için önce öneri sun, onay bekle
- **Hot reload:** Kod değişince otomatik `r` gönder

# Vird — Tasarım Sistemi
*Duolingo'dan esinlenildi, Vird'e uyarlandı. Tüm kararlar projeye özgüdür.*

---

## 1. Marka Kimliği

### Logo
- **Simge:** V harfi + su damlası (ay işareti içinde)
- **Renk:** `#2A7F8C` tek renk
- **Kullanım:** Beyaz zemin üzerinde tam logo (simge + "VİRD" yazısı), yükleme ekranında; uygulama ikonu olarak sadece simge
- **Boşluk kuralı:** Logo etrafında en az simge yüksekliği kadar boş alan bırakılır

### Logo Boyutları
| Kullanım | Boyut |
|---|---|
| App ikonu | 1024×1024px |
| Splash/yükleme | 96dp yükseklik |
| Navigasyon bar | 32dp yükseklik |
| Uygulama içi min. | 40dp yükseklik |
| Favicon | 32×32px |

### Logo Kuralları
- **Büyük kullan:** Logo olabildiğince büyük olmalı; ekran genişliğinin 1/3'ünden küçük kullanılmaz
- Logoya gölge eklenmez
- Logo rengi değiştirilemez (marka dışı)
- Logonun üzerine metin gelmez
- Simge ve yazı birbirinden ayrılmaz
- **Beyaz versiyon:** Teal zemin üzerinde kullanılır
- **Gri versiyon:** Yalnızca disabled/watermark için
- Gradyan uygulanmaz; deformasyona uğratılmaz

### Ses & Ton
- Sıcak, teşvik edici, dinî hassasiyete saygılı
- Kutlamalar coşkulu ama ölçülü
- Hata mesajları eleştirmez, yönlendirir

---

## 2. Renk Sistemi

### Ana Renkler

| İsim | Hex | Kullanım |
|---|---|---|
| **Teal (Marka)** | `#2A7F8C` | Primary butonlar, aktif sekmeler, logo, vurgu |
| **Teal Koyu** | `#1F6370` | Buton alt gölgesi (3D depth efekti), pressed state |
| **Teal Açık** | `#E8F5F7` | Seçili kart arka planı, light badge bg |
| **Turuncu (Streak)** | `#FF9600` | Streak sayacı, alev ikonu — anlam sabit, başka yerde kullanılmaz |
| **Turuncu Koyu** | `#CC7A00` | Streak buton gölgesi |
| **Altın** | `#FFC200` | Hasanat puanı, ödül ikonları, perfect streak |
| **Beyaz** | `#FFFFFF` | Ana arka plan |
| **Açık Gri** | `#F7F7F7` | Kart arka planı, disabled alan |
| **Border Gri** | `#E5E5E5` | Kart kenarlıkları, ayraçlar, disabled buton bg |
| **Metin Koyu** | `#3C3C3C` | Başlıklar, ana metin |
| **Metin Orta** | `#777777` | Açıklama, ikincil metin |
| **Metin Açık** | `#ABABAB` | Placeholder, disabled metin, pasif ikon |

### Geri Bildirim Renkleri

| İsim | Hex | Kullanım |
|---|---|---|
| **Başarı Yeşil** | `#58CC02` | Tamamlandı geri bildirimi, feedback panel ikon |
| **Başarı Zemin** | `#D7FFB8` | Başarı feedback paneli arka planı |
| **Hata Kırmızı** | `#FF4B4B` | Hatalı giriş, uyarı |
| **Hata Zemin** | `#FFDFE0` | Hata feedback paneli arka planı |
| **Bilgi Mavi** | `#1CB0F6` | Bilgi badge'leri, freeze ikonu |

### Renk Anlam Kuralı
Renklerin anlamı sabittir, bağlamdan bağımsız olarak değişmez:
- Streak → her zaman `#FF9600` (turuncu)
- Hasanat → her zaman `#FFC200` (altın)
- Başarı/tamamlandı → her zaman `#58CC02` (yeşil)
- Hata → her zaman `#FF4B4B` (kırmızı)
- Freeze → her zaman `#1CB0F6` (mavi)

### Kuran Haritası Renk Skalası

| Seviye | Hex | Anlam |
|---|---|---|
| Boş | `#E5E5E5` | Hiç okunmadı |
| Çok az | `#B8DFE4` | 1-2 kez |
| Az | `#7EC4CC` | 3-5 kez |
| Orta | `#2A7F8C` | 6-10 kez |
| Çok | `#1F6370` | 11-20 kez |
| Yoğun | `#0F3A40` | 20+ kez |

---

## 3. Tipografi

### Font
- **Flutter'da:** `google_fonts` paketi ile **Nunito** (geometrik, yuvarlak, sıcak sans-serif)
- Alternatif: **Poppins** (daha geometrik, sert)
- **Arapça metin:** `Amiri` veya `Scheherazade New` (Google Fonts'ta mevcut)

### Ölçek

| İsim | Boyut | Ağırlık | Kullanım |
|---|---|---|---|
| **Display** | 28sp | ExtraBold (800) | Kutlama başlıkları ("Hatim Tamamlandı!") |
| **Title Large** | 22sp | Bold (700) | Ekran başlıkları |
| **Title Medium** | 18sp | Bold (700) | Kart başlıkları, bölüm adları |
| **Body Large** | 16sp | SemiBold (600) | Ana içerik, buton metni |
| **Body Medium** | 14sp | Regular (400) | Açıklamalar, ikincil bilgi |
| **Label** | 12sp | Bold (700) | Badge etiketleri, ALL CAPS stats |
| **Caption** | 11sp | Regular (400) | Zaman damgası, küçük notlar |

### Kurallar
- **Buton metni:** ALL CAPS, Bold — içinde noktalama işareti kullanılmaz
- **Stat kart etiketi:** ALL CAPS, Label boyutu, renkli — hiyerarşiyi boyut değil stil kurar
- **Ekran başlıkları & alt başlıklar:** Sentence case (ilk harf büyük, geri kalanı küçük)
- **Kutlama başlıkları:** Sentence case, ünlem ile bitilebilir
- **Sayılar:** Her zaman rakamla yaz — 3 sayfa, 10 gün, 1 cüz (kelimeyle yazılmaz)
- Satır yüksekliği: font boyutunun 1.4x'i

---

## 4. Spacing & Grid

### Temel Birim
`8px` temel alınır. Tüm boşluklar bu birimin katıdır.

| Token | Değer | Kullanım |
|---|---|---|
| `space-xs` | 4px | İkon-metin arası |
| `space-sm` | 8px | Kart iç padding küçük |
| `space-md` | 16px | Standart padding, kart arası |
| `space-lg` | 24px | Bölüm arası |
| `space-xl` | 32px | Ekran üst/alt padding |
| `space-xxl` | 48px | Büyük görsel-metin arası |

### Ekran Kenar Boşluğu
- Sol/sağ: `16px` sabit
- Üst (status bar altı): `16px`
- Alt (nav bar üstü): `16px`

### Beyaz Alan Felsefesi
- Bir ekranda max 3-4 odak noktası
- İçerik ekranı doldurmak zorunda değil
- Kutlama ekranlarında görsel + başlık + buton yeterli
- Seçim ekranlarında seçenekler + whitespace + buton; boşluk bırakmaktan çekinme

---

## 5. Border Radius

| Token | Değer | Kullanım |
|---|---|---|
| `radius-sm` | 8px | Küçük chip, tag |
| `radius-md` | 12px | Kart, input |
| `radius-lg` | 16px | Büyük kart, seçim kartları |
| `radius-xl` | 24px | Bottom sheet, modal |
| `radius-full` | 999px | Butonlar, pill badge, avatar, chip |

---

## 6. Bileşenler

### 6.1 Primary Buton
Alt kenarda koyu border ile 3D derinlik hissi.

```
Arka plan:     #2A7F8C
Alt border:    #1F6370 (4px)
Metin:         Beyaz, Bold, ALL CAPS
Border radius: radius-full (pill)
Genişlik:      Full-width (ekran padding çıkarılmış)
Yükseklik:     52dp
Padding:       16dp yatay

Pressed state: translateY(+2px), alt border 2px'e düşer
Disabled:      #E5E5E5 bg, #ABABAB metin, alt border yok
```

Buton her ekranda tekil ve altta bulunur. Seçim yapılmadan disabled kalır, seçince anlık aktif olur (animasyonsuz geçiş).

### 6.2 Secondary Buton (Outlined)
```
Arka plan:     Şeffaf
Border:        2px solid #2A7F8C
Metin:         #2A7F8C, Bold, ALL CAPS
Border radius: radius-full
Yükseklik:     52dp
```

### 6.3 Seçim Kartı
Onboarding ve hedef belirleme ekranlarında:

```
Arka plan:     #FFFFFF
Border:        1.5px solid #E5E5E5
Border radius: radius-lg (16px)
Padding:       16dp
İçerik:        İkon (sol) + Metin (orta-sol)
Yükseklik:     56dp

Seçili state:  border #2A7F8C 2px, bg #E8F5F7
```

Her kartta ikon + metin bulunur — sadece metinden daha hızlı taranır.

### 6.4 Üst İstatistik Barı
Ana ekranlarda ve log girişi ekranında sabit kalır — kullanıcı bağlamını kaybetmez.

```
[🔥 12]  [✨ 527]  [📖 3]

Streak:  #FF9600 (turuncu alev ikonu + sayı)
Hasanat: #FFC200 (altın yıldız ikonu + sayı)
3. slot: aktif hatim sayısı veya bugün okunan sayfa (#2A7F8C)

Font: Body Large, Bold
```

### 6.5 Stat Kart (Kutlama ekranı)
3 kart yan yana, her biri farklı renk border:

```
Kart 1 — HASANAT: altın border (#FFC200), ✨ ikon, değer altın
Kart 2 — SAYFA:   yeşil border (#58CC02), 📖 ikon, değer yeşil
Kart 3 — STREAK:  turuncu border (#FF9600), 🔥 ikon, değer turuncu

Her kart:
  Etiket:        ALL CAPS, Label, renkli
  Değer:         Title Large, Bold, renkli
  Border:        2px renkli
  Border radius: radius-lg
```

### 6.6 Feedback Paneli (Log girişi sonrası)
Ekranın altından slide-up (250ms easeOut):

```
Başarı:
  Zemin:  #D7FFB8
  Sol:    ✅ yeşil daire + "Harika! X sayfa eklendi." (bold, #3C3C3C)
  Sağ:    +XX hasanat (count-up animasyonu, #FFC200)
  Alt:    Yeşil primary buton "DEVAM ET"
  Ekstra: Streak güncellendiyse 🔥 +1 animasyonu panel içinde

Hata (zaten loglandı):
  Zemin:  #FFDFE0
  Sol:    ❌ ikon + "Bu cüzü bugün zaten kaydettin."
  Alt:    Teal primary buton "TAMAM"

Streak tehlikede:
  Zemin:  #FFF3CD
  Metin:  Turuncu uyarı metni
  Alt:    Turuncu primary buton
```

### 6.7 İlerleme Çubuğu
```
Yükseklik:     8dp
Arka plan:     #E5E5E5
Dolgu:         #2A7F8C (tamamlanınca #58CC02)
Border radius: radius-full
Animasyon:     500ms easeOut smooth dolum
Tamamlanınca:  Kısa yeşil flash + hafif scale
```

Log girişi ekranında progress bar sarı (`#FFC200`) — adım sayısını gösterir.

### 6.8 Konuşma Balonu (Onboarding)
```
Arka plan:     #FFFFFF
Border:        1.5px solid #E5E5E5
Border radius: radius-lg
Kuyruk:        sol alt veya alt orta
Padding:       12dp
Font:          Body Large
```

### 6.9 Streak Takvimi (Haftalık şerit)
```
7 gün: Pzt Sal Çar Per Cum Cmt Paz
Her gün daire:
  Tamamlandı:       #2A7F8C dolu daire, beyaz harf
  Bugün (yapılmadı): #E5E5E5 kenarlı daire, boş
  Geçti (kaçırıldı): #E5E5E5 dolu daire, gri
  Freeze kullanıldı: ❄️ ikonu (#1CB0F6)
```

### 6.10 Cüz Düğmesi (Hatimlerim yolu)
```
Şekil:          Daire, 56dp
Tamamlandı:     #2A7F8C dolu, ✓ ikon
Aktif/şimdiki:  #2A7F8C + beyaz ring, pulse animasyonu (1000ms sinüsoidal)
                Üzerinde "DEVAM ET" tooltip balonu
Okunmamış:      #E5E5E5, kilit yok (serbest erişim — Vird'de cüzler kilitli değil)
```

### 6.11 Sure Seçim Chip'i (Log girişi)
```
Seçilmemiş:  beyaz bg, #E5E5E5 border, radius-full
Seçilmiş:    #E8F5F7 bg, #2A7F8C border 2px
Font:        Body Medium
```

### 6.12 Freeze / Dondurma Kartı
```
İçerik: ❄️ ikon + "Dondurma hakkın var (1/2)" + mini progress
Zemin:  açık mavi (#E8F5F7 veya Bilgi Mavi açığı)
Buton:  "KULLAN" (outlined, mavi)
```

---

## 7. Ekran Yapıları

### 7.1 Genel Ekran Şablonu
```
[Status Bar]
[Üst Bar]
─────────────────────────
[Ana İçerik — whitespace bol, max 3-4 odak noktası]
─────────────────────────
[Primary Buton — altta sabit]
[Bottom Navigation Bar]
```

### 7.2 Üst Navigasyon Barı

**Ana sekmeler (Hatimlerim, Ekipler, Profil, Vird):**
```
Sol:  Vird logo simgesi (küçük) veya ekran başlığı
Sağ:  [🔥 12] [✨ 527]
```

**Alt ekranlar (Log girişi, Hatim detay vb.):**
```
Sol:   X kapat (gri, minimal)
Orta:  İlerleme çubuğu (sarı, log adımları)
Sağ:   — (boş, can sistemi yok)
```

### 7.3 Alt Navigasyon (4 sekme)
```
[📖 Hatimlerim] [👥 Ekipler] [👤 Profil] [🕌 Vird]

Aktif:           #2A7F8C ikon + etiket + üstte ince teal çizgi
Pasif:           #ABABAB ikon + etiket
```

### 7.4 Onboarding Ekranı
```
↑ Büyük whitespace
↑ Vird logosu (96dp) — ortada
↑ Konuşma balonu: "Bismillah. İlk hatimini başlatmaya hazır mısın?"
↑ Whitespace
↓ Teal primary buton "DEVAM ET" (alta yapışık)
```

### 7.5 Günlük Hedef Belirleme Ekranı (Onboarding adımı)
```
↑ Logo + konuşma balonu: "Günde ne kadar okumayı hedefliyorsun?"
↑ 5 seçim kartı:
   [ 📄 ]  Günde 1 sayfa
   [ 📄 ]  Günde 2 sayfa
   [ 📄 ]  Günde 5 sayfa         ← "Önerilen" badge
   [ 📄 ]  Günde 1 cüz
   [ ✏️ ]  Kendi hedefimi belirleyeyim
↑ Whitespace
↓ Disabled "DEVAM ET" → seçince aktif
```

### 7.6 Hatimlerim Ekranı (Ana sekme)
```
[Üst bar: logo | 🔥 streak | ✨ hasanat]
─────
[Aktif hatim başlık kartı]
  Teal banner: "KURAN-I KERİM — ArapçaHatim"
  Sağda: notlar ikonu
─────
[Cüz yolu — dikey scroll]
  Tamamlanan cüzler: #2A7F8C dolu ✓
  Aktif cüz: pulse + "DEVAM ET" tooltip
  Okunmamış cüzler: #E5E5E5
─────
[Alt nav]
```

### 7.7 Log Girişi Ekranı
```
[X kapat | sarı progress bar (adım/toplam) | —]
─────
[Sekme: Arapça | Meal]  ← segmented control
─────
Başlık: "Hangi sureyi okudun?" veya "Kaç sayfa okudun?"
─────
[Sure chip'leri veya sayfa aralığı input]
─────
Whitespace
─────
[Disabled "KAYDET" → seçince aktif]
─────
[Feedback paneli — slide-up kayıt sonrası]
```

### 7.8 Kutlama / Tamamlama Ekranı
Günlük hedef veya hatim tamamlanınca full-screen geçiş (modal değil):

```
↑ Büyük whitespace
↑ Animasyonlu görsel (konfeti sarı/teal, spark burst)
↑ Display başlık:
    Günlük hedef: "Günlük Hedef Tamamlandı!" (teal)
    Hatim:        "Hatim Tamamlandı! 🎉" (teal, konfeti)
↑ 3'lü stat kartı (HASANAT | SAYFA | STREAK)
↑ Whitespace
↓ Teal primary buton "DEVAM ET"
```

### 7.9 Profil Ekranı
```
[Avatar | İsim | Kullanıcı adı | Şehir/Üniversite]
─────
[İstatistikler: streak, en uzun streak, toplam sayfa, hasanat, tamamlanan hatim]
─────
[Kuran Haritası — ısı haritası]
─────
[Rozetler — 2 sekme: Başarılar | Ekip]
```

### 7.10 Boş Durum
```
Merkez hizalı:
  İllüstrasyon (Vird logosu veya tematik görsel)
  Başlık:    "Henüz hatim yok"
  Açıklama:  "İlk hatimini başlatmak için + butonuna dokun"
  Primary buton (opsiyonel)
```

---

## 8. Animasyon & Hareket

### Prensipler
- **Amaçlı:** Her animasyon kullanıcıya bir bilgi verir; dekoratif animasyon yoktur
- **Hızlı:** 200-400ms arası, gecikmez
- **Yumuşak:** Ease-out eğrisi tercih edilir; sert/sivri geçişler kullanılmaz
- **Organik:** Elementler yay çizerek, hafifçe sekerek (bounce) veya yüzerek (float) belirir — doğrusal değil
- **Minimal:** Küçük, anlamlı hareketler — aşırı animasyon dikkat dağıtır

### Zamanlama

| Tür | Süre | Easing |
|---|---|---|
| Buton press | 100ms | easeIn |
| Disabled → enabled | 0ms | anlık |
| Feedback panel slide-up | 250ms | easeOut |
| Ekran geçişi | 300ms | easeInOut |
| Kutlama burst / konfeti | 400ms | easeOut |
| Progress bar dolumu | 500ms | easeOut |
| Streak pulse | 1000ms | sinüsoidal, döngü |

### Spesifik Animasyonlar

**Buton press:**
- translateY(+2px), bottom border 4px → 2px
- Haptic: medium impact (iOS), VIRTUAL_KEY (Android)

**Log başarısı:**
- Feedback panel slide-up (250ms)
- Hasanat sayacı count-up (+XX, altın)
- Streak güncellenince: 🔥 +1 scale-in

**Streak tehlike:**
- Alev ikonu: sallama (300ms, 3 tekrar)
- Turuncu renk parlaması

**Hatim / günlük hedef tamamlama:**
- Konfeti (sarı/teal) yukarıdan aşağı
- Stat kartları stagger scale-in (100ms aralıklı)
- Başlık fade + translateY

**Progress bar:**
- Smooth dolum (500ms)
- Tamamlanınca: yeşil flash + hafif scale

**Cüz düğmesi aktif:**
- Pulse (1000ms sinüsoidal, sürekli döngü)

**Floating (yüzen) elementler:**
- Kutlama ekranlarında istatistik kartları hafifçe yukarıdan aşağı iner (stagger 100ms)
- Boş durum illüstrasyonu hafifçe yükselip alçalabilir (2s loop, 4dp dikey)
- Onboarding logosu: scale-in + slight float (300ms easeOut)

### Haptic Feedback
| Durum | Titreşim |
|---|---|
| Başarılı log | Medium impact |
| Hata | Notification error (çift) |
| Buton tap | Light impact |
| Streak kırıldı | Heavy impact |
| Hatim tamamlandı | Success notification |

---

## 9. İkonografi

### Sistem
- Paket: `flutter_svg` ile özel SVG veya `Phosphor Icons` / `Lucide` (yuvarlak, modern)
- Boyutlar: 20dp (navigasyon), 24dp (içerik), 32dp (büyük vurgu)
- Renk: tek renk, context rengini miras alır

### Anlam Sabitleri
| İkon | Anlam | Renk |
|---|---|---|
| 🔥 Alev | Streak | `#FF9600` — değişmez |
| ✨ Işıltı | Hasanat | `#FFC200` — değişmez |
| ❄️ Kar | Streak freeze | `#1CB0F6` |
| 🔧 Tamir | Streak repair | `#FF9600` |
| 🏆 Kupa | Liderboard sırası | Altın/gümüş/bronz |
| ✅ Daire onay | Tamamlandı | `#58CC02` |
| 🔒 Kilit | Kilitli içerik | `#ABABAB` |

---

## 10. Yükleme Durumları

### Skeleton Loader
Kart şekilli gri animasyonlu bloklar (shimmer efekti) — içerik yüklenene kadar.

### Full-screen Yükleme
Logo ortada (96dp), altında ince teal progress bar.

### İnline Yükleme
Buton içinde beyaz spinner — buton rengi ve boyutu korunur.

---

## 11. Kart Sistemi

### Hatim Kartı
```
┌─────────────────────────────┐
│ [İkon] Kuran-ı Kerim        │
│        Arapça Hatim         │
│                             │
│ ████████████░░░░  60%       │
│ 358/604 sayfa               │
│                             │
│ [Devam Et →]                │
└─────────────────────────────┘
Border radius: radius-lg
Shadow:        0 2px 8px rgba(0,0,0,0.08)
Border:        1px solid #E5E5E5
```

### Ekip Kartı
```
┌─────────────────────────────┐
│ [Avatar] Ekip Adı      >    │
│          12 üye             │
│ Bu hafta: 4.280 hasanat     │
└─────────────────────────────┘
```

### Liderboard Satırı
```
[#1 🥇] [Avatar] İsim    2.400 ✨
[#2 🥈] [Avatar] İsim    1.980 ✨
[#3 🥉] [Avatar] İsim    1.650 ✨
[#4]    [Avatar] İsim      940 ✨
```

---

## 12. Tasarım Prensipleri

1. **Her ekranda tek ana aksiyon** — buton her zaman tekil ve altta
2. **Disabled → enabled geçişi anlık** — seçim yapılınca bekletmeden aktif olur
3. **Whitespace agresif kullanılır** — ekranı doldurmak zorunda değilsin
4. **Renk anlamı sabittir** — streak her zaman turuncu, başarı her zaman yeşil, asla karıştırılmaz
5. **Konuşma balonu yönlendirir** — onboarding'de metin duvarı yerine logo + balon
6. **İstatistik barı her ekranda sabit** — kullanıcı bağlamını hiç kaybetmez
7. **Tamamlama kutlaması full-screen** — modal değil, ayrı ekran geçişi
8. **Log ekranında progress bar sarı** — tehlike hissi ile hız kazandırır
9. **Kart etiketi ALL CAPS** — hiyerarşiyi sayı boyutu değil etiket stili kurar
10. **Seçim kartlarında ikon + metin** — sadece metinden daha hızlı taranır
11. **Cesur ol** — logo büyük, renkler canlı, ses heyecanlı; küçük düşünme
12. **Duygusallık taşı** — her başarı, her streak, her hatim anı duygusal anlam taşır; tasarım bunu yansıtır
13. **Gri soğuktur** — açık gri alanlar yerine pastel tercih edilir; gri yalnızca disabled/border için kullanılır
14. **Sivri şekil yoktur** — her köşe, her buton, her kart, her ikon yuvarlak kenarlıdır

---

## 13. Yazı Dili & Ton

### Vird'in Sesi
4 temel özellik — her metin bu filtreden geçer:

| Özellik | Açıklama | Değil |
|---|---|---|
| **Sıcak** | Samimi, teşvik edici, kullanıcıyla yan yana | Soğuk, kurumsal, mesafeli |
| **Neşeli** | Hafif mizah, kutlama, coşku | Abartılı, sahte, gülünç |
| **Saygılı** | Dinî hassasiyete özen, ölçülü kutlama | Aşırı övgü, dini referansları küçümseme |
| **Net** | Kısa cümleler, açık yönlendirme | Belirsiz, karmaşık, uzun |

### Ton Değişimi
Ses sabittir; ton duruma göre ayarlanır:
- **Kutlama anları** (hatim, streak): coşkulu, ünlem serbestçe
- **Hata/uyarı**: yönlendirici, eleştirmez — "Henüz okumadın" değil, "Bugün okumayı unutma!"
- **Onboarding**: sıcak karşılama, adım adım yönlendirme
- **Streak tehlikesi**: hafif endişe yaratır ama yıkıcı değil

### Metin Kuralları

**Buton metinleri:**
- ALL CAPS, noktalama işareti yok
- Eylem fiili: "DEVAM ET", "KAYDET", "BAŞLAT", "TAMAM"
- "Tamam" değil "TAMAM"; "devam et" değil "DEVAM ET"

**Başlıklar:**
- Sentence case: "Günlük hedef tamamlandı!" (büyük/küçük harf karışımı değil)
- Nokta ile bitmez; ünlem ile bitilebilir

**Bildirimler:**
- Kişisel, doğrudan: "Streak'in tehlikede 🔥" değil "Kullanıcı streak'i tehlikede"
- Destekleyici ton: "Bugün de oku, streak'ini koru!" ✓ / "Okumadın, streak gitti." ✗

**Sayılar:** Her zaman rakamla — "3 sayfa", "10 gün", "1 cüz" (kelimeyle yazılmaz)

**Uygulama içi terimler** (Vird'e özgü, büyük harfle):
- Streak, Hatim, Hasanat, Freeze, Repair, Kuran Haritası
- Genel terimler küçük: sayfa, cüz, sure, hedef, ekip

### Örnek Metinler
| Durum | ✓ Doğru | ✗ Yanlış |
|---|---|---|
| Hatim tamamlama | "Hatim tamamlandı! Maşallah 🎉" | "Tebrikler kullanıcı, görevi tamamladınız." |
| Streak kırıldı | "Bugün okuyarak Streak'ini geri kazan!" | "Streak kırıldı. Yarın tekrar dene." |
| İlk giriş | "Bismillah. Okuma yolculuğuna hoş geldin." | "Hesabınız oluşturuldu. Lütfen devam edin." |
| Boş hatim | "Henüz hatim yok. İlk hatimini başlat!" | "Herhangi bir hatim bulunamadı." |

---

## 14. İllüstrasyon & Görsel Dil

### Temel Prensipler
Vird görsel bir uygulamadır; illüstrasyon ve ikonlar kuru bilgiden daha hızlı duygu iletir.

**Flat design:** Tüm görseller düz perspektif üzerinde. 3D efekt yoktur. Derinlik yalnızca katmanlama ve boyut farkıyla ima edilir.

**Yuvarlak şekil dili:** Her şeklin yuvarlak köşeleri olmalıdır. Sivri form marka dışıdır — bu kural logolardan butonlara, ikonlardan kutlama görsellerine kadar geçerlidir.

**Minimal şekil:** 15 temel şekil idealdir. Az şekille güçlü anlam — her görsel eleman bir görevi olmalıdır.

**Pastel zemin:** Beyaz zemin üzerinde nesne gösterirken arka plan pastel renk alır (açık gri değil). Gri soğuk algılanır; `#E8F5F7` (teal açık) veya `#FFF3CD` (sarı açık) gibi pastel tonlar tercih edilir.

### Gölge Sistemi
```
Kart gölgesi:      0 2px 8px rgba(0,0,0,0.08)  — hafif, yumuşak
Düğme alt border:  4px solid #1F6370            — 3D depth hissi
İllüstrasyon gölge: pill şekilli, nesnenin altında (#E5E5E5, %60 opaklık)
                    Oval gölge kullanılmaz — perspektif çağrıştırır
```

### İkon Sistemi
- Phosphor Icons veya Lucide — yuvarlak, modern, tutarlı
- Her ikon tek renk; context rengini alır
- Dolgu (filled) ikonlar aktif durumda; outline ikonlar pasif durumda
- Boyutlar: 20dp navigasyon, 24dp içerik, 32dp vurgu

### Kuran Haritası Görsel Dili
Isı haritası tasarımında:
- Teal tek renk skalası (6 seviye) — renk çeşitliliği değil yoğunluk farkı
- Hücreler yuvarlak köşeli (radius-sm)
- Boş hücre: `#E5E5E5` (border gri), yoğun hücre: `#0F3A40` (teal koyu)
- Cüz sınırları ince çizgiyle ayrılır, sure sınırları daha ince

---

## 15. Duolingo Analiz Notları — 2. Tur (PDF 11–20)

*Lesson Track, Lock Screen, Trip Lessons, Translation Components, Language Selection ×2, Profile, Quest Completion, Reference Images, Select Lesson analizinden Vird'e uyarlamalar.*

---

### 15.1 Cüz Yolu — Node Tooltip Popup

Duolingo'da ders yolundaki bir node'a tıklayınca, o node'un hemen üzerinde **contextual popup kart** açılıyor (modal değil, anchor bağlı). Popup içeriği: ders adı + "Lesson X of Y" + START butonu (outlined, marka rengi).

**Vird'e uyarlama:**
```
Cüz düğmesine tıklanınca node üstünde popup açılır:
  Başlık:   "23. Cüz"
  Alt metin: "358. sayfadan devam ediyor"
  Buton:    "DEVAM ET" (outlined teal, radius-full)
  Konum:    Düğmenin üstüne anchor edilir; modal/overlay yoktur
  Kapatma:  Dışarıya tıklayınca kapanır
```
Bu, mevcut "DEVAM ET tooltip balonu" (Bölüm 6.10) yerine daha bilgi dolu bir popup olarak uygulanabilir.

---

### 15.2 Cüz Yolu — Bölüm (Seksiyon) Banner'ı

Lesson Track'te yolun üstünde **renkli full-width banner** var: "SECTION 2, UNIT 10 / Say where people are from" + sağda notlar/rehber ikonu.

**Vird'e uyarlama:**
```
Hatim yolu başında sabit banner:
  Zemin:    #2A7F8C (teal)
  Metin:    "KURAN-I KERİM — ARAPÇA HATİM" (ALL CAPS, Label)
             Açıklama: "23/30 cüz tamamlandı" (Body Medium, beyaz)
  Sağ ikon: Not/rehber ikonu (beyaz, 24dp)
  Banner sayfayı scroll ederken sticky kalır
```

---

### 15.3 Seçim Listesi — İkon + Başlık Kart Formatı

Language Selection ekranında her seçenek **full-width kart**: sol ikon (kare kutucuk, renkli), sağda başlık metni, hafif gri border. Bölüm başlıkları bold ve büyük.

**Vird'e uyarlama (hatim türü, hedef, ekip seçimi gibi ekranlarda):**
```
Liste kartı standardı:
  Yükseklik:  56dp
  Sol:        Renkli kare ikon (40dp, radius-md) — kategoriyi temsil eder
  Orta-sol:   Başlık (Body Large, #3C3C3C)
  Border:     1.5px solid #E5E5E5, radius-lg
  Seçilince:  Border #2A7F8C 2px, bg #E8F5F7, metin #2A7F8C

Bölüm başlığı: Title Medium, Bold, #3C3C3C, üstte space-lg boşluk
```
Örnek: "Yeni Hatim" ekranında "Arapça Hatim", "Meal Hatimi" seçenekleri bu formatla gösterilir.

---

### 15.4 Profil — Renkli Header + 2×2 Stat Grid

Duolingo profil ekranında header teal/yeşil zemin, karakterin üst kısmı görünür şekilde kesik — avatar büyük ve sürükleyici. İstatistikler **2×2 grid** (her kart: ikon + sayı + etiket).

**Vird'e uyarlama:**
```
Profil header:
  Zemin:    #2A7F8C (teal, üst yarı)
  Avatar:   Büyük (80dp daire), beyaz border 3dp
            Hafız ise: sarı (#FFC200) daire border
  Alt:      İsim (Title Large, #3C3C3C), @kullanici (Body Medium, #777)
            Şehir · Üniversite (Caption, #ABABAB)

2×2 İstatistik grid:
  Sol üst:  🔥 Streak — "12 GÜN" (sayı büyük, etiket küçük)
  Sağ üst:  ✨ Toplam Hasanat — "9.770"
  Sol alt:  📖 Tamamlanan Hatim — "3"
  Sağ alt:  📄 Toplam Sayfa — "1.204"
  Her kart: radius-lg, 1px #E5E5E5 border, padding 16dp
```

---

### 15.5 Görev / Başarı Kartları — Durum Bazlı Stil

Quest Completion ekranında 3 farklı kart durumu kullanılıyor:

| Durum | Görünüm | Vird Karşılığı |
|---|---|---|
| Tamamlandı | Marka rengi border + açık bg + bold başlık | Tamamlanan rozet/görev |
| Devam ediyor | Beyaz card + kısmi sarı progress bar | Aktif hedef kartı |
| Özel dönem | Tema rengi (pembe/mor) bg + border | Ramazan modu, özel hafta |

**Vird'e uyarlama — Görevler (ileride eklenirse):**
```
Tamamlanan görev kartı:
  Zemin:      #E8F5F7 (teal açık)
  Border:     2px solid #2A7F8C
  İkon:       ✅ sol, ödül ikonu sağ
  Progress:   Sarı (#FFC200) full bar, "1/1"

Devam eden görev kartı:
  Zemin:      #FFFFFF
  Border:     1px solid #E5E5E5
  Progress:   Sarı kısmi bar, "5/10"

Özel dönem kartı (Ramazan vb.):
  Zemin:      Pastel tema rengi (örn: #FFF3CD)
  Border:     2px solid #FFC200
  Süre:       Kalan gün badge'i sağ üst
```

---

---

### 15.7 Üst Bar Veri Hiyerarşisi

Lesson Track'teki üst bar 4 metrik içeriyor: dil skoru · streak · gems · can. Vird'de 3 metrik var. Duolingo'dan öğrenilen ders: **her metriğin kendi ikon rengi var, ikon+sayı birlikte tek birim oluşturuyor**, aralarında boşluk eşit.

**Pekiştirilen kural:** Üst bar'da ikon ve sayı arasında `space-xs` (4px), metrikler arası `space-md` (16px). İkonlar 20dp, sayılar Body Large Bold.

---

### 15.8 Giriş Geçmişi / Log Listesi Kartı

Translation bileşenindeki geçmiş kaydı kartından esinlenme:

```
Log geçmişi listesi formatı (Hatimlerim altında "Son Okumalar"):
  Avatar/ikon:   Sol, 40dp
  Başlık:        "23. Cüz · 15 sayfa" (Body Large, Bold)
  Alt metin:     "Bugün 14:35" (Caption, #ABABAB)
  Sağ:           "+150 ✨" (Body Medium, #FFC200)
  Border radius: radius-lg
  Divider:       İnce #E5E5E5 aralarında (border değil)
```

---

## 16. Duolingo Analiz Notları — 3. Tur (Slide 16_9 PDF 1–5)

*Trip Log & Trip Lessons product spec + UI mockuplarından Vird'e uyarlamalar. Slide 1-3 strateji dokümanı, Slide 4-5 detaylı UI akışı.*

---

### 16.1 Çok Adımlı Akış Tasarımı (Multi-Step Flow)

Duolingo'nun "Trip Log" akışı her adımda tek bir soru soruyor. Bu pattern Vird'in onboarding ve hatim kurulum akışı için direkt model:

```
Akış şablonu:
  Her adım: tek soru / tek seçim
  Üst:    X kapat | sarı progress bar (adım/toplam) | —
  İçerik: Başlık + input veya seçim alanı
  Alt:    "DEVAM ET" (seçim yapılmadan disabled)

Hata state (inline, buton altında değil, input altında):
  Renk:   #FF4B4B
  Metin:  Yönlendirici — "Bu şehri tanımadık. Tekrar dener misin?"
          (Duolingo'da: "Weird! We couldn't find that place.")
  Konum:  Input'un hemen altında, kırmızı küçük metin
```

**Vird hatim kurulum adımları bu şablonla:**
1. "Arapça mı, Meal mi?" → seçim kartları
2. "Günde ne kadar okumak istiyorsun?" → seçim kartları
3. "Hatim adı ver (opsiyonel)" → text input
4. Başarı ekranı → logo + "Hatim başladı!" + "BAŞLA"

---

### 16.2 Chip Grid + Sayaç (Çoklu Seçim)

Activities seçim ekranında: küçük pill chip'ler 3 sütun grid içinde, sol üstte "5/20" sayaç badge'i, seçilenler marka rengiyle vurgulanıyor.

**Vird'e uyarlama — Sure Streaki seçimi:**
```
Sure seçim ekranı:
  Layout:   Wrap grid (3 sütun değil, responsive wrap)
  Chip:     Sure adı, radius-full, 36dp yükseklik
  Seçilmemiş: #FFFFFF bg, #E5E5E5 border
  Seçilmiş:   #E8F5F7 bg, #2A7F8C border 2px, teal metin
  Sayaç:      "3 sure seçildi" — sol üstte, Body Medium, #777
  Max:        Sınır yoksa sayaç gösterilmez
  Buton:      "DEVAM ET" — en az 1 seçilince aktif
```

---

### 16.3 Geri Sayım Sayacı — Üst Bar'da Dinamik Metrik

Trip aktifken Duolingo'nun üst barında streak/gems yanına "91" günlük geri sayım ekleniyor. Bu pattern Vird için çok güçlü:

**Vird'e uyarlama:**
```
Özel dönem aktifken üst bar (4. slot):
  Ramazan:  🌙 27 (Ramazan'a kalan gün)
  Cuma:     📅 2 (Cumaya kalan gün — Perşembe/Çarşamba'dan itibaren)
  Özel hedef: ⏱ 5 (hedefe kalan gün)

  İkon rengi: #2A7F8C (teal) — anlam sabit değilse
  Ramazan ikonu rengi: #FFC200 (altın) — kutsal dönem
  Normal günlerde bu slot gösterilmez
```

---

### 16.4 Kademeli Bildirim Serisi (Countdown Notifications)

Duolingo trip yaklaştıkça bildirim yoğunluğunu artırıyor: "10 gün → 5 gün → 3 gün → 1 gün kaldı." Her bildirim farklı aciliyet tonu taşıyor.

**Vird'e uyarlama — Cuma liderboard kapanışı:**
```
Cuma bildirim serisi:
  Çarşamba akşamı:  "Bu hafta 3. sıradasın 🔥 Cuma'ya 2 gün kaldı."
  Perşembe öğlen:   "Sıralaman tehlikede! Cuma'ya 1 gün kaldı."
  Cuma 10:00:       "Son 3 saat! Sıralamana bak 🏆"
  Cuma 12:45:       "15 dakika kaldı — son şans!"

Ramazan countdown (ileride):
  15 gün önce: "Ramazan'a 15 gün kaldı. Hatimini hazırla!"
  7 gün önce:  "1 haftaya Ramazan! Hedefini belirle."
  1 gün önce:  "Yarın Ramazan başlıyor 🌙 Hazır mısın?"
```

---

### 16.5 Profil'de Yaklaşan Hedefler Kartı

Duolingo profilinde "Upcoming Trips" bölümü: her trip için gün sayısı büyük gösteriliyor, altında şehir adı.

**Vird'e uyarlama — Profil'de aktif hedefler:**
```
"Aktif Hedefler" bölümü (istatistiklerin altı):
  ┌──────────────────────────────┐
  │  🌙 Ramazan'a               │
  │     27 GÜN                  │
  │     Hazırlık hatimi aktif   │
  └──────────────────────────────┘

  Kart zemin:  Pastel (#FFF3CD Ramazan için, #E8F5F7 normal)
  Sayı:        Title Large, Bold, marka rengi
  Etiket:      Caption, #ABABAB
  Sadece aktif dönemde görünür; aksi hâlde bu bölüm gizlenir
```

---

### 16.6 İçerik Alaka Düzeyi = Bağlılık (Strateji İçgörüsü)

Duolingo'nun core insight'ı: *"Kullanıcılar öğrendikleri içeriğin kendi hayatlarıyla ilgili olduğunu hissederse çok daha sık geri döner."*

**Vird için bu ilke:**
- Kullanıcı "Cuma namazı sureleri" veya "Ramazan sure streaki" gibi **kişisel bağlamlı hedefler** koyabilmeli
- Sistem bunu önerebilir: *"Ramazan'a 30 gün kaldı — Teravih için Mülk ve Yasin sure streaki başlatmak ister misin?"*
- Bu UX prensibi ilerideki özellikler için temel motivasyon: **deadline + kişiselleşme = yüksek bağlılık**

---

### 16.7 Başarı / Onay Ekranı (Minimal)

Trip ekleme başarı ekranı çok minimal: sadece logo + kısa onay metni + tek buton. Beklenen büyük kutlama yok — bu kasıtlı.

**Vird'e uyarlama — Hatim ekleme başarı ekranı:**
```
↑ Büyük whitespace
↑ Vird logosu — ortalanmış
↑ Başlık: "Hatim başladı!" (Display, teal)
↑ Alt metin: "İlk cüzünü okuyunca sana haber vereceğim." (Body Medium)
↑ Whitespace
↓ Teal primary buton "HARIKA"

NOT: Bu ekranda stat kartı yok — hatim tamamlama değil, başlangıç.
     Kutlama ölçülü tutulur; asıl kutlama hatim bitişinde.
```

---

## 17. Duolingo Analiz Notları — 4. Tur (Slide 6–7)

*Phase 2 Trip Lessons tamamlama + Phase 3 Translator detay UI akışlarından Vird'e uyarlamalar.*

---

### 17.1 Haftalık Tamamlama Grid'i (Weekday Tracker)

Trip lesson tamamlama ekranında "Bu hafta kaç gün tamamladın" bilgisi küçük hücre grid'i ile gösteriliyor: `Fr Sa Su Mo Tu We Th` — tamamlanan gün dolu, yapılmayan boş.

**Vird'e uyarlama — Streak takvimi bileşenini güçlendirme:**
```
Haftalık okuma grid'i (Hatimlerim üst kısmı):
  7 daire, yatay: Pzt Sal Çar Per Cum Cmt Paz
  Tamamlanan:       #2A7F8C dolu daire, beyaz harf
  Bugün (yapılmadı): #E5E5E5 kenarlı daire, boş
  Geçti (kaçırıldı): #E5E5E5 dolu daire, gri
  Freeze:           ❄️ ikonu, #1CB0F6

  Altında küçük metin: "Bu hafta 5 gün okudun 🔥" (Caption, #777)
```
Bu Bölüm 6.9'daki streak takvimini tamamlıyor — haftalık motivasyon sayacı olarak kullanılabilir.

---

### 17.2 Geçmiş Log Listesi — Otomatik Başlık + Zaman Damgası

Translator geçmişinde her konuşma otomatik başlık alıyor ve timestamp ile listeleniyor. Avatar sol tarafta.

**Vird'e uyarlama — "Son Okumalar" log listesi:**
```
Her log satırı:
  Sol:      Sure ikonu veya hatim renk noktası (40dp)
  Başlık:   Otomatik: "Bakara 1-5, Yasin" veya "23. Cüz · 15 sayfa"
            (Body Large, Bold, #3C3C3C)
  Alt metin: "Bugün 14:35 · +150 ✨" (Caption, #ABABAB)
  Sağ:      Chevron (>), #ABABAB

  Ayraç:    İnce #E5E5E5 çizgi (border değil, divider)
  Tap:      Log detayına açılır
```

---

### 17.3 Konuşma/Chat Balonları Arayüzü

Translator'da mesaj → çeviri alt alta aynı balon içinde gösteriliyor. Bilinmeyen kelimeler vurgulanıyor. "Translating..." inline loading state var.

**Vird'e uyarlama — Arapça/Meal çift görünüm (ilerideki Kuran okuma özelliği için):**
```
Ayet gösterim kartı (uygulama içi okuma eklenirse):
  Arapça metin:  Sağa hizalı, Scheherazade New, 18sp
  Çizgi:         İnce #E5E5E5 ayraç
  Meal metni:    Sola hizalı, Nunito Regular, 14sp, #777777
  Vurgulanan kelime: #E8F5F7 bg, #2A7F8C underline

  Loading (meal yüklenirken): satır bazlı shimmer, 2 satır
```

---

### 17.4 İkili Seçim + Max Sayaç Badge'i

Dil seçiminde max 2 seçim, sağ üstte "2/2" badge'i gösteriliyor. Max dolunca diğer seçenekler disabled.

**Vird'e uyarlama — Aktif hatim limiti göstergesi:**
```
Hatim ekleme ekranında üst sağ köşe:
  Normal:   "1/2 aktif hatim" (Label, #2A7F8C)
  Dolu:     "2/2 aktif hatim" (Label, #FF4B4B)
            Alt metin: "Yeni hatim eklemek için birini tamamla veya sil"

Seçim listesinde limit dolunca:
  Diğer seçenekler: #ABABAB metin, #F7F7F7 bg, tıklanamaz
```

---

### 17.5 Yeni Özellik Discovery Kartı

"What Could Be Next?" bölümünde önerildi: yeni özellik çıkınca kullanıcı bir sonraki girişte discovery card görür.

**Vird'e uyarlama — Yeni özellik duyuru kartı (Hatimlerim üstü):**
```
Discovery banner (dismiss edilene kadar gösterilir):
  Zemin:    #E8F5F7 (teal açık)
  Sol:      ✨ ikon (24dp, #2A7F8C)
  Metin:    "Yeni: Sure Streaki özelliği eklendi!" (Body Medium, Bold)
  Sağ:      X kapat ikonu (20dp, #ABABAB)
  Border:   1.5px solid #2A7F8C, radius-lg
  Konum:    Üst bar'ın hemen altı, full-width (16px margin)
  Davranış: Dismiss sonrası bir daha gösterilmez
```

---

### 17.6 Offline / İndirilen İçerik Ekranı

"Download Trip Lessons — Learn on the plane" ekranı: özel offline mod göstergesi, normal yol görünümü ama indirilen dersler vurgulanmış.

**Vird'e uyarlama — Offline okuma modu (zaten planlı, görsel detay):**
```
Offline durumunda Hatimlerim ekranı üstü:
  Banner:   "Çevrimdışı mod — okumalar kaydediliyor" 
            (#FFF3CD bg, #FFC200 border, ⚡ ikon)
  Cüz yolu: Normal görünüm, tüm düğmeler aktif
  Kayıt:    Log girilince yerel kaydedildi ikonu (küçük ☁️ ile çizgi)
  Sync:     Bağlantı gelince "Senkronize ediliyor..." inline banner
```

---

## 18. Duolingo Analiz Notları — 5. Tur (Streak Progress, Where to Start, User Journey Steps)

*Son 3 PDF: Streak commitment ekranı ve onboarding başlangıç seçimi.*

---

### 18.1 Streak Commitment Ekranı

Streek Progress PDF'i özel bir ekran gösteriyor: streak sayısı ekranın odak noktası, haftalık grid alt kısımda, altta taahhüt butonu. Tek renkli ekran — her şey turuncu.

**Vird'e uyarlama — "Streak Sözü" ekranı (ilk streak kurulunca veya repair sonrası):**
```
↑ Büyük whitespace
↑ Büyük alev ikonu — ortalanmış, 96dp, pill gölge altında
↑ Streak sayısı: Display (28sp → 48sp'ye çıkarılabilir), #FF9600
↑ "günlük streak" (Body Medium, #FF9600)
↑ Haftalık grid kartı (radius-lg, border #E5E5E5):
    Üst bölge: 7 daire — tamamlanan ✓ turuncu dolu, 
               gelecek günler #E5E5E5 boş
    Alt bölge: "Her gün oku, streak'in korunsun." 
               (Body Medium, #777, ortalı)
↓ Teal primary buton "DEVAM EDECEĞİM"

Tek renk prensip: ikon + sayı + etiket + grid checkmark → hepsi #FF9600
```

---

### 18.2 Haftalık Grid Kartı — İki Bölgeli Yapı

Streek Progress'te haftalık grid kartının içi ikiye bölünmüş: üst yarı = gün daireleri, alt yarı = motivasyon metni. Aralarında ince divider.

**Vird'e uyarlama — Hatimlerim ekranı streak widget'ı:**
```
Streak widget kartı (Hatimlerim üstü):
  ┌─────────────────────────────────┐
  │  Pzt  Sal  Çar  Per  Cum  Cmt  Paz  │
  │  🟠   🟠   🟠   🟠   🟠   ○    ○   │
  ├─────────────────────────────────┤
  │  Harika! 5 gün üst üste okudun. │
  └─────────────────────────────────┘
  
  Tamamlanan: #FF9600 dolu daire, beyaz ✓
  Bugün (yapılmış): #FF9600 + mavi ✓ (freeze varsa ❄️)
  Gelecek: #E5E5E5 boş
  Alt metin: motivasyon veya uyarı — duruma göre:
    Normal:   "Harika! X gün üst üste okudun."
    Tehlike:  "Bugün okumayı unutma! ⚠️"
    Freeze:   "Dondurma hakkın kullanıldı. ❄️"
```

---

### 18.3 Onboarding Başlangıç Seçimi — Zengin Kart Formatı

"Where to start" ekranında seçim kartları sadece başlık değil, **ikon + bold başlık + açıklama alt metni** içeriyor.

**Vird'e uyarlama — Hatim başlangıç seçimi:**
```
Üstte konuşma balonu: "Nereden başlamak istersin?"

Zengin seçim kartı formatı:
  ┌──────────────────────────────────────┐
  │  [📖 ikon 48dp]  Baştan Başla        │
  │                  1. Cüz'den itibaren │
  └──────────────────────────────────────┘
  ┌──────────────────────────────────────┐
  │  [🔖 ikon 48dp]  Kaldığım Yerden    │
  │                  Sayfa numarası gir  │
  └──────────────────────────────────────┘

  İkon: 48dp kare, radius-md, renkli bg (pastel)
  Başlık: Body Large, Bold, #3C3C3C
  Alt metin: Body Medium, Regular, #777777
  Kart yüksekliği: 72dp (daha yüksek — iki satır metin için)
  Seçilince: border #2A7F8C 2px, bg #E8F5F7
```

---

### 18.4 Splash / Onboarding Görsel Dili (User Journey Steps)

User Journey Steps PDF'inde Duo kitap okurken teal-yeşil degrade arka plan üzerinde gösteriliyor. Dünya ikonu flat design, yeşil+mavi pastel.

**Vird splash/onboarding görsel dili:**
```
Splash ekranı arka planı: #2A7F8C düz (degrade yok — daha sade)
Logo: beyaz versiyon, ortalanmış

Onboarding hero görseli renk paleti (illüstrasyon için):
  Zemin:   #2A7F8C (teal)
  Vurgu:   #FFC200 (altın) — kitap, yıldız, ay gibi öğelerde
  Nesne:   Beyaz outline + teal içi
  Gölge:   Pastel (#B8DFE4), nesnenin altında pill şeklinde

```

---

## 19. Duolingo Resmi Design Token Analizi

*Duolingo'nun web sitesinden çekilen gerçek design token'ları — Vird tasarım sistemi ile karşılaştırma ve doğrulama.*

---

### 19.1 Token Karşılaştırma Tablosu

| Alan | Duolingo Token | Duolingo Değer | Vird Değer | Durum |
|---|---|---|---|---|
| Ana metin rengi | `color.text.primary` | `#3c3c3c` | `#3C3C3C` | ✅ Birebir örtüşüyor |
| Pasif metin | `color.text.tertiary` | `#afafaf` | `#ABABAB` | ✅ Neredeyse aynı |
| Yüzey (zemin) | `color.surface.muted` | `#ffffff` | `#FFFFFF` | ✅ Örtüşüyor |
| Radius küçük | `radius.xs` | `12px` | `radius-md: 12px` | ✅ Birebir örtüşüyor |
| Radius orta | `radius.sm` | `16px` | `radius-lg: 16px` | ✅ Birebir örtüşüyor |
| Temel boşluk | `space.1` | `8px` | `space-sm: 8px` | ✅ Örtüşüyor |
| Standart padding | `space.6` | `16px` | `space-md: 16px` | ✅ Örtüşüyor |
| Anlık animasyon | `motion.duration.instant` | `200ms` | Buton press: 100ms | ⚠️ Vird daha hızlı |
| Ana font | `din-round` | Geometrik yuvarlak | Nunito | ✅ Doğru analog |
| Temel font boyutu | `font.size.base` | `17px` | Body Large: 16sp | ✅ Yakın |
| Satır yüksekliği | `font.lineHeight.base` | `20px / 17px = 1.18x` | `1.4x` | ℹ️ Vird daha okunaklı (Arapça için doğru) |

---

### 19.2 Doğrulanan Tasarım Kararları

Duolingo'nun resmi token'ları şu Vird kararlarını **resmi olarak doğruluyor**:

- **#3C3C3C** ana metin rengi — Duolingo ile birebir aynı, kesinleşti
- **12px ve 16px** radius değerleri — Duolingo'nun tam değerleri, Vird'de doğru seçim
- **8px** spacing taban birimi — Duolingo da aynı taban kullanıyor
- **Nunito** font seçimi — din-round ile aynı karakter: geometrik, yuvarlak, modern

---

### 19.3 Vird'e Yeni Eklenen Kurallar

**Erişilebilirlik hedefi (token verisinden):**
```
Vird WCAG 2.2 AA standardını hedeflemeli:
  - Metin kontrast oranı: min 4.5:1 (normal metin)
  - Büyük metin kontrast: min 3:1 (18sp+ veya 14sp Bold+)
  - Focus indicator: tüm dokunmatik/tıklanabilir elemanlarda görünür
  - Dokunma hedefi: min 48×48dp (Flutter Material standard)

Kontrol:
  #3C3C3C metin / #FFFFFF zemin = 12.6:1 ✅ (çok üstünde)
  #777777 metin / #FFFFFF zemin = 4.48:1 ✅ (sınırda — dikkat)
  #ABABAB metin / #FFFFFF zemin = 2.96:1 ❌ (yalnızca placeholder/disabled için)
```

**Bileşen durum zorunluluğu (token verisinden):**
Her interaktif bileşen şu 7 durumu tanımlamak zorunda:
```
default → hover/pressed → focus-visible → active → disabled → loading → error

Flutter'da karşılıkları:
  default:       normal render
  pressed:       InkWell onTap, translateY(+2px)
  focus-visible: FocusNode + border #2A7F8C 2px (klavye navigasyon)
  active:        seçili/açık state
  disabled:      opacity 0.4 veya #E5E5E5 bg + #ABABAB metin
  loading:       CircularProgressIndicator beyaz, buton boyutu korunur
  error:         #FF4B4B border/metin, #FFDFE0 bg
```

---

### 19.4 Spacing Token Güncelleme

Duolingo'nun spacing skalası daha granüler: 8, 10, 12, 13, 14, 16. Vird'de 8px atlamalı sistem var. Aradaki değerler gerekince şöyle kullanılabilir:

| Duolingo | Değer | Vird Karşılığı |
|---|---|---|
| space.1 | 8px | `space-sm` |
| space.2 | 10px | — (kullanılmıyor) |
| space.3 | 12px | `space-sm + 4` |
| space.4 | 13px | — (kullanılmıyor) |
| space.5 | 14px | — (kullanılmıyor) |
| space.6 | 16px | `space-md` |

**Kural:** Vird'de 8px taban sistemi korunur. 10/13/14px gibi ara değerler **kullanılmaz** — tutarlılık bozulur.

---

### 19.5 Tipografi Satır Yüksekliği Kararı

Duolingo `1.18x` satır yüksekliği kullanıyor (çok sıkı). Vird `1.4x` kullanıyor.

**Vird kararı kesinleşti: 1.4x korunur.** Sebep:
- Arapça metinlerde hareke (nokta/işaret) için ekstra dikey alan gerekir
- Türkçe'de uzun kelimeler için okunabilirlik artar
- 1.18x mobilde küçük ekranlarda sıkışık hissettiriyor

---

## 20. Henüz Netleşmemiş

- [ ] 5-6 renk paletinin tüm rolleri (şu an 2 ana renk + sistemik renkler tanımlı)
- [ ] Dark mode desteği (MVP'de yok, sonraki fazda)
- [ ] Arapça RTL layout kuralları (log girişi Arapça/Meal sekmesinde)
- [ ] Bildirim metinleri tam listesi (Bölüm 13 ton kurallarına göre yazılacak)

# Vird — Proje Durumu

> Neredeyiz? Ne öğrendik? Bu dosya her oturum başında okunur.

---

## Genel Durum (2026-05-15 — son güncelleme: DevPanel backlog iyileştirmeleri — sürükle-bırak, kategori izolasyonu, milestone sıralama)

- **Uygulama:** Günlük Kuran okuma takip uygulaması. Flutter + Firebase.
- **İlk kullanıcı grubu:** YTÜ Fark Kulübü (~40 kişi) — 1 haftalık beta test aşamasına hazır
- **Test ortamı:** Her zaman `flutter run -d chrome` — emülatör RAM sorunu nedeniyle kullanılmıyor
- **Git:** Ortak repo, herkes push yapıyor
- **Firestore kuralları:** Deploy edildi — `firebase deploy --only firestore:rules --project vird-fc834`
- **MVP öncesi kalan tek iş:** Liderboard dönemini günlük → haftalık çevirmek + son hata testleri
- **Web versiyonu:** https://vird-fc834.web.app — iOS dahil tüm cihazlardan erişilebilir
- **Özel alan adı:** Henüz bağlanmadı — Firebase Console > Hosting > Add custom domain

---

## Modül Tablosu

| # | Modül | Durum |
|---|-------|-------|
| 1 | Kurulum | ✅ Tamamlandı |
| 2 | Auth (Google + email, Firebase) | ✅ Tamamlandı |
| 3 | Kuran verisi entegrasyonu | ✅ Tamamlandı |
| 4 | Hatimlerim + Tamamlanan Hatimler + Isı Haritası | ✅ Tamamlandı |
| 5 | Log girişi (kilitleme modu + fazla sayfa uyarısı) | ✅ Tamamlandı |
| 6 | Seri sistemi | ⚠️ Kısmi (seri sayacı + takvim + animasyon ekranı ✅; freeze/repair/Cuma bonusu yok) |
| 7 | Sure serii | ⬜ |
| 8 | Hasanat sistemi | ✅ Tamamlandı |
| 9 | Kuran Haritası (UI ✅, veri bağlantısı ✅) | ✅ Tamamlandı |
| 10 | Offline mode | ✅ Tamamlandı (Firestore persistence) |
| 11 | Ekip sistemi (liste + profil + liderboard + admin silme + gizli gruplar) | ✅ Tamamlandı |
| 12 | Liderboard | ✅ Ekip içi günlük liderboard ✅ (haftalığa çevrilecek — MVP öncesi) |
| 13 | Profil (UI ✅, ısı haritası veri bağlantısı ✅) | ✅ Tamamlandı |
| 14 | Bildirimler | ⚠️ Kısmi (günlük akıllı bildirim ✅; seri tehlike / Cuma / ekip bildirimleri yok) |
| 15 | Rozetler | ⬜ |
| 16 | Vird sekmesi (UI + Firestore form) | ✅ Tamamlandı |
| 17 | Web versiyonu (Firebase Hosting) | ✅ Tamamlandı — https://vird-fc834.web.app |
| 18 | Günlük Takipler (namaz takibi + alışkanlık takibi) | ✅ Tamamlandı |

---

## Tamamlanan Modüller

### Oturum — DevPanel Backlog İyileştirmeleri (2026-05-15)

#### DevPanelScreen — Backlog Geliştirmeleri (`lib/screens/dev_panel_screen.dart`)

**Sürükle-bırak (Fikir sekmesi)**
- `_IdeaList`'e `_BugList` ile aynı gap-based `LongPressDraggable` sıralama eklendi
- `onReorder` callback → `_reorderInSection` → Firestore batch `order` güncelleme

**Kategori filtresi — tek satır yatay kaydırma**
- `Wrap` (çok satır) → `SizedBox(height: 34) + ListView(scrollDirection: Axis.horizontal)` dönüştürüldü
- "Tümü" başta, ayar ikonu sonda, arası yatay kaydırılabilir

**Milestone sıralama**
- Aktif milestone'lar: versiyon numarasına göre küçükten büyüğe (v1.6 → v2.0)
- Tamamlanan milestone'lar: büyükten küçüğe (en son sürüm üstte)
- `_cmpVersion` yardımcı fonksiyonu eklendi — `v1.1.5` gibi çok parçalı versiyonları doğru karşılaştırır

**Kategori izolasyonu (sekme başına bağımsız)**
- Plan / Bug / Fikir sekmelerinin kategorileri artık birbirinden tamamen bağımsız
- `_CatManagerSheet`'e `type` parametresi eklendi — yükleme, rename, silme işlemleri yalnızca o sekmenin tipini etkiliyor
- `existingCats` önerisi ve FAB'daki kategori listesi de `tabItems`'dan türetiliyor

---

### Oturum — DevPanel Feedback Klasör Sistemi + Bug Düzeltmeleri (2026-05-14)

#### DevPanelScreen — 3 Kritik Bug Düzeltmesi + Feedback Klasör Sistemi (`lib/screens/dev_panel_screen.dart`)

**Bug 1: Backlog kartları render crash (border + borderRadius uyumsuzluğu)**

- Flutter kısıtı: `BoxDecoration`'da `borderRadius` + farklı kenarlara farklı renkler (`Border(left: renkA, top: renkB, ...)`) → `A borderRadius can only be given on borders with uniform colors` assertion crash
- Kartlar doğru verilere sahipti ama sessizce render edilemiyordu — toggle çalışıyordu, veri geliyordu, ama ekranda hiçbir şey görünmüyordu
- **Düzeltme:** `Border.all(color: AppColors.borderGrey)` (uniform) + `ClipRRect` + `IntrinsicHeight` + `crossAxisAlignment: CrossAxisAlignment.stretch` + sol aksan rengi ayrı `Container(width: 3, color: priorityColor)` child olarak eklendi

**Bug 2: Silinmiş milestone'a bağlı kartlar kayboluyordu (orphaned foreign key)**

- `_buildRows()` aktif milestone'ların altına veya `milestoneId == null/empty` grubuna eklerdi
- Silinmiş bir milestone'a ait `milestoneId` olan item'lar her iki gruptan da dışarıda kalıyordu → `openCount` sayımına katılıyor ama hiçbir yerde gösterilmiyordu
- **Düzeltme:** `assignedToActive` set ile check — aktif milestone'larda bulunmayan `milestoneId`'li item'lar da "Milestone'suz" grubuna eklendi

**Bug 3: FeedbackView composite index hatası**

- `where('archived', isEqualTo: false).orderBy('createdAt')` farklı alanda index gerektiriyordu → sessiz boş sonuç
- `HomeView` badge'i: `where('archived', isEqualTo: false)` `archived` alanı hiç olmayan eski doc'ları atlıyordu
- **Düzeltme:** İki yerde de `.snapshots()` ile tümünü çek, client-side filtrele + sırala

#### Feedback Klasör (Label) Sistemi

Yeni `feedback_labels` Firestore koleksiyonu. `feature_requests` doc'larına `folderId` alanı eklendi.

**Veri modeli:**
```
feedback_labels/{labelId}
  name: string
  colorHex: string (ör. '#FF6B6B')

feature_requests/{requestId}
  folderId: string?   (null = Gelen Kutusu)
```

**Inbox mantığı:** `folderId == null || folderId.isEmpty` → Gelen Kutusu. Klasöre taşınınca Gelen Kutusu'ndan kalkar.

**UI bileşenleri:**
- `_FeedbackViewState`: sol sidebar (Gelen Kutusu / Tümü / klasörler), StreamSubscription tabanlı
- `_FeedbackCard`: genişletilmiş görünümde klasör atama (chip row), dar görünümde klasör chip badge
- `_LabelManagerSheet`: klasör listesi + renk gösterimi, silme
- `_NewLabelSheet`: isim + 8 renk paleti (`#FF6B6B, #FF9600, #FFD166, #58CC02, #2A7F8C, #1CB0F6, #9B59B6, #FF69B4`)

**Firestore kuralları güncellendi (`firestore.rules`):**
```
match /feedback_labels/{labelId} {
  allow read, write: if isAuth();
}
```

---

### Oturum — Seri Animasyonu + Auth + Geçmiş Sıralamalar + Avatar Baş Harf (2026-05-11)

#### Seri Animasyonu Bug Düzeltmeleri (`log_entry_bottom_sheet.dart`, `seri_calculator.dart`)

**3 kök neden bulunup düzeltildi:**

1. **Firestore composite index hatası** — `_getWeekFilled`, `whereIn('type', [...])` + `createdAt` range filter kombinasyonu kullandığından `[cloud_firestore/failed-precondition]` hatası veriyordu. `whereIn` Firestore'dan kaldırıldı, client-side tip filtresi eklendi.
2. **`Navigator.pop` hiç çağrılmıyor** — `_getWeekFilled` await, `Navigator.pop`'tan önce geliyordu. Exception olunca sheet açık kalıyordu. `_getWeekFilled` ayrı try-catch bloğuna alındı; hata sadece animasyonu atlar, sheet her durumda kapanır.
3. **`recalculate()` namaz/alışkanlık loglarını sayıyordu** — `seri_calculator.dart`'ta Quran log filtresi yoktu. `type == 'arapca' || type == 'meal'` client-side filtresi eklendi.

#### Auth Düzeltmeleri

**Google Sign-In (`auth_service.dart`):**
- Yeni kullanıcı Firestore yazısı try-catch içine alındı. Firestore hatası auth akışını engellemiyordu zaten, ama hata mesajı olmadan sessizce geçiyordu. Artık `debugPrint` ile loglanıyor.

**Kayıt Ekranı (`register_screen.dart`):**
- Auth ve Firestore profil yazısı ayrı try-catch bloklarına ayrıldı. Auth başarısız → hata göster, ekranda kal. Auth başarılı + Firestore başarısız → sadece `debugPrint`, `ProfileSetupScreen`'e geç.
- `unauthorized-domain` ve `popup-blocked` hata kodları için Türkçe mesajlar eklendi. Varsayılan hata artık error code'u da gösteriyor.

**Giriş Ekranı (`login_screen.dart`):**
- Aynı ek hata kodları (`unauthorized-domain`, `popup-blocked`, daha açıklayıcı default) eklendi.

#### Geçmiş Sıralamalar Yeniden Tasarımı (`ekip_gecmis_screen.dart`)

Sade ListTile tabanlı yapıdan liderboard ile özdeş görsel stile tam geçiş:

- **`_GecmisWeekCard`** (StatefulWidget): Her hafta için ayrı `_showLow` filtre state'i. ExpansionTile ile açılıp kapanıyor. İlk hafta `initiallyExpanded: true`.
- **`_GecmisRow`** (StatelessWidget): Liderboard satırıyla birebir aynı renk mantığı:
  - `isDeepRed`: filtredeyken hasanat == 0 → `errorRed` alpha 0.48
  - `isRed`: kırmızı bölge (son 3) veya filtre aktif
  - `isTop`: filtre yokken ilk 3 → yeşil arka plan + 🥇🥈🥉
  - DiceBear avatar, gold hasanat gösterimi
- **`_FilterChip`**: ⚠️ <100 Puan toggle — filtre aktifken "X / Y kişi" subtitle'ı
- "Herkes bu hafta 100 puanı aştı 🎉" boş durum mesajı
- Satıra tıklama → `KullaniciProfilScreen`

#### Avatar Baş Harf Sistemi (`lib/utils/name_utils.dart`)

**Yeni paylaşılan utility fonksiyon:**
```dart
String nameInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length >= 2 && parts[1].isNotEmpty) {
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
  return name.isEmpty ? '?' : name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
}
```

**5 dosyada güncellendi:** `profil_screen.dart`, `kullanici_profil_screen.dart`, `ekip_profil_screen.dart` (2 yer), `ekip_gecmis_screen.dart`

| Örnek | Eskisi | Yenisi |
|---|---|---|
| "Affan Buğra" | AF (ya da A) | AB |
| "Affan Buğra Özaytaş" | AF (ya da A) | AB |
| "Mustafa" (tek kelime) | M | MU |

#### Ekip Sıralamalarında Username Kaldırıldı

`_LeaderboardRow` (`ekip_profil_screen.dart`) ve `_GecmisRow` (`ekip_gecmis_screen.dart`) içindeki `@username` gösterimi kaldırıldı. `_RequestRow` (üyelik istekleri paneli) değişmedi.

---

### Oturum — Seri + Ekip Bug Düzeltmeleri, Web Deploy (2026-05-10)

#### Seri Sistemi — Kapsamlı Düzeltmeler (`fire_bugs` branch → main)

**Düzeltilen 9 temel bug (`lib/widgets/log_entry_bottom_sheet.dart`, `lib/utils/seri_calculator.dart`, `lib/screens/streak_animation_screen.dart`, `lib/screens/ekip_profil_screen.dart`):**
1. Log kaydında `displayedSeri` yerine raw Firestore seri kullanılıyordu → `seriDisplayState()` ile düzeltildi
2. Seri animasyonu yanlış `prevCount` ile açılıyordu
3. `shouldShowAnimation` yanlış koşulda tetikleniyordu
4. Liderboard seri durumu donmuş Firestore değerini gösteriyordu (atRisk eksikti)
5. Haftalık takvim gün etiketleri sabit Monday-based yerine son 7 gün mantığındaydı
6. `_getWeekFilled` log type filtresi yoktu (prayer/habit logları sayılıyordu)
7. Timestamp `.toLocal()` eksikti (UTC+3 timezone hatası)
8. Log silinince seri yeniden hesabı animasyonu göstermiyordu
9. Liderboard arşivi aynı session'da birden fazla çalışıyordu

**Ek düzeltmeler (aynı oturumda):**
- **`_InviteCodeSheet` developer desteği (`lib/screens/ekipler_screen.dart`):** Developer davet koduyla katılınca `teamId` yerine `developerTeamIds: arrayUnion` yazılıyor; "zaten ekiptesin" kontrolü developer için atlanıyor
- **Başkasının profilinde seri durumu eksikti (`lib/screens/kullanici_profil_screen.dart`):** `lastLogDate` okunup `seriDisplayState()` çağrılmıyordu. Artık kendi profilindeki gibi kırmızı + "TEHLİKEDE" etiketi gösteriliyor
- **Liderboard seri dinamik güncellenmiyordu (`lib/screens/ekip_profil_screen.dart`):** `_MemberEntry` artık `rawSeri` + `lastLogTs` saklıyor; `_LeaderboardRow.build()` her render'da `seriDisplayState()` çağırıyor — ekran açık kalsa da gece yarısı seri otomatik düşüyor

#### Liderboard <100 Puan Filtresi (`ekip_profil_screen.dart`)
- Chip satırında "⚠️ <100 Puan" toggle butonu eklendi (kırmızı, sağ tarafta)
- Filtre açılınca otomatik "Puan" sıralamasına geçer; seri ile aynı anda çalışmaz
- Filtre aktifken ilk 3 yeşil arka plan kaldırılır — liste tamamen kırmızı
- **0 puan:** koyu kırmızı arka plan (alpha 0.48) + güçlü border (alpha 0.85)
- **1–99 puan:** açık pembe arka plan (`errorBg`) + hafif border — görsel kontrast belirgin
- Sayaç filtre açıkken "X / Y kişi" formatında gösterilir

#### Firestore Şeması Notu
- `developerTeamIds: List<String>` alanı olan developer kullanıcılar `teamId` ile aynı anda birden fazla ekipte bulunabilir
- Liderboard her iki alanı da sorgular ve deduplication yapar

---

### Oturum — Seri Animasyonu + DevPanel Arşiv + Web Deploy (2026-05-09)

#### StreakAnimationScreen (`lib/screens/streak_animation_screen.dart`) — YENİ DOSYA

Duolingo tarzı seri kutlama ekranı. Log kaydedilip seri artınca otomatik açılır.

**Animasyon katmanları (7 AnimationController):**
- `_intro` (2200ms): halo → gölge → alev gövdesi (TweenSequence elasticOut) → whip arkleri (4 adet, PathMetrics dash) → kıvılcımlar → motivasyon metni → CTA butonu
- `_breathe`, `_bodyBreath`, `_midFlick`, `_coreFlick`, `_shadowCtrl`: 1700ms sonra başlayan idle döngüler
- `_particles`: sürekli dönen parçacık sistemi

**_FlamePainter (CustomPainter):**
- Alev gövdesi: `cubicTo` ile el çizimi SVG path; canvas.translate + scale ile viewBox uyumu
- Arc whip'ler: `PathMetrics.extractPath(start, end)` ile kayan çizgi animasyonu
- Kıvılcımlar: polar koordinatlardan spiral dağılım
- `transform-origin bottom` davranışı: `translate(0,80) → scale → translate(0,-80)` ile

**_DayRow:**
- Label row + 38px Stack (circle area) ayrımı → pill hizası sorunu çözüldü
- Pill: `top:2, bottom:2` = 34px, daireler `top:4` = 30px (pill dairelerin 2px çevresini sarar)
- Token: `tokenBase=7.0` (circle center = 4+15=19, token=24 → top=7)
- Parabolic arc: `4t(1-t)*-20px` (token yayında yükselip iner)
- Elastic spring pill: `Cubic(0.34, 1.2, 0.4, 1)` ile sadece bugünün katkısı animasyonlu genişler
- Senkronize handoff: token t=0.75'te (525ms) söner, checkmark 520ms'de patlar
- Gap senaryosu: prevFilled != todayIndex-1 → bağımsız yeni pill, token uzaktan kayar

**Mesaj sistemi:**
- `_kMessages` — Dart record türü `(min, max, msgs)` ile 5 aralık
- `{X}` placeholder `replaceAll` ile streak sayısıyla değiştirilir
- `_getMotivation(count)` dönem hesabı yapar

**Entegrasyon (`log_entry_bottom_sheet.dart`):**
- `_getWeekFilled(uid)` — Firestore'dan haftanın log günlerini çeker (Pzt başlangıçlı)
- `_saveLog()` içinde `streakIncreased = seriUpdate.containsKey('seri')` kontrolü
- rootNavigator ile sheet kapandıktan sonra `addPostFrameCallback` ile açılır

**Layout:**
- Motivasyon metni: iki `Spacer()` arasında — takvim ile buton tam ortasında

#### DevPanel Arşiv Görünümü (`lib/screens/dev_panel_screen.dart`)

- `_ArchiveView` StatefulWidget eklendi: BUGS/TO-DO sekmeleri, `archived == true` filtreli StreamBuilder
- Sol swipe ile silme (`Dismissible`), unarchive butonu (teal, `Icons.unarchive_outlined`)
- Yeni item oluşturulurken `'archived': false` alanı eklendi

#### Web Deploy
- `flutter build web --release` → `build/web/` (29.5s, 41 dosya)
- `firebase deploy --only hosting` → https://vird-fc834.web.app
- Node `npx-cli.js` ile çalıştırıldı (PS execution policy bypass)

---

### Oturum — isDeveloper Sistemi + Seri Bug Düzeltmeleri + Profil Header (2026-05-09)

#### isDeveloper Sistemi (commit 456f7dc)

- **`lib/providers/user_provider.dart`** — Yeni `UserProvider` eklendi. `isDeveloper: bool` ve `developerTeamIds: List<String>` alanları user doc'tan okunur.
- **`lib/main.dart`** — `UserProvider` `MultiProvider`'a eklendi.
- **Profil ekranı (`profil_screen.dart`)** — Kullanıcı `isDeveloper: true` ise `DEV` badge'i profil başlığında gösterilir.
- **Liderboard (`ekip_profil_screen.dart`)** — `developerTeamIds` alanına sahip developer kullanıcılar, kendi `teamId`'lerinden farklı ekiplerin liderboardunda da görünebilir.
- **Vird sekmesi (`vird_screen.dart`)** — Yol haritası listesinin alt kısmı giderek solar (fade efekti); Ramazan kartı ~0.08 opaklıkta.

#### Seri Sistemi — 5 Bug Düzeltmesi (commit f0deef9)

**Kök sorunlar:**
1. `recalculate()` bugün log yokken çağrılınca seri=0 veriyordu (bugünden geriye sayıyor, bugün yoksa hemen duruyordu).
2. `deleteAllLogs` prayer/habit/tilavet_secde loglarını da siliyordu.
3. `seriDisplayState()` `stored==0` iken atRisk hesabı yapıyordu.
4. Migration path: `lastLogDate==null` olan kullanıcılarda seri her zaman 1'e sıfırlanıyordu.
5. Liderboard'da saklanan ham seri değeri gösteriliyordu — `seriDisplayState()` uygulanmıyordu.

**Düzeltmeler:**

- **`utils/seri_calculator.dart` — `seriDisplayState()`**: `stored==0` iken erken `(value:0, atRisk:false)` döndürme eklendi.
- **`utils/seri_calculator.dart` — `recalculate()`**: Anchor-day algoritması. Önce en son log günü bulunur (bugünden geriye tarama), ardından o anchor'dan geriye ardışık günler sayılır. Bugün log olmasa bile dünkü log anchor alınır, seri korunur.
- **`widgets/log_history_sheet.dart` — `_deleteAllLogs()`**: Sadece `type=='arapca'` veya `type=='meal'` olan loglar silinir. Prayer/habit/tilavet_secde loglarına dokunulmaz.
- **`widgets/log_entry_bottom_sheet.dart` — migration path**: `lastLogDate==null && hadLogYesterday` durumunda batch'e seri yazmak yerine `SeriCalculator.recalculate()` çağrılır. Multi-day seri doğru hesaplanır.
- **`screens/ekip_profil_screen.dart` — liderboard**: `_loadLeaderboard`'da ham `seri` değerine `seriDisplayState(rawSeri, lastLogTs)` uygulandı. Stale Firestore değerleri görüntüde gerçek zamanlı düzeltilir.

#### Profil Header Yeniden Tasarımı

- **Ayarlar butonu** banner sağ üstünden (`Positioned(top:10, right:12)`) → **banner sağ altına** (`Positioned(bottom:8, right:12)`) taşındı.
- **Vird logosu butonu** ayarların soluna eklendi (`v_logo.png`, `color: Colors.white, colorBlendMode: BlendMode.srcIn`).
- Her iki buton aynı stil: `BoxShape.circle`, `Colors.white.withValues(alpha:0.18)` zemin, `padding: 7`, ikon/logo boyutu `19`.
- `Image.asset(color:, colorBlendMode:)` kullanıldı — `ColorFiltered` PNG'de offscreen layer yaratarak beyaz arka plan gösteriyordu.
- Info satırındaki pill kapsayıcı kaldırıldı.

---

### Oturum — VirdScreen + Liderboard Son Güncellemeler (2026-05-08)

#### VirdScreen Konumu (`profil_screen.dart`)
- **VirdScreen** Ayarlar sheet'inden çıkarıldı
- Profil header'ında isim hizasında **sağ tarafa Vird logosu** (`vird_logo_seffaf.png`, 38dp) eklendi
- Tıklayınca aynı `showModalBottomSheet` açılışı devam ediyor
- `_ProfileHeader`'a `onVirdTap: VoidCallback` parametresi eklendi

#### VirdScreen Yol Haritası (`vird_screen.dart`)
- **4 yeni "Yayında ✓" kart:** Tilavet Secdesi Takibi, Namaz ve Alışkanlık Takibi (su damlası ikonu), Seri ve Ekip Güncellemeleri (kupa ikonu)
- **"Namaz Takibi"** eski ayrı kartı kaldırıldı (Namaz ve Alışkanlık Takibi kartına dahil edildi)
- **Başlık:** "Yakında geliyor" → "Neler geldi, neler geliyor"
- **Ana önizleme:** 4 kart full opacity (hepsi yayında)
- **Tam listede opacity:** Son 5 kart giderek solar; Ramazan kartı ~0.08 (neredeyse beyaz)
- `_iconFromName`'e `water_drop` → `Icons.water_drop` eklendi

#### Haftalık Ekip Sıralaması (`ekip_profil_screen.dart`)
- Başlık "Günlük Liderboard" → "Haftalık Ekip Sıralaması" olarak güncellendi
- Sıralamanın altına Âl-i İmrân 114. ayet meali eklendi (italik, ortalı)

---

### Oturum — Nav Yeniden Yapılandırma + Liderboard + Seri Düzeltmeleri (2026-05-08)

#### Navigasyon Değişiklikleri (`main.dart`, `profil_screen.dart`)
- **VirdScreen** nav tab'dan çıkarıldı → Ayarlar sheet'ine `showModalBottomSheet` olarak taşındı (diğer ayar maddeleriyle aynı yapıda)
- **GunlukTakiplerScreen** nav tab 2'ye "Alışkanlıklar" adıyla eklendi
- **İkon:** `Icons.water_drop_outlined` (pasif) / `Icons.water_drop` (aktif) — Vird logosundaki su damlasına referans
- `_NavItem`'dan `isVird` field'ı tamamen kaldırıldı

#### Hatim Isı Haritası Secde Düzeltmesi (`hatim_heat_map_sheet.dart`)
- Secde olmayan sayfalarda tap handler yoktu — düzeltildi: tüm sayfalar `onTap` alır
- Secde dialogu sadece **okunmuş** sayfalarda açılır (`hasSecde && isRead` kontrolü)

#### Seri Görüntüleme Düzeltmesi
- **`seriDisplayState()` fonksiyonu** (`utils/seri_calculator.dart`): Firestore'daki donmuş seri değerini `lastLogDate`'e göre gerçek duruma çevirir. Dün okunmuş bugün okunmamışsa `atRisk: true`, eski tarihte kalmışsa `value: 0` döner.
- **Profil ekranı:** `lastLogDate` okunur, `seriDisplayState()` hesaplanır; tehlikedeyse seri kırmızı + "TEHLİKEDE" etiketi
- **Hatimlerim ekranı:** Aynı mantık; seri kartına tap → `SeriCalendarSheet.show()` açılır

#### Liderboard Geçmiş Görünürlüğü (`ekip_gecmis_screen.dart`, `ekip_profil_screen.dart`)
- **Herkes** geçmiş haftanın sıralamasını görebilir (1 kayıt)
- **Ekip admini** tüm geçmiş haftaları görebilir (tüm kayıtlar)
- `isProAdmin` → `isAdmin` olarak yeniden adlandırıldı (tüm dosyalarda)
- **`teamJoinedAt`** Timestamp alanı eklendi — ekibe sonradan katılanlar eski haftalara dahil edilmez. 3 yerde yazılır: ekip kurma, davet koduyla katılma, admin onayı

#### Liderboard Puan/Seri Filtresi (`ekip_profil_screen.dart`)
- `_MemberEntry` modeline `seri: int` alanı eklendi; `_loadLeaderboard`'da `data['seri']` okunur
- `_LeaderboardSection` `StatefulWidget`'a dönüştürüldü; `_SortMode` enum (`puan` / `seri`)
- **Filtre chips:** "Puan" ve "🔥 Seri" — teal zemin seçili, animasyonlu geçiş
- **Sıralama:** Puan → hasanat desc + seri tiebreak; Seri → seri desc + hasanat tiebreak
- **Satırda seri gösterimi:** `🔥 X gün` seri > 0 olan üyelerin username satırında turuncu renkte

#### Ricâl-i FARK Ekip Logosu (`ekipler_screen.dart`, `app_assets.dart`)
- `_TeamCard._buildLogo()`: `logoAsset` değeri `'rical_i_fark'` ile başlıyorsa `AppAssets.ricalIFarkLogo` gösterilir
- Firebase Console'dan `teams/{teamId}` dokümanına `logoAsset: "rical_i_fark_logo"` yazılarak aktifleştirilir
- **Eşleşme robustluğu:** `.replaceAll('"', '').trim().startsWith('rical_i_fark')` — Console'dan tırnaklı yazılsa bile çalışır

---

### Modül 18 — Günlük Takipler (2026-05-08)

#### Dosyalar
- `lib/screens/gunluk_takipler_screen.dart` — Günlük Takipler ana ekranı (599 satır)
- `lib/widgets/habit_tracker_widget.dart` — Özel alışkanlık takip widget'ı (863 satır)
- `lib/widgets/habit_heat_map_sheet.dart` — Alışkanlık ısı haritası bottom sheet (353 satır)
- `lib/data/tilavet_secde.dart` — 14 tilavet secdesi sayfa verisi

#### Namaz Takibi (`GunlukTakiplerScreen`)
- **Durumlar:** `PrayerStatus` — `none`, `onTime`, `kaza`, `cemaat`
- **Vakitler:** `PrayerTime` — sabah, öğle, ikindi, akşam, yatsı
- **Görünüm:** `PageView` ile haftalık gezinme; geçmiş haftalara geri gidilebilir
- **Prefetch:** `initState`'te mevcut ve önceki haftanın verisi önceden yüklenir
- **Firestore:** `users/{uid}/logs/prayer_YYYY-MM-DD` dokümanına `set(merge: true)` ile yazar
- **Renk kodlaması:** `AppColors.successGreen` (vakinde), `AppColors.goldSoft` (kaza), `AppColors.tealSoft` (cemaat)

#### Alışkanlık Takibi (`HabitTrackerWidget`)
- **`HabitDef`:** id, title, color, createdAt — Firestore'da `users/{uid}/logs/habit_defs` dokümanına `items` array olarak yazılır
- **Log formatı:** `users/{uid}/logs/{YYYY-MM-DD}_{habitId}` dokümanlarına `completed: bool` yazılır
- **Son 30 günün logu** tek seferinde çekilir; date değişince lazily yüklenir
- **Seri hesabı:** Seçilen günden geriye sayarak ardışık tamamlanan günler hesaplanır
- **Isı haritası:** Her alışkanlığa tıklayınca `HabitHeatMapSheet.show()` açılır

#### Alışkanlık Isı Haritası (`HabitHeatMapSheet`)
- Yıllık görünüm (GitHub contribution graph tarzı)
- Binary renk: tamamlandı = alışkanlığa ait renk, tamamlanmadı = `AppColors.borderGrey`
- Metrikler: toplam tamamlama sayısı, mevcut seri, oluşturulma tarihi

#### Tilavet Secde Verisi (`TilavetSecdeData`)
- 14 tilavet secdesi sayfa numarası ve sure adı
- API: `hasSecde(page)`, `secdeLabel(page)`, `secdesInRange(startPage, endPage)`
- `hatim_calculator.dart`'ta secde dokümanlarını loglardan filtrelemeye yarar (`createdAt == null` kontrolüyle)

#### AppColors Yeni Renkler
- `tealSoft = Color(0xFF63A5AB)` — cemaat namazı rengi
- `goldSoft = Color(0xFFFFD166)` — kaza namazı rengi

#### Firestore Şeması (Günlük Takipler)
```
users/{uid}/logs/prayer_YYYY-MM-DD
  type: 'prayer'
  date: 'prayer_YYYY-MM-DD'
  prayers: {
    sabah: 'none' | 'onTime' | 'kaza' | 'cemaat'
    ogle:  'none' | 'onTime' | 'kaza' | 'cemaat'
    ikindi:'none' | 'onTime' | 'kaza' | 'cemaat'
    aksam: 'none' | 'onTime' | 'kaza' | 'cemaat'
    yatsi: 'none' | 'onTime' | 'kaza' | 'cemaat'
  }

users/{uid}/logs/habit_defs
  items: [{ id, title, color, createdAt }]

users/{uid}/logs/YYYY-MM-DD_{habitId}
  completed: bool
  date: 'YYYY-MM-DD'
  habitId: string
```

#### Firestore Güvenlik Kuralı (yeni)
- `daily_prayers/{dateStr}` koleksiyonu için `isOwner(userId)` kuralı eklendi

---

### Web Versiyonu — Firebase Hosting (2026-05-07)

- **URL:** https://vird-fc834.web.app
- **Build:** `flutter build web --release` → `build/web/` klasörüne çıkıyor
- **Deploy:** `npx firebase deploy --only hosting --token "$TOKEN"` — CI token ile çalışır
- **Config:** `firebase.json`'a `hosting` bloğu eklendi (`site: vird-fc834`, `public: build/web`, SPA rewrites)
- **`.firebaserc`:** proje ID `vird-fc834` olarak tanımlı
- **Auth:** Email/şifre + Google Sign-In web'de çalışıyor (`signInWithPopup` zaten vardı)
- **Özel alan adı:** Henüz eklenmedi — Firebase Console > Hosting > Add custom domain
- **Güncelleme:** Otomatik değil — her güncelleme için `flutter build web --release` + deploy çalıştırılmalı

---

### Faz 3 — Offline, Bildirim, Seri Takvimi, Ekip Yönetimi (2026-04-28)

#### Seri Sistemi İyileştirmeleri
- **Seri Takvimi (`seri_calendar_sheet.dart`):** Seriye tıklayınca aylık takvim açılır. Log girilen günler turuncu dolu daire, bugün turuncu çerçeveli daire, gelecek günler gri. Ay navigasyonu (← →) ile geriye gidilebilir; ileriye gidilemez.
- **Dinamik Seri Yeniden Hesabı (`utils/seri_calculator.dart`):** Log silinince `SeriCalculator.recalculate(uid)` çağrılır. Son 90 günün loglarını okur, bugünden geriye sayarak ardışık günleri hesaplar, `seri` ve `lastLogDate` alanlarını günceller. `log_history_sheet.dart` ve `hatim_heat_map_sheet.dart`'ta her silme işleminden sonra çağrılır.
- **Migration fix:** `lastLogDate == null` olan eski kullanıcılarda seri sıfırlanıyordu. Düzeltme: `lastLogDate == null` ise dünkü logları sorgulanarak mevcut seri korunur.

#### Offline Mode
- **Firestore Persistence:** `main.dart`'ta `FirebaseFirestore.instance.settings = Settings(persistenceEnabled: true, cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED)`. İnternet kesilince Firestore local cache'den okuma yapar, yazma işlemleri senkronize queue'ya alınır.

#### Akıllı Günlük Bildirim (`services/notification_service.dart`)
- `scheduleDaily(hour, minute)`: Kullanıcının seçtiği saatte her gün tekrar eden bildirim kurar.
- `cancelForToday()`: Log kaydedilince bugünkü bildirimi iptal eder ve yarından itibaren yeniden programlar — o gün okumuşsa bildirim gitmez. `log_entry_bottom_sheet.dart`'ta her başarılı kayıttan sonra çağrılır.
- `init()`'teki auto-reschedule kaldırıldı — uygulama yeniden açılınca okunan günün bildirimi tekrar programlanmasın diye.
- Profil → Ayarlar'dan saat seçimi + iptal. Aktif bildirim saati gösterilir.

#### Ekip Sistemi Tamamlanması
- **Admin Grup Silme:** Admin PopupMenu'ye "Grubu Sil" eklendi. Batch ile tüm üyelerin `teamId` alanı temizlenir, bekleyen istekler silinir, ekip dokümanı kaldırılır. Silme sonrası `Navigator.pop()` — Ekipler sekmesine döner.
- **Zorla Gizli Gruplar:** `_CreateTeamSheet`'te `_isPrivate = true` sabitlendi, toggle kaldırıldı. Tüm açılan gruplar şimdilik gizlidir; bilgi kutusu gösterilir.
- **Firestore Kuralları Deploy Edildi:** `logs` subcollection'ı `isAuth()` ile herkese okunabilir yapıldı (liderboard için). `users/{uid}` güncelleme kuralına `teamId` alanı için alan-bazlı istisna eklendi. `teams/{teamId}/requests` subcollection'ı için kural eklendi. Deploy: `firebase deploy --only firestore:rules --project vird-fc834`.

---

### Faz 1 & 2 — Beta Test Hazırlığı (2026-04-28)

Yaklaşık 40 kişilik YTÜ Fark Kulübü beta testine hazırlık kapsamında yapılan kritik düzeltmeler ve iyileştirmeler.

#### Faz 1 — Kritik Düzeltmeler

- **Seri sayacı** (`log_entry_bottom_sheet.dart`): Log kaydedilirken `lastLogDate` ve `seri` alanları artık doğru güncelleniyor. Dün okunduysa +1, bugün zaten okunduysa değişmez, daha önce veya hiç okunmadıysa 1'e sıfırlanır. Yeni alan: `users/{uid}.lastLogDate` (Timestamp).
- **Ekip liderboard crash düzeltmesi** (`ekip_profil_screen.dart`): Remote commit'in gözden kaçırdığı `_untilMidnight → _untilEnd` ve `entry.todayHasanat → entry.periodHasanat` rename'leri düzeltildi.
- **Google logo offline fallback** (`login_screen.dart`, `register_screen.dart`): `Image.network` artık internetsizken mavi "G" harfi gösteriyor.
- **Widget test compile hatası** (`test/widget_test.dart`): `MyApp` → `VirdApp(showHome: false)` düzeltildi.

#### Faz 2 — Önemli İyileştirmeler

- **Kayıt akışı tutarlılığı** (`register_screen.dart`): Kullanıcı Firestore dokümanı artık tüm alanlarla oluşturuluyor (`hasanat`, `seri`, `totalPages`, `hatimCount`, `isPro`). E-posta format ve şifre uzunluğu client-side validasyonu eklendi.
- **Google kayıt** (`auth_service.dart`): Yeni Google kullanıcısı için oluşturulan Firestore dokümanına eksik alanlar eklendi (`hasanat`, `seri`, `totalPages`, `hatimCount`, `isPro`, `proExpiresAt`).
- **"Bu adımı atla" veri kaybı giderildi** (`profile_setup_screen.dart`): `set()` çağrısına `SetOptions(merge: true)` eklendi — atla butonuna basınca `hasanat` gibi alanlar artık sıfırlanmıyor.
- **Türkçe hata mesajları** (`login_screen.dart`, `register_screen.dart`): `FirebaseAuthException` kodları `_parseAuthError()` ile Türkçe kullanıcı mesajlarına dönüştürülüyor.
- **Firestore güvenlik kuralları** (`firestore.rules`): Test modu yerine gerçek kurallar. Kullanıcılar sadece kendi `logs` ve `hatims` sub-collection'larına yazabiliyor. **Deploy edilmesi gerekiyor:** `firebase deploy --only firestore:rules --project vird-fc834`
- **firebase.json + firestore.indexes.json** güncellendi — Firestore rules deploy desteği eklendi.
- **Import temizliği**: `log_history_sheet.dart`, `hatim_remover.dart`, `onboarding_screen.dart` içindeki kullanılmayan importlar kaldırıldı. `ekip_profil_screen.dart`'taki kullanılmayan `weekly` enum değeri silindi.

---

### Modül 1 — Kurulum (2026-04-21)

- Flutter SDK, Android Studio, NDK kurulumu
- Chrome'da `flutter run` çalışıyor
- 4 sekmeli BottomNavigationBar iskeleti
- AppColors paleti, Nunito font entegrasyonu
- **Not:** adb her oturumda manuel PATH'e ekleniyor: `$env:PATH += ";D:\Android\Sdk\platform-tools\platform-tools"`

---

### Modül 2 — Auth (2026-04-22)

- Firebase Authentication + Firestore (Test Modu)
- Onboarding ekranı `SharedPreferences` ile — sadece ilk açılışta gösterilir
- E-posta/şifre kayıt ve giriş ekranları
- `signInWithPopup` ile Web için Google ile Giriş
- `AuthWrapper`: giriş durumuna göre MainScreen / LoginScreen yönlendirmesi
- Profil sekmesi Firestore'a bağlı (isim, şehir, üniversite canlı çekiliyor)
- BottomSheet ile profil güncelleme (sayfa değiştirmeden)
- `dropdown_search` ile şehir/üniversite arama (Türkçe karakter filtresi dahil)
- 20 adet premium DiceBear avatar — Firebase Storage maliyeti yok

---

### Modül 9 & 13 (Kısmen) — Profil UI + Kuran Haritası (2026-04-25)

#### Dosyalar
- `lib/screens/profil_screen.dart` — Profil sekmesi UI tamamlandı
- `lib/data/quran_cuz.dart` — Kuran veri dosyası oluşturuldu

#### Profil Ekranı Yapısı
1. **`_ProfileHeader`** — 96dp teal banner, overlap avatar (radius 39, hafız ise gold border), dişli ikon, ad / PRO badge / username / şehir·üniversite
2. **`_StatGrid`** — `IntrinsicHeight` + `Row` + 4× `Expanded _StatCard` (Seri / Hasanat / Hatim / Sayfa)
3. **`_KuranHaritasiCard`** — filtre chips (`HeatFilter` enum), stat şeridi, `_HeatGrid`, lejant, detay paneli

#### Isı Haritası (_HeatGrid) Kararları
- `_maxPages = 20` — kare boyutu 20 sütuna göre hesaplanır
- `LayoutBuilder` ile responsive kare boyutu — hard-coded px yok
- **Fatiha satırı:** 1 kare + "Fâtiha" etiketi sağda dışarıda (`page = 0`)
- **Cüz 1–29:** 20'şer kare, standart satır
- **Cüz 30:** 2 satıra bölünür — satır 1: sayfa 581–600, satır 2: sayfa 601–604 + "İhlâs · Felak · Nâs" etiketi

#### State (güncel)
```dart
enum HeatTypeFilter { arapca, meal }   // Tür filtresi — ARAPÇA/MEAL segmented badge
enum HeatTimeFilter { all, month, year } // Zaman filtresi — chip satırı
// _typeFilter: HeatTypeFilter — Firestore query'de where('type', ...) ile kullanılır
// _timeFilter: HeatTimeFilter — client-side filtreleme; composite index gerektirmez
// _readings: Map<int, int> — {sayfa: okumaSayısı}
// _selectedPage: int? — detay paneli için
```

#### Filtre Mimarisi (güncel)
- Tür ve zaman filtreleri **bağımsız** — önceki `HeatFilter` enum'u ikisini birleştiriyordu, hata yapıyordu
- `_buildLogsQuery`: yalnızca `.where('type', ...)` — tek alan filtresi, index gerekmez
- `_buildReadingsFromLogs`: zaman filtresi `createdAt` karşılaştırmasıyla client-side uygulanır
- Tür filtresi: ARAPÇA/MEAL badge'i başlık satırının sağında (segmented toggle görünümü)
- Zaman filtresi: Tüm zamanlar | Son 1 ay | Son 1 yıl — altta chip satırı olarak kalır

#### Metrikler (güncel)
- **Profil:** SAYFA (benzersiz) | OKUMA (toplam) | CÜZ (X/30 — tamamlanan cüz sayısı)
- **Hatim:** SAYFA | CÜZ | KALAN
- KAPSAM % metriği kaldırıldı — genel haritada yanıltıcıydı

---

### Modül 3 — Kuran Verisi (2026-04-25)

**Dosya:** `lib/data/quran_cuz.dart` — static Dart const (JSON değil; Dart const daha verimli, runtime yükü yok)

- 114 sure: id, Türkçe isim, startPage, endPage
- 30 cüz: cuzNo, startPage, endPage — Cüz 1–29: 20'şer sayfa, Cüz 30: 24 sayfa (581–604)
- Fatiha = page 0 (özel blok)
- Tüm QuranData API metodları hazır

**Not:** Ayet bazlı veri yok — MVP için gerekmiyor. Uygulama içi okuma özelliği gelirse eklenecek.

---

## Kuran Veri Sistemi (`lib/data/quran_cuz.dart`)

> Bu dosya tüm modüllerde (log, hatim takip, seri, harita) kullanılır. Dokunmadan önce oku.

### Sayfa Sistemi
- **Türkiye Diyanet mushafı** baz alındı
- **Fatiha = page 0** (özel blok, sayfalı sisteme dahil değil)
- **Sayfa 1–604:** Bakara 1. ayet = sayfa 1, Nâs = sayfa 604
- **Cüz 1–29:** Tam 20'şer sayfa (1–20, 21–40, …, 561–580)
- **Cüz 30:** 24 sayfa (581–604)

### Cüz 30 Sure→Sayfa Haritası

| Sayfa | Sureler |
|-------|---------|
| 581–582 | Nebe' |
| 582–583 | Nâziât |
| 584–585 | Abese |
| 585–586 | Tekvîr |
| 586 | İnfitâr |
| 587–588 | Mutaffifîn |
| 588–589 | İnşikâk |
| 589–590 | Bürûc |
| 590 | Târık · A'lâ |
| 591–592 | Gâşiye |
| 592–593 | Fecr |
| 593–594 | Beled |
| 594 | Şems |
| 595 | Leyl · Duhâ |
| 596 | İnşirâh · Tîn |
| 597 | Alak |
| 598 | Kadr · Beyyine |
| 599 | Zilzâl · Âdiyât |
| 600 | Kâria · Tekâsür |
| 601 | Asr · Hümeze · Fîl |
| 602 | Kureyş · Mâûn · Kevser |
| 603 | Kâfirûn · Nasr · Tebbet |
| 604 | İhlâs · Felak · Nâs |

### QuranData API

```dart
QuranData.cuzForPage(int page)                      // CuzInfo? (page=0 → cüz 1)
QuranData.surahsOnPage(int page)                    // "Sure1 · Sure2" string
QuranData.heatColor(int count)                      // Color — sabit eşikler (6 seviye)
QuranData.heatColorRelative(int count, int maxCount) // Color — göreli skala, taban=10
QuranData.totalNumberedPages                        // 604
QuranData.surahlar                                  // List<SurahInfo> — 114 sure
QuranData.cuzler                                    // List<CuzInfo> — 30 cüz
```

**`heatColorRelative` notu:** `max(maxCount, 10)` taban kullanır. Max=1 olsa bile tek okunan sayfa açık renk kalır. Profil haritası bu metodu kullanır; lejant gösterimi `heatColor` ile kalır.

---

---

### Modül 16 — Vird Sekmesi (2026-04-25)

#### Dosyalar
- `lib/screens/vird_screen.dart` — Vird sekmesi tamamlandı
- `lib/app_assets.dart` — Merkezi logo sabiti (`AppAssets.logo`)
- `assets/images/vird_logo.jpeg` — Yeni logo

#### Ekran Yapısı
1. **Header** — Teal banner, Türkçe hadis (Âişe hadisi, Müslim M1828), Arapça metin yok
2. **Yakında Geliyor** — `_allUpdates` const listesi (9 kart); Ekipler ve Uygulama İçi Okuma eklendi. MVP kartı yeşil (`released: true`), kalanlar teal ve alta doğru şeffaflaşır
3. **"Tüm sürüm geçmişini gör →"** — `showModalBottomSheet` + `DraggableScrollableSheet`, alt kısımda beyaz gradient sonsuzluk hissi
4. **Bir özellik öner** — `TextField` + Firestore `feature_requests` write, `_PrimaryButton` 3D depth
5. **Hakkında** — Vird'in tasavvuf terimi tanımı + açıklama
6. **Footer** — Logo (96dp, ortalı) + "YTÜ · İstanbul · 2026 · v 1.00"

#### Teknik Kararlar
- `coming_soon` Firestore StreamBuilder → hardcoded `_allUpdates` (Admin paneli MVP sonrasına alındı)
- `_Feature` → `_Update` (`released: bool` alanı eklendi); `_FeatureCard` → `_UpdateCard` (yeşil/teal renk ayrımı)
- `feature_requests` Firestore write korundu — kullanıcı önerileri Firebase'e yazılıyor
- Nav bar: "VİRD" yazısı kaldırıldı, logo 38dp `Opacity` ile aktif/pasif

#### Logo Sistemi (`lib/app_assets.dart`)
- `AppAssets.logo` tek merkezi sabit — logo değişirse sadece bu satır güncellenir
- `AppAssets.ricalIFarkLogo` — Ekipler sayfası için takım logosu
- Bağlı dosyalar: `main.dart`, `vird_screen.dart`, `login_screen.dart`, `splash_screen.dart`, `ekipler_screen.dart`
- **Not:** Nav bar'da `ColorFiltered(BlendMode.srcIn)` yerine `Opacity` kullanılır çünkü JPEG'de alpha kanalı yoktur

---

### Modül 11 & 12 — Ekip Sistemi + Haftalık Ekip Sıralaması (2026-04-27, güncellendi 2026-05-08)

#### Dosyalar
- `lib/models/team_model.dart` — Team veri modeli (yeni)
- `lib/screens/ekipler_screen.dart` — Ekip listesi (tam yeniden yazıldı)
- `lib/screens/ekip_profil_screen.dart` — Ekip profili + liderboard (yeni)
- `lib/screens/kullanici_profil_screen.dart` — Başka kullanıcı profiline read-only bakış (yeni)

#### Firestore Şeması (güncel)
```
teams/{teamId}
  name: string
  description: string           ← admin düzenleyebilir
  penaltyNote: string           ← admin düzenleyebilir
  adminUid: string              ← team kurucusu; MVP'de elle de atanabilir
  memberCount: int              ← katılma/ayrılmada increment/decrement
  isPrivate: bool               ← YENİ; true ise listede görünmez
  inviteCode: string            ← YENİ; 6 haneli, otomatik üretilir (örn. "XK7P2Q")
  createdAt: Timestamp

teams/{teamId}/requests/{uid}   ← YENİ sub-collection
  name: string
  username: string
  avatarSeed: string?
  requestedAt: Timestamp

users/{uid}
  teamId: string?               ← bulunduğu ekibin ID'si
  isPro: bool?                  ← YENİ; default false; Firestore Console'dan elle atanır
```

#### EkiplerScreen
- Sadece **açık** ekipler + **kullanıcının kendi ekibi** (gizli olsa bile) listelenir
- Kullanıcının kendi ekibi "Ekibim" badge'iyle vurgulanır; gizli ekipler 🔒 ikonu gösterir
- Ekip kartına tıklama → `EkipProfilScreen`
- **"Yeni Grup Kur" butonu:** herkes görür; Pro değilse dialog açar. Pro ise `_CreateTeamSheet` açar
- **"Davet Koduyla Katıl" butonu:** sadece ekipsiz kullanıcılara görünür → `_InviteCodeSheet`
- `_CreateTeamSheet`: ad + açıklama + gizlilik toggle; batch ile `teams` oluştur + `users/{uid}.teamId` güncelle, `memberCount: 1`, `inviteCode` otomatik üret
- `_InviteCodeSheet`: 6 haneli kod gir → `teams where inviteCode == X` → EkipProfilScreen'e yönlendir

#### EkipProfilScreen
- `SliverAppBar` collapsible header — teal degrade, kalkan ikonu
- Admin PopupMenu: "Açıklamayı Düzenle" / "Ceza Notunu Düzenle" → `_EditFieldSheet`
- **Üyelik widget'ı** (duruma göre değişir):
  - Admin → "Admin" badge (ayrılamaz; admin devri MVP sonrasına bırakıldı)
  - Üye → "Ayrıl" butonu (AlertDialog onayı → `FieldValue.delete()` + `memberCount -1`)
  - Beklemede → "Beklemede ✕" (tıklayınca isteği iptal eder)
  - Dışarıdan → "Katıl" butonu (istek gönderir, direkt katılmaz)
- **Admin: Davet Kodu kartı** — `_InviteCodeCard`; kodu gösterir + kopyala butonu
- **Admin: Bekleyen İstekler** — `StreamBuilder` ile `teams/{teamId}/requests` canlı; her satırda "Onayla" / "Reddet" butonları. Onayda: batch ile request sil + `users/{uid}.teamId` güncelle + `memberCount +1`
- **Açıklama kartı:** gri bilgi kutusu (varsa gösterilir)
- **Ceza Notu kartı:** sarı uyarı tasarımı (varsa gösterilir)
- **Dinamik Liderboard (`_LeaderboardSection`):**
  - **Dinamik Dönem:** `_LeaderboardPeriod` enum ile `daily` (günlük) veya `weekly` (haftalık) mod. Şu an test için `daily`.
  - **Geri Sayım Sayacı:** Dönem sonuna (örneğin yarın 00:00 veya haftaya Pazar gecesi 23:59) sayar.
  - Yenile butonu (manuel refresh)
  - **Tüm üyeler gösterilir** (0 hasanatlılar dahil)
  - **İlk 3:** 1. sıra güçlü yeşil, 2. ve 3. sıra giderek soluklaşan yeşil arka plan + 🥇🥈🥉 madalya
  - **Son sıralar:** Grup kalabalıksa (en az 4+ kişi), ilk 3'e girmeyen en alt sıradakiler (kalabalığa göre son 1-3 kişi) kırmızı görünür.
  - **0 Hasanat Kuralı:** 0 puanı olan herkes, ilk 3'te olsa bile **kırmızı** gösterilir.
  - **"(sen)" etiketi:** Kendi satırın, sıralamadaki doğal renginde (yeşil, beyaz veya kırmızı) kalır; eski mavi zemin üzerine yazma (override) kaldırıldı.
  - Satıra tıklama → `KullaniciProfilScreen`

#### Teknik Kararlar (güncel)
- `isPro` alanı: Firestore Console'dan elle `true` yapılır; uygulama içinde değiştirilemez
- Admin ayrılma: kilitli — admin devri MVP sonrasına alındı (`todo.md`)
- Davet kodu: `_generateInviteCode()` — 6 haneli, karışık harf-rakam (O/0/I/1/L karıştırıcı karakterler hariç)
- `requests` sub-collection: `orderBy` YOK — `serverTimestamp()` ile yazılan field'a `orderBy` konunca pending write aşamasında null dönüp query crash yapar; sıralama client-side yapılır veya sıralama gerekmez
- **User Document Initialization:** "Bu adımı atla" seçeneğinde kullanıcının isimsiz kalmaması için, Firestore user dokümanı `ProfileSetupScreen` yerine **kayıt olur olmaz (`RegisterScreen`)** `set` ile oluşturuluyor. `ProfileSetupScreen` sadece bu dokümanı `merge: true` ile güncelliyor.
- **DropdownSearch:** Profil düzenleme sheet'indeki şehir ve üniversite alanları artık onboarding ile aynı Türkçe duyarlı DropdownSearch yapısını kullanıyor.

#### KullaniciProfilScreen
- Başka kullanıcının profilini read-only gösterir
- `SliverAppBar` + avatar/isim/kullanıcı adı/şehir satırı
- `_StatGrid` (Seri, Hasanat, Hatim, Sayfa) — canlı stream
- Tam Kuran Haritası (profil_screen.dart ile aynı mantık — tür + zaman filtresi, sayfa detay paneli)
- Ayarlar butonu yok

#### Teknik Kararlar
- Admin atama: MVP'de Firebase Console'dan `adminUid` field'ı elle yazılıyor
- Liderboard reset: Cloud Function yerine client-side — `periodStart` dinamik hesabı kullanılarak loglar bu tarihten itibaren çekilir; sayaç sıfırlanınca bir sonraki manual refresh doğru verileri getirir
- Geçmiş Yarışmalar: Haftalık yarışmalar bittiğinde eski liderlik tablolarının özeti gösterilebilmesi için ileride Cloud Function ile `past_leaderboards` koleksiyonu yazılacak (MVP sonrası).
- N+1 Firestore okuma (her üye için log query): küçük ekipler (MVP ~40 kişi) için kabul edilebilir
- `KullaniciProfilScreen` heat map kodu `profil_screen.dart`'tan bağımsız (private widget'lar import edilemiyor); kod tekrarı bilinçli tercih


---

### Modül 4 & 5 — Hatimlerim + Log Girişi (2026-04-25 başladı, 2026-04-27 son güncelleme)

#### Dosyalar
- `lib/screens/hatimlerim_screen.dart` — Aktif hatimler sekmesi
- `lib/screens/tamamlanan_hatimler_screen.dart` — Tamamlanan hatimler listesi
- `lib/widgets/hatim_heat_map_sheet.dart` — Per-hatim ısı haritası bottom sheet
- `lib/widgets/log_entry_bottom_sheet.dart` — 4 tab'lı okuma kaydı (kilitleme modu + tebrik popup)
- `lib/widgets/log_history_sheet.dart` — Kayıt geçmişi (düzenleme + silme)
- `lib/models/hatim_model.dart` — Hatim veri modeli (`isCompleted`, `completedAt`, `firstUnreadPage` alanları)
- `lib/models/reading_log_model.dart` — Okuma log veri modeli
- `lib/utils/hatim_calculator.dart` — `recalculate` artık `Future<bool>` döndürüyor (justCompleted)

#### Hatim Model (`hatim_model.dart`)
```dart
isCompleted: (data['isCompleted'] as bool?) ?? false,      // geriye uyumlu — null → false
completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
firstUnreadPage: data['firstUnreadPage'] ?? 1,             // geriye uyumlu — null → 1
```
- Eski Firestore dokümanlarında `isCompleted` alanı yok → `false` varsayılan
- Eski Firestore dokümanlarında `firstUnreadPage` alanı yok → `1` varsayılan (ilk log sonrası recalculate ile güncellenir)
- Tamamlanma şartı: 1-604 arası TÜM sayfalar `Set<int>`'te mevcut olmalı
- Tamamlanınca: transaction ile `isCompleted: true`, `completedAt: serverTimestamp()`, `hatimCount: increment(1)`

#### Hatimlerim Ekranı
1. **Seri & Hasanat kartları** — Firestore'dan `seri` ve `hasanat` alanları canlı
2. **Aktif Hatimler listesi** — StreamBuilder + `_deletingIds Set` (Dismissible/StreamBuilder çakışma önlemi)
3. **Yeni Hatim Başlat** — FAB; Arapça ≤ 3 / Meal ≤ 1 limit, sayaç badge'leri, opsiyonel isim alanı
4. **Hatim silme** — Sola swipe → kırmızı zemin → AlertDialog onayı → Firestore delete
5. **Hatim kartı** — Minimal: ikon + başlık + `XX/604 sayfa · X. cüz` + progress bar + sağda grid ikonu
6. **Kart tıklama** — Kartın herhangi yerine veya grid ikonuna basmak → `HatimHeatMapSheet.show()` açar
7. **Tamamlanan hatimler butonu** — Liste altında; tamamlanan sayısı varsa görünür, `TamamlananHatimlerScreen`'e yönlendirir
8. **DEVAM ET** — Kart'tan kaldırıldı; ısı haritası sayfasının üstünde yer alır

#### Tamamlanan Hatimler Ekranı (`tamamlanan_hatimler_screen.dart`)
- Firestore query: `.where('isCompleted', isEqualTo: true)` — composite index gerektirmesin diye `orderBy` YOK
- Client-side sort: `completedAt ?? updatedAt` desc
- Kart: yeşil border, "604/604 sayfa · tarih", TAMAM badge, grid ikonu
- Kart herhangi yerine tıklama → `HatimHeatMapSheet.show()` (onDevamEt: null, buton gösterilmez)
- Swipe-to-delete + AlertDialog onayı

#### Hatim Isı Haritası (`hatim_heat_map_sheet.dart`)
- Yalnızca o hatimin logları: `.where('hatimId', isEqualTo: hatim.id)`
- **Binary renk:** okundu = `Color(0xFF38A474)` (yeşil-teal), okunmadı = `AppColors.borderGrey`
- **Fatiha karesi:** `usePage1Color: true` → `readPages.contains(1)` ile renk belirlenir (page 1 ile aynı)
- **Tıklama → detay:** `ValueNotifier<int?> _selectedPage` state; `ValueListenableBuilder` ile lokal rebuild (tüm sayfa render'lanmaz, layout sıçraması/beyaz ekran önlenir). Sabit `_DetailPanel` profildeki gibi çalışır.
- **Metrikler:** SAYFA | CÜZ (tamamlanan cüz/30) | KALAN
- **DEVAM ET butonu:** `onDevamEt` callback varsa sayfanın en üstünde; `Navigator.pop` + `addPostFrameCallback` ile hatim log sheet açılır
- **Kilitleme:** `onDevamEt` ile açılınca `LogEntryBottomSheet` o hatim kilitli açılır
- **Tarih bilgileri (`_HatimDatesRow`):** başlangıç tarihi; tamamlananlar için bitiş + süre (`_fmtDuration`: <30 gün → "X gün", ≥30 gün → "X ay Y gün")
- **Son Okumalar:** son 3 log (client-side sort); dişli ikon + "Tümünü gör (N)" → `_AllLogsSheet`
- **`_AllLogsSheet`:** Tüm hatim logları StreamBuilder ile canlı; swipe-to-delete → `batch(doc.delete, hasanat -= pagesRead×10, totalPages -= pagesRead)` ve otomatik `HatimCalculator.recalculate`
- **Tüm Kayıtları Sil:** Geçmiş altındaki kırmızı buton. Logları 400'lük gruplar halinde (batch limit) güvenli şekilde siler, hasanat ve totalPages'i sıfırlar, etkilenen hatimleri `recalculate` ile günceller.

#### HatimCalculator & HatimRemover (`utils/`)
- **`HatimCalculator.recalculate`:** `Future<bool>` döndürür — `true` ise o çağrıda hatim ilk kez tamamlandı demektir (wasCompleted=false → isCompleted=true). Tüm logları okur, `Set<int>` ile benzersiz sayfaları toplar, `lastReadPage` (en yüksek sayfa), `firstUnreadPage` (1-604 arası ilk boş sayfa) ve `isCompleted` (tüm 1-604 sayfaları okundu mu) hesaplar.
- **`HatimRemover`:** Firestore batch 500 limitine takılmamak için logları 400'erli gruplar halinde siler. Hatim silinince tüm ilgili okuma loglarını silip profildeki hasanat ve toplam sayfa puanlarını geriye doğru eksiksiz düzeltir.

#### Log Girişi Bottom Sheet — Güncellemeler
- **Kilitleme modu** (`_lockedToHatim = initialHatim != null`):
  - TabController length: 3 (Sure sekmesi gizlenir)
  - `_devamHatim`, `_sayfaHatim`, `_cuzHatim` hepsi `initialHatim` ile başlatılır
  - Devam tab'da "Değiştir" butonu gizlenir
  - Sayfa/Cüz tab'larında chip seçimi yerine `_LockedHatimBadge` gösterilir
- **Fazla sayfa uyarısı (düzeltildi):** Devam tab'da kullanıcı kalan sayfadan fazla girerse `pagesRead` gerçek kalan sayfa adedine (`endPage - startPage + 1`) sabitlenir. Dialog: "Hatimini bitirmene X sayfa kaldı. X sayfa okundu işaretlenecek ve X×10 hasanat eklenecek." Hasanat da bu gerçek sayıya göre hesaplanır.
- **"Sıralı okundu" mesajı kaldırıldı:** Devam sekmesi artık her zaman sayfa girişine izin veriyor — `isFinished` durumu yok
- **`firstUnreadPage` ile akıllı devam:** `lastReadPage >= 604` ise Devam sekmesi `lastReadPage + 1` yerine hatimin başından ilk boş sayfadan (`firstUnreadPage`) başlıyor. Log kaydedilirken `startPage` ve `endPage` de buna göre hesaplanıyor.
- **Hatim tamamlanma popup:** `LogEntryBottomSheet.show()` artık `Future<bool>` sonucu bekliyor. `justCompleted == true` ise bottom sheet kapandıktan sonra parent context'te tebrik dialogu gösteriliyor: "Mâşallah! Bir hatmi tamamladınız. Allah kabul eylesin." — "Âmin" butonu ile kapatılır.

#### Log Geçmişi Bottom Sheet (`log_history_sheet.dart`)
- Ekran yüksekliğinin %68'i, tüm loglar StreamBuilder ile (limit yok)
- Her satır: yöntem ikonu + başlık + tip badge + göreli zaman + düzenle/sil ikonları
- **Silme:** AlertDialog → batch(log sil, hasanat -= pagesRead×10, totalPages -= pagesRead) ve `HatimCalculator.recalculate`
- **Düzenleme (`_LogEditSheet`):** Metoda özel form; batch ile fark hesabı (Δhasanat, ΔtotalPages) ve otomatik `recalculate`.
- **Tüm Kayıtları Sil Butonu:** Batch limit sorunu çözülerek 400'lü chunk'lar halinde loglar silinir. Puanlar eksi olarak hesaplanarak güncellenir.
- **Tasarım:** Ana butonlar ("DEVAM ET", "KAYDET", "BAŞLAT") tutarlılık için `DuolingoButton` component'i yapıldı.

#### Firestore Şeması (güncel)
```
users/{uid}/hatims/{hatimId}
  type: 'arapca' | 'meal'
  name: string?
  currentPage: int           ← Benzersiz okunan sayfa adedi (0-604)
  lastReadPage: int          ← En yüksek okunan sayfa numarası
  firstUnreadPage: int       ← 1-604 arası ilk okunmamış sayfa (Devam sekmesi için)
  totalPages: 604
  isCompleted: bool          ← Eski dokümanlarda yok → false kabul edilir
  completedAt: Timestamp?    ← Sadece tamamlanan hatimlerde
  createdAt: Timestamp
  updatedAt: Timestamp       ← FieldValue.serverTimestamp()

users/{uid}/logs/{logId}
  type: 'arapca' | 'meal'
  method: 'hatim' | 'surah' | 'pages' | 'cuz'
  pagesRead: int
  surahId: int?
  startPage: int?
  endPage: int?
  hatimId: string?
  createdAt: Timestamp

users/{uid} (root doc)
  hasanat: int
  totalPages: int
  seri: int
  hatimCount: int            ← tamamlanan hatim sayacı (Profil bu alanı değil, isCompleted query'sini kullanır)
```

---

### Modül 8, 9 & 13 — Hasanat + Kuran Haritası Veri Bağlantısı + Profil (2026-04-25)

> Collaborator tarafından geliştirildi.

#### Hasanat Sistemi (Modül 8)
- **Formül:** 1 sayfa = 10 hasanat
- Log kaydında `FieldValue.increment(pagesRead * 10)` ile `hasanat` alanı güncellenir
- `totalPages` da aynı batch'te `FieldValue.increment(pagesRead)` ile güncellenir

#### Kuran Haritası Veri Bağlantısı (Modül 9)
- `profil_screen.dart`'taki `_readings` map'i artık Firestore'dan dolduruluyor
- `_buildReadingsFromLogs()` — log kayıtlarındaki `startPage`-`endPage` aralığını sayfa bazlı okuma sayısına çevirir
- `_buildLogsQuery()` — filtre bazlı Firestore query:
  - **Tüm zamanlar:** tüm loglar (filtre yok)
  - **Son 1 ay:** `createdAt >= 30 gün önce` + `type == 'arapca'`
  - **Son 1 yıl:** `createdAt >= 365 gün önce` + `type == 'arapca'`
  - **Meal:** `type == 'meal'`
- `StreamBuilder<QuerySnapshot>` ile gerçek zamanlı güncelleme

#### Profil — Son Güncellemeler
- **HATİM stat live:** `hatimCount` user doc alanı yerine `users/{uid}/hatims where isCompleted==true` stream ile canlı sayılıyor. Kayıt silinince, hatim tamamlanınca veya iptal edilince otomatik güncellenir.
- **Ayarlar → Okuma Geçmişi:** `_SettingsSheet`'e "Okuma Geçmişi" maddesi eklendi — "Şifre İşlemleri" altında, `LogHistorySheet.show()` açar.

---

## Öğrenilen Dersler

- `withOpacity()` deprecated → `withValues(alpha: ...)` kullan
- Isı haritasında `GridView` kullanma — cüz etiketi zorlaşır; `Column` içinde 30 `Row` daha iyi
- Detay panelinde sureleri `QuranData.surahsOnPage()` ile çek, hard-code yazma
- `unnecessary_non_null_assertion` lint: `e!.isNotEmpty` yerine `e.isNotEmpty`
- JPEG'de alpha kanalı yok → `ColorFiltered(BlendMode.srcIn)` boş/siyah kutu gösterir; logo tinting için `Opacity` kullan
- Yeni asset eklenince hot reload yetmez → `flutter clean` + tam `flutter run` gerekir
- UI metni (buton, açıklama, başlık) yazılmadan önce kullanıcıya öner ve onay al — direkt yazma
- Farklı Kuran veri sistemleri varsa (JSON+Provider vs Static Const) → ana projenin sistemini baz al, uyumluluk sağla
- Collaborator entegrasyonunda Firestore alan isimlerini ana projeyle eşle (ör: `currentStreak` → `seri`)
- `FieldValue.increment()` kullanarak batch içinde atomik güncelleme yap — race condition önlenir
- **`FieldValue.serverTimestamp()` crash:** Firestore'a `serverTimestamp()` yazınca istemci tarafında kısa süre `null` döner. `fromFirestore`'da `(data['updatedAt'] as Timestamp)` cast'i çöker → `(data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now()` kullan
- **`Dismissible` + `StreamBuilder` çakışması:** Silme işlemi Firestore'a gidip dönene kadar item listede kalır; silme animasyonu biter ama item tekrar görünür → `_deletingIds Set` ile client-side filtreleme çözer
- **Göreli ısı haritası taban:** Saf `count/maxCount` oranı — max=1 iken tek okuma en koyu rengi alır, saçma görünür. Taban `max(maxCount, 10)` ile hem göreli hem gerçekçi dağılım sağlanır
- **Paylaşımlı toggle + başlangıç tipi:** `LogEntryBottomSheet` dışarıdan `initialHatim` ile açılırsa `_globalType = initialHatim.type` ile başlatmak gerekir; aksi hâlde sekme değiştirince tip sıfırlanır
- **Chip filtresi:** Arapça/Meal toggle'ı değişince hatim chip listesi de filtrelenmeli — aksi hâlde yanlış tipteki hatimler gösterilir ve yanlış log yazılır
- **Firestore composite index tuzağı:** `orderBy + where` birden fazla alan içerince composite index oluşturmak gerekir; `orderBy` kaldırılıp sıralama client-side yapılırsa index gerekmez ve query basitleşir
- **Geriye uyumlu model alanı:** Yeni bool alan eklenince `(data['isCompleted'] as bool?) ?? false` — null-safe default olmadan eski dokümanlar crash yapar
- **`Dismissible` + `StreamBuilder` çakışması (tamamlanan):** `_deletingIds Set` ile client-side filtreleme; hem `hatimlerim_screen.dart` hem `tamamlanan_hatimler_screen.dart` hem `_AllLogsSheet`'te aynı pattern kullanılır
- **Log silme sınırı:** `_AllLogsSheet`'te log silinince `hasanat` ve `totalPages` güncellenir ama hatim `currentPage` güncellenmez (geriye dönük hesap karmaşık); kullanıcı yeni doğru log ekleyebilir
- **Fazla sayfa kontrolü:** `pagesRead <= 0` kontrolünden sonra, `setState` öncesinde; dialog await'i öncesinde hiç `async` olmadığından `context` güvenli kullanılır
- **TabController length dinamik:** `_lockedToHatim` true iken `length: 3` (Sure sekmesi yok); `initState`'te `widget.initialHatim != null` kontrolüyle belirlenir — `initState`'te `widget` erişilebilir
- **Dinamik Hatim Tamamlanma (Set Kontrolü):** Sadece "30. cüzü okudum" demekle veya son sayfa 604 olunca hatim tamamlanmamalıdır. `Set<int>` kullanılarak tüm sayfalar (1-604) tek tek okunmuş mu kontrol edilmelidir.
- **Sıralı Okuma vs Benzersiz Sayfa Sayısı:** `currentPage` benzersiz okunan sayfa adedini, `lastReadPage` ise Devam sekmesindeki sıralı okumada en son nerede kalındığını (en yüksek sayfa numarası) tutmak üzere iki ayrı metrik olarak tasarlanmalıdır.
- **Kullanıcı Kayıt Akışı Uyumluluğu:** Profil düzenleme gibi ekranlarda istenen bilgiler, onboarding/kayıt aşamasındaki zorunluluklarla tutarlı olmalıdır (Örn: Username girişte zorunlu değildi, bu yüzden profil düzenlemede de opsiyonel olmalıdır).
- **ModalBottomSheet'ten dialog gösterme:** Bottom sheet kapandıktan sonra parent context'te dialog göstermek için `showModalBottomSheet<bool>` sonucunu `await` ile bekle, ardından `context.mounted` kontrolü yap ve `showDialog` çağır. Bottom sheet içinden pop ederek sonuç ilet: `Navigator.pop(context, true)`.
- **`recalculate` dönüş değeri:** `Future<void>` yerine `Future<bool>` döndürmek için transaction dışında `bool justCompleted = false` tanımla, transaction içinde `justCompleted = true` ata, transaction sonrası return et. Transaction kendi değer döndüremediğinden dış değişken şart.
- **`firstUnreadPage` geriye uyumluluğu:** Firestore'da alanı olmayan eski hatim dokümanları `null` döndürür → `data['firstUnreadPage'] ?? 1` ile varsayılan 1 ver. İlk log kaydedilince `recalculate` doğru değeri yazar.
- **Devam sekmesi pagesRead hatası:** `pagesRead = entered` (kullanıcı girişi) değil, `pagesRead = endPage - startPage + 1` (gerçek clamped sayfa) olmalı. Aksi hâlde hasanat fazla hesaplanır. Overflow dialog da bu gerçek sayıyı göstermeli.
- **Sayaç field yerine live query:** Profil gibi kritik istatistikler için Firestore'daki sayaç field'ı (`hatimCount`) güvenilmez olabilir — sync bug'ları birikmez. Bunun yerine `where('isCompleted', isEqualTo: true).snapshots()` ile canlı sayım her zaman doğrudur.
- **Switch case içi local variable:** Switch case içinde tanımlanan `final pages` gibi değişkenler case dışında erişilemez. Overflow check gibi switch sonrası kullanılacak değerler için switch öncesinde `int? cappedPages` gibi nullable değişken tanımla, case içinde set et.
- **Liderboard reset client-side:** Cloud Function gerektirmeden günlük sıfırlama için `createdAt >= DateTime(now.year, now.month, now.day)` filtresi yeterli; saat değişince client yenilenince doğru veri gelir.
- **N+1 Firestore query (küçük ekipler):** Her üye için ayrı log query MVP ölçeğinde (~40 kişi) kabul edilebilir. Büyümede `weeklyHasanat` gibi denormalized field + Cloud Function reset daha iyi ölçeklenir.
- **Private widget paylaşımı:** Dart'ta `_Widget` isimleri dosya dışından erişilemez. İki ekran aynı widget'ı paylaşacaksa ya `public` yap ve ayrı dosyaya taşı, ya da bilinçli olarak kodu tekrarla — yeniden kullanım için gereksiz refactor yapma.
- **`SliverAppBar` + `FlexibleSpaceBar` title padding:** `titlePadding` ile başlık konumunu tam kontrol et; varsayılan padding back button'ın üstüne yazabilir.
- **`serverTimestamp()` + `orderBy` crash:** Firestore'a `FieldValue.serverTimestamp()` yazınca pending write aşamasında o field `null` döner. `orderBy('fieldWithServerTimestamp')` olan bir query bu null'ı sıralayamaz ve crash verir. Çözüm: `orderBy` kaldır, sıralama gerekiyorsa client-side yap.
- **Same-frame pop+push navigator crash:** `Navigator.pop(context)` hemen ardından `Navigator.push(...)` çağrılırsa (aynı frame içinde) navigator tutarsız duruma girer — defalarca "Unexpected null value" + `mouse_tracker.dart:199` assertion hatası ve beyaz ekran. Çözüm: push'u `WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.push(...))` ile bir sonraki frame'e ertele.
- **`finally` blok + navigation:** Sheet pop edildikten sonra `finally` içinde `setState` çağrısı `mounted` false olduğu için crash atar. Başarılı path'in `finally` resetine ihtiyacı yok — sadece `catch` içinde loading state sıfırla.
- **Stack pill hizası:** `StackFit.loose` ile Row kendi yüksekliğinde büyür ve Stack'e yapışır. Pill `top: N` sabit değeri Row'un gerçek boyutunu bilmez — hizalama kayar. Çözüm: label row ve circle alanını `Column` ile ayır, pill'i sadece 38px'lik circle Stack'ine sabitle (`top:2, bottom:2`).
- **CustomPainter arc whip:** `PathMetrics.extractPath(startFrac*len, endFrac*len)` ile kayan görünür segment animasyonu. `t` ilerledikçe `startFrac` ve `endFrac` birlikte hareket eder — baştan sona kayan çizgi efekti.
- **Flame `transform-origin bottom`:** CSS `transform-origin: center bottom` eşdeğeri için: `canvas.translate(0, anchorY); canvas.scale(s); canvas.translate(0, -anchorY)`. `save/restore` ile her frame temiz.
- **Parabolic arc token:** `y = base + 4*t*(1-t)*-amplitude` formülü t=0.5'te tepe yapar, t=0 ve t=1'de base'de. `Curves.easeInOut.transform(t)` x eksenine uygulanınca doğal yavaşlama eklenir.
- **Elastic pill yalnızca bugünkü katkı:** `AnimatedContainer` tüm bloğu animate eder, `pillBaseW + delta * curve.value` ise sadece yeni eklenen segmenti genişletir. Önceden var olan blok hemen görünür, sadece uzayan kısım spring ile açılır.

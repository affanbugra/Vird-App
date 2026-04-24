# Vird — Proje Durumu & Dersler

> Tüm notlar burada. Oturum başında bu dosya okunur. `.claude/memory/` kullanılmaz.

---

## Proje Durumu (2026-04-25)

- **Uygulama:** Günlük Kuran okuma takip. Flutter + Firebase. İlk kullanıcı grubu: YTÜ Fark Kulübü (~40 kişi).
- **Test ortamı:** Her zaman `flutter run -d chrome` — emülatör RAM sorunu var, kullanılmıyor.
- **Git:** Ortak repo, herkes push yapıyor. Tüm bağlam README/ klasöründe.

### Modül Durumu

| # | Modül | Durum |
|---|-------|-------|
| 1 | Kurulum | ✅ Tamamlandı |
| 2 | Auth (Google + email, Firebase) | ✅ Tamamlandı |
| 3 | Kuran verisi entegrasyonu | ⬜ Sıradaki |
| 4 | Hatimlerim ekranı | ⬜ |
| 5 | Log girişi | ⬜ |
| 6 | Streak sistemi | ⬜ |
| 7 | Sure streaki | ⬜ |
| 8 | Hasanat sistemi | ⬜ |
| 9 | Kuran Haritası (UI ✅, veri bağlantısı ⬜) | 🔶 Kısmen |
| 10 | Offline mode | ⬜ |
| 11 | Ekip sistemi | ⬜ |
| 12 | Liderboard | ⬜ |
| 13 | Profil (UI ✅) | 🔶 Kısmen |
| 14 | Bildirimler | ⬜ |
| 15 | Rozetler | ⬜ |
| 16 | Vird sekmesi | ⬜ |

---

## Tamamlanan: Profil Sekmesi (2026-04-25)

### Dosyalar

- `lib/screens/profil_screen.dart` — Profil sekmesi UI tamamen yazıldı
- `lib/data/quran_cuz.dart` — Kuran veri dosyası oluşturuldu

### Profil Ekranı Yapısı

1. **`_ProfileHeader`** — 96dp teal (#2A7F8C→#236D79 gradient) banner, sol alta overlap avatar (radius 39, hafız ise gold border), dişli ikon sağ üst, ad / PRO badge / username / şehir·üniversite
2. **`_StatGrid`** — `IntrinsicHeight` + `Row` + 4× `Expanded _StatCard` (Streak / Hasanat / Hatim / Sayfa)
3. **`_KuranHaritasiCard`** — filtre chips (`HeatFilter` enum), stat şeridi (OKUMA/KAPSAM/SAYFA), `_HeatGrid`, lejant, detay paneli
4. **Rozet teaser kaldırıldı** (MVP dışı)

### Isı Haritası (_HeatGrid) Tasarım Kararları

- `_maxPages = 20` — kare boyutu 20 sütuna göre hesaplanır
- `LayoutBuilder` ile responsive kare boyutu, hard-coded px yok
- **Fatiha satırı:** 1 kare + "Fâtiha" etiketi sağda dışarıda (`page = 0`)
- **Cüz 1–29:** 20'şer kare, standart satır
- **Cüz 30:** 2 satıra bölünür — satır 1: sayfa 581–600 (20 kare, "30" etiketi sol), satır 2: sayfa 601–604 (4 kare) + "İhlâs · Felak · Nâs" etiketi sağda
- Renk skalası: 0→`#EEEEEF`, ≤2→`#B8DFE4`, ≤5→`#7EC4CC`, ≤10→`#2A7F8C`, ≤20→`#1F6370`, >20→`#0F3A40`

### State

```dart
enum HeatFilter { month, year, all, meal }
// _readings: Map<int, int> — {sayfa: okumaSayısı}
// MVP: boş harita. Firestore log modülünde doldurulacak.
// _selectedPage: int? — detay paneli için
```

---

## Kuran Veri Sistemi (lib/data/quran_cuz.dart)

**Bu dosya tüm modüllerde (log, hatim takip, streak, harita) kullanılır. Dokunmadan önce oku.**

### Sayfa Sistemi

- **Türkiye Diyanet mushafı** baz alındı
- **Fatiha = page 0** (özel blok, sayfalı sisteme dahil değil)
- **Sayfa 1–604:** Bakara 1. ayet = sayfa 1, Nâs = sayfa 604
- **Cüz 1–29:** Tam 20'şer sayfa (1–20, 21–40, …, 561–580)
- **Cüz 30:** 24 sayfa (581–604)

### Cüz 30 Sure→Sayfa Haritası (kullanıcı tarafından onaylandı)

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
QuranData.cuzForPage(int page)      // CuzInfo? (page=0 → cüz 1)
QuranData.surahsOnPage(int page)    // "Sure1 · Sure2" string
QuranData.heatColor(int count)      // Color (6 seviye skala)
QuranData.totalNumberedPages        // 604
QuranData.surahlar                  // List<SurahInfo> — 114 sure
QuranData.cuzler                    // List<CuzInfo> — 30 cüz
```

---

## Öğrenilen Dersler

- `withOpacity()` deprecated → `withValues(alpha: ...)` kullan
- Isı haritasında `GridView` kullanma — cüz etiketi zorlaşır; `Column` içinde 30 `Row` daha iyi
- Detay panelinde sureleri `QuranData.surahsOnPage()` ile çek, hard-code yazma
- `unnecessary_non_null_assertion` lint: `e!.isNotEmpty` yerine `e.isNotEmpty`

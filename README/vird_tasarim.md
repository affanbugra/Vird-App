# Vird — Tasarım Sistemi

---

## 1. Renk Sistemi

### Ana Renkler

| İsim | Hex | Kullanım |
|---|---|---|
| **Teal (Marka)** | `#2A7F8C` | Primary butonlar, aktif sekmeler, logo, vurgu |
| **Teal Koyu** | `#1F6370` | Buton alt gölgesi (3D depth), pressed state |
| **Teal Açık** | `#E8F5F7` | Seçili kart arka planı, light badge bg |
| **Turuncu (Seri)** | `#FF9600` | Seri sayacı, alev ikonu — başka yerde kullanılmaz |
| **Turuncu Koyu** | `#CC7A00` | Seri buton gölgesi |
| **Altın** | `#FFC200` | Hasanat puanı, ödül ikonları |
| **Beyaz** | `#FFFFFF` | Ana arka plan |
| **Açık Gri** | `#F7F7F7` | Kart arka planı, disabled alan |
| **Border Gri** | `#E5E5E5` | Kart kenarlıkları, ayraçlar, disabled buton bg |
| **Metin Koyu** | `#3C3C3C` | Başlıklar, ana metin |
| **Metin Orta** | `#777777` | Açıklama, ikincil metin |
| **Metin Açık** | `#ABABAB` | Placeholder, disabled metin, pasif ikon |

### Geri Bildirim Renkleri

| İsim | Hex | Kullanım |
|---|---|---|
| **Başarı Yeşil** | `#58CC02` | Tamamlandı geri bildirimi |
| **Başarı Zemin** | `#D7FFB8` | Başarı feedback paneli arka planı |
| **Hata Kırmızı** | `#FF4B4B` | Hatalı giriş, uyarı |
| **Hata Zemin** | `#FFDFE0` | Hata feedback paneli arka planı |
| **Bilgi Mavi** | `#1CB0F6` | Freeze ikonu, bilgi badge |

### Renk Anlam Kuralı
Renk anlamı sabittir — hiçbir zaman farklı bağlamda kullanılmaz:
- Seri → `#FF9600` · Hasanat → `#FFC200` · Başarı → `#58CC02` · Hata → `#FF4B4B` · Freeze → `#1CB0F6`

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

## 2. Tipografi

**Font:** Nunito (Google Fonts) — geometrik, yuvarlak. Arapça: `Amiri` veya `Scheherazade New`.

| İsim | Boyut | Ağırlık | Kullanım |
|---|---|---|---|
| **Display** | 28sp | ExtraBold (800) | Kutlama başlıkları |
| **Title Large** | 22sp | Bold (700) | Ekran başlıkları |
| **Title Medium** | 18sp | Bold (700) | Kart başlıkları, bölüm adları |
| **Body Large** | 16sp | SemiBold (600) | Ana içerik, buton metni |
| **Body Medium** | 14sp | Regular (400) | Açıklamalar, ikincil bilgi |
| **Label** | 12sp | Bold (700) | Badge etiketleri, ALL CAPS stats |
| **Caption** | 11sp | Regular (400) | Zaman damgası, küçük notlar |

Buton metni ALL CAPS, noktalama yok. Ekran başlıkları Sentence case. Sayılar her zaman rakamla. Satır yüksekliği 1.4x.

---

## 3. Spacing & Radius

**Taban: 8px.** Tüm boşluklar bu birimin katı.

| Token | Değer | Kullanım |
|---|---|---|
| `space-xs` | 4px | İkon-metin arası |
| `space-sm` | 8px | Kart iç padding küçük |
| `space-md` | 16px | Standart padding, kart arası |
| `space-lg` | 24px | Bölüm arası |
| `space-xl` | 32px | Ekran üst/alt padding |

Ekran kenar boşluğu: sol/sağ/üst/alt `16px`.

| Token | Değer | Kullanım |
|---|---|---|
| `radius-sm` | 8px | Küçük chip, tag |
| `radius-md` | 12px | Kart, input |
| `radius-lg` | 16px | Büyük kart, seçim kartları |
| `radius-xl` | 24px | Bottom sheet, modal |
| `radius-full` | 999px | Butonlar, pill badge, avatar |

---

## 4. Bileşenler

### Primary Buton
`#2A7F8C` bg · `#1F6370` alt border 4px · beyaz ALL CAPS · radius-full · 52dp · full-width
- Pressed: translateY(+2px), alt border → 2px
- Disabled: `#E5E5E5` bg, `#ABABAB` metin, alt border yok
- Her ekranda tekil ve altta

### Secondary Buton (Outlined)
Şeffaf bg · 2px solid `#2A7F8C` · metin `#2A7F8C` ALL CAPS · radius-full · 52dp

### Seçim Kartı
`#FFFFFF` bg · 1.5px `#E5E5E5` border · radius-lg · 56dp · sol ikon + metin
Seçilince: 2px `#2A7F8C` border + `#E8F5F7` bg

### Zengin Seçim Kartı
72dp · 48dp renkli kare ikon (pastel bg, radius-md) + başlık Bold + açıklama Regular altında

### Stat Kart (3'lü yan yana)
Etiket ALL CAPS Label renkli · değer Title Large Bold renkli · 2px renkli border · radius-lg
Renkler: Hasanat altın · Sayfa yeşil · Seri turuncu

### Feedback Paneli (slide-up 250ms easeOut)
- Başarı: `#D7FFB8` · ✅ + mesaj + hasanat count-up (altın) · yeşil buton "DEVAM ET"
- Hata: `#FFDFE0` · ❌ + mesaj · teal buton "TAMAM"
- Seri tehlike: `#FFF3CD` · turuncu metin + buton

### İlerleme Çubuğu
8dp · `#E5E5E5` bg · `#2A7F8C` dolgu (tamamlanınca `#58CC02`) · radius-full · 500ms easeOut
Log girişinde sarı (`#FFC200`) — hız ve aciliyet hissi.

### Seri Takvimi (haftalık şerit)
- Tamamlandı: `#2A7F8C` dolu · beyaz ✓
- Bugün (yapılmadı): `#E5E5E5` kenarlı boş
- Kaçırıldı: `#E5E5E5` dolu gri
- Freeze: ❄️ `#1CB0F6`

### Cüz Düğmesi (56dp daire)
- Tamamlandı: `#2A7F8C` dolu ✓
- Aktif: `#2A7F8C` + beyaz ring + pulse 1000ms sinüsoidal
- Okunmamış: `#E5E5E5`

### Sure Seçim Chip'i
Seçilmemiş: beyaz bg · `#E5E5E5` border · radius-full
Seçilmiş: `#E8F5F7` bg · 2px `#2A7F8C` border

---

## 5. Animasyon

| Tür | Süre | Easing |
|---|---|---|
| Buton press | 100ms | easeIn |
| Disabled → enabled | 0ms | anlık |
| Feedback panel slide-up | 250ms | easeOut |
| Ekran geçişi | 300ms | easeInOut |
| Kutlama burst / konfeti | 400ms | easeOut |
| Progress bar dolumu | 500ms | easeOut |
| Seri pulse | 1000ms | sinüsoidal döngü |

**Haptic:**

| Durum | Titreşim |
|---|---|
| Başarılı log | Medium impact |
| Hata | Notification error |
| Buton tap | Light impact |
| Seri kırıldı | Heavy impact |
| Hatim tamamlandı | Success notification |

---

## 6. İkonografi

| İkon | Anlam | Renk |
|---|---|---|
| 🔥 Alev | Seri | `#FF9600` — değişmez |
| ✨ Işıltı | Hasanat | `#FFC200` — değişmez |
| ❄️ Kar | Freeze | `#1CB0F6` |
| 🏆 Kupa | Liderboard sırası | Altın/gümüş/bronz |
| ✅ Daire onay | Tamamlandı | `#58CC02` |

Boyutlar: 20dp (nav) · 24dp (içerik) · 32dp (vurgu). Phosphor Icons veya Lucide. Dolgu ikon aktif, outline pasif.

---

## 7. Ekran Şablonu

```
[Status Bar]
[Üst Bar: logo/başlık sol | 🔥 seri + ✨ hasanat sağ]
─────────────────────────────────────────
[Ana İçerik — max 3-4 odak noktası, whitespace bol]
─────────────────────────────────────────
[Primary Buton — altta sabit]
[Bottom Nav: Hatimlerim | Ekipler | Profil | Vird]
```

Alt ekranlar (log girişi, detay vb.): `[X kapat | sarı progress bar | —]`

Alt nav: aktif sekme `#2A7F8C` ikon + etiket + üstte ince teal çizgi · pasif `#ABABAB`.

---

## 8. Tasarım Prensipleri

1. **Her ekranda tek ana aksiyon** — buton tekil ve altta
2. **Disabled → enabled geçişi anlık** — seçimle bekletmeden aktif
3. **Whitespace agresif kullan** — ekranı doldurmak zorunda değilsin
4. **Renk anlamı sabittir** — asla karıştırma
5. **İstatistik barı her ekranda sabit** — kullanıcı bağlamını kaybetmez
6. **Tamamlama kutlaması full-screen** — modal değil, ekran geçişi
7. **Log ekranında progress bar sarı** — hız ve aciliyet hissi
8. **Kart etiketi ALL CAPS** — hiyerarşiyi stil kurar, boyut değil
9. **Seçim kartlarında ikon + metin** — taramayı hızlandırır
10. **Cesur ol** — logo büyük, renkler canlı, küçük düşünme
11. **Duygusallık taşı** — her başarı, seri, hatim anı duygusal anlam taşır
12. **Gri soğuktur** — disabled/border dışında gri kullanma, pastel tercih et
13. **Sivri şekil yoktur** — her köşe, buton, kart yuvarlak
14. **Her animasyon bilgi verir** — dekoratif animasyon yok

---

## 9. Yazı Dili & Ton

| Özellik | Evet | Hayır |
|---|---|---|
| **Sıcak** | Samimi, teşvik edici | Kurumsal, mesafeli |
| **Neşeli** | Hafif mizah, coşku | Abartılı, sahte |
| **Saygılı** | Dinî hassasiyete özen | Aşırı övgü, küçümseme |
| **Net** | Kısa, açık yönlendirme | Belirsiz, uzun |

**Ton:** Kutlamada coşkulu · Hata/uyarıda yönlendirici · Seri tehlikesinde hafif endişe, yıkıcı değil.

**Metin kuralları:**
- Buton: ALL CAPS, eylem fiili — "DEVAM ET" "KAYDET" "TAMAM" "BAŞLAT"
- Başlık: Sentence case, nokta yok, ünlem olabilir
- Bildirim: kişisel ve destekleyici — "Bugün de oku, seri'ini koru!" ✓ / "Okumadın." ✗
- Sayılar: her zaman rakamla — "3 sayfa" "10 gün" "1 cüz"
- Büyük harfli Vird terimleri: Seri, Hatim, Hasanat, Freeze, Kuran Haritası
- Küçük yazılan genel terimler: sayfa, cüz, sure, hedef, ekip

| Durum | ✓ Doğru | ✗ Yanlış |
|---|---|---|
| Hatim tamamlama | "Hatim tamamlandı! Maşallah 🎉" | "Tebrikler, görevi tamamladınız." |
| Seri kırıldı | "Bugün okuyarak Seri'ini geri kazan!" | "Seri kırıldı. Yarın tekrar dene." |
| İlk giriş | "Bismillah. Okuma yolculuğuna hoş geldin." | "Hesabınız oluşturuldu." |
| Boş durum | "Henüz hatim yok. İlk hatimini başlat!" | "Herhangi bir hatim bulunamadı." |

---

## 10. Gölge & Zemin

- Kart gölgesi: `0 2px 8px rgba(0,0,0,0.08)`
- Buton alt gölgesi: `4px solid #1F6370`
- Splash: `#2A7F8C` düz zemin (degrade yok), beyaz logo ortalanmış
- Pastel zemin: nesne gösterirken `#E8F5F7` veya `#FFF3CD` — açık gri değil

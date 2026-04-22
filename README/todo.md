# Vird — Görev Listesi

## Modül 1: Kurulum ✅ (2026-04-21)

- [x] Flutter SDK kuruldu (C:\Users\HUAWEI\flutter)
- [x] Android Studio + Android SDK (D:\Android\Sdk) kuruldu
- [x] NDK kuruldu (bozuk indi, silindi, otomatik yeniden kuruldu)
- [x] Pixel 8 emülatörü oluşturuldu (API 35)
- [x] Flutter projesi oluşturuldu: D:\Coding\vird_app
- [x] chrome'da flutter run çalışıyor (`$env:PATH += ";D:\Android\Sdk\platform-tools\platform-tools"` gerekiyor her seferinde)
- [x] 4 sekmeli BottomNavigationBar iskeleti (Hatimlerim, Ekipler, Profil, Vird)
- [x] AppColors paleti hazır
- [x] Google Fonts (Nunito) entegre edildi
- [x] Vird sekmesi logolu, diğer sekmeler ikonlu
- [x] Tüm dökümanlar D:\Coding\vird_app altında toplandı

## Notlar
- adb her oturumda manuel PATH'e ekleniyor: `$env:PATH += ";D:\Android\Sdk\platform-tools\platform-tools"`
- Emülatör RAM sorunu var, şimdilik Chrome'da geliştirme yapılıyor

---

## Modül 2: Auth & Profil — TAMAMLANDI (22 Nisan 2026)

- [x] Firebase entegrasyonu yapıldı (Authentication & Firestore Test Modu).
- [x] Onboarding ekranı `SharedPreferences` ile entegre edilip sadece ilk açılışta gösterilmesi sağlandı.
- [x] E-posta/Şifre ile Kayıt Ol ve Giriş Yap sayfaları oluşturuldu.
- [x] **Ekstra:** Firebase `signInWithPopup` ile Web için "Google ile Giriş Yap / Kayıt Ol" özelliği butonu ve altyapısı eklendi.
- [x] `AuthWrapper` yazılarak giriş durumuna göre (Giriş yaptıysa MainScreen, yapmadıysa LoginScreen) otomatik yönlendirme sağlandı.
- [x] Profil sekmesi Firestore'a bağlanarak ismin, şehrin ve üniversitenin canlı olarak çekildiği dinamik bir karta çevrildi.
- [x] **Ekstra:** Profil sayfasında anında güncellemeler yapabilmek için (sayfa değiştirmeden) alttan açılan (BottomSheet) "Profili Güncelle" ekranı yapıldı.
- [x] **Ekstra:** `dropdown_search` paketi ile "Şehir" ve "Üniversite" alanlarına arama yapılabilen gelişmiş menüler bağlandı (Tüm iller ve üniversiteler eklendi, özel Türkçe karakter filtresi yazıldı).
- [x] **Ekstra:** Profil sayfasında İsim güncelleme özelliği eklendi.
- [x] **Ekstra:** Firebase Storage kısıtlamalarına/maliyetlerine takılmamak adına 20 adet Premium Avatar (DiceBear Micah) seçimi yapıldı, profil fotoğrafları sıfır maliyetle sisteme entegre edildi.

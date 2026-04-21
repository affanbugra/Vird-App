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

## Modül 2: Auth — Yapılacaklar

- [ ] Firebase projesi oluştur (console.firebase.google.com)
- [ ] FlutterFire CLI ile projeye bağla
- [ ] Google Sign-In + Email/Password auth entegre et
- [ ] Giriş ekranı (splash → onboarding → login)
- [ ] Kayıt ekranı (isim, kullanıcı adı, email zorunlu; şehir/üniversite opsiyonel)
- [ ] Profil oluşturma adımı (kayıt sonrası)
- [ ] Auth state yönetimi (giriş yapıldıysa ana ekran, yoksa login)

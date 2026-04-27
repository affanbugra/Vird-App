# Vird App Tasarım Sistemi

## Ana Butonlar (Duolingo Stili)
Uygulama içindeki ana aksiyon butonları (örn: "DEVAM ET", "KAYDET" gibi) fiziksel basılma hissiyatı (3D derinlik) veren "Duolingo Stili" buton yapısına geçirilmiştir.

### Kullanım
Yeni veya değiştirilecek bir ana buton için standart `ElevatedButton` yerine, `DuolingoButton` bileşeni kullanılmalıdır.

```dart
import '../widgets/duolingo_button.dart';

DuolingoButton(
  color: AppColors.teal,
  bottomColor: AppColors.tealDark,
  disabledColor: AppColors.borderGrey,
  onPressed: () { /* Aksiyon */ },
  isLoading: false,
  child: Text('KAYDET', style: ...),
)
```

### Özellikler
- **Derinlik (Depth):** Alt kısımda 4 piksellik gölge yerine katı bir renk (`bottomColor`) kullanılarak fiziksel kalınlık verilir.
- **Etkileşim:** Butona tıklandığında üst katman 4 piksel aşağı kayarak basılma hissi yaratır.
- **Yükleniyor (Loading) Durumu:** `isLoading` parametresi `true` olduğunda buton tıklanamaz hale gelir ve ortasında beyaz bir `CircularProgressIndicator` döner.
- **İnaktif (Disabled) Durumu:** `onPressed` fonksiyonu `null` olarak verildiğinde veya `isLoading` `true` olduğunda buton basılı/çökmüş görünümde kalır ve `disabledColor` rengini alır.
- **Şekil (Border Radius):** `borderRadius` parametresi ile butonun köşeleri ayarlanabilir. Varsayılan olarak tam yuvarlak (`999.0`) şeklindedir, ancak kare formunda butonlar (örneğin ekipler logoları için `16.0` veya `28.0`) yapılabilir.

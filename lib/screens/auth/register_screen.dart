import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../app_colors.dart';
import '../../app_theme.dart';
import '../../providers/auth_provider.dart';
import 'profile_setup_screen.dart';

String _parseAuthError(dynamic e) {
  if (e is FirebaseAuthException) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'Bu e-posta adresi zaten kullanımda.';
      case 'invalid-email':
        return 'Geçersiz e-posta adresi.';
      case 'weak-password':
        return 'Şifre en az 6 karakter olmalıdır.';
      case 'too-many-requests':
        return 'Çok fazla deneme. Lütfen birkaç dakika sonra tekrar deneyin.';
      case 'network-request-failed':
        return 'İnternet bağlantısı yok. Bağlantını kontrol et.';
      case 'popup-closed-by-user':
      case 'cancelled-by-user':
        return 'Google girişi iptal edildi.';
      case 'unauthorized-domain':
        return 'Bu alan adı Google girişi için yetkilendirilmemiş.';
      case 'popup-blocked':
        return 'Açılır pencere engellendi. Tarayıcı ayarlarını kontrol et.';
      case 'account-exists-with-different-credential':
        return 'Bu e-posta başka bir giriş yöntemiyle kayıtlı. E-posta ve şifreyle dene.';
      default:
        return 'Bir hata oluştu: ${e.code}. Lütfen tekrar deneyin.';
    }
  }
  return 'Bir hata oluştu. Lütfen tekrar deneyin.';
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _cinsiyet;

  Future<void> _handleRegister() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) return;
    if (_cinsiyet == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen cinsiyet seçimi yapınız.')),
      );
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Şifre en az 6 karakter olmalıdır.')),
      );
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geçersiz e-posta adresi.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await context.read<AuthProvider>().registerWithEmail(email, password);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_parseAuthError(e))),
        );
        setState(() => _isLoading = false);
      }
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await user.updateDisplayName(name);
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'name': name,
          'email': user.email,
          'city': '',
          'university': '',
          'createdAt': FieldValue.serverTimestamp(),
          'isPro': false,
          'proExpiresAt': null,
          'hasanat': 0,
          'seri': 0,
          'totalPages': 0,
          'hatimCount': 0,
          'cinsiyet': _cinsiyet, // 'hanim' veya 'bey'
        });
      } catch (e) {
        debugPrint('Profil Firestore yazma hatası: $e');
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ProfileSetupScreen(name: name),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.colors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Yeni Hesap Oluştur',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: context.colors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'Kuran hedeflerini takip etmeye başlamak için aramıza katıl.',
                style: TextStyle(color: context.colors.textSecondary),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                maxLength: 50,
                decoration: InputDecoration(
                  labelText: 'İsim Soyisim',
                  counterText: '',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                maxLength: 100,
                decoration: InputDecoration(
                  labelText: 'E-posta',
                  counterText: '',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _isLoading ? null : _handleRegister(),
                maxLength: 64,
                decoration: InputDecoration(
                  labelText: 'Şifre',
                  counterText: '',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),
              // --- CİNSİYET SEÇİMİ ---
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, size: 11, color: Color(0xFFBBAB00)),
                      const SizedBox(width: 4),
                      const Expanded(
                        child: Text(
                          'Bu seçim yalnızca bir kez yapılabilir ve daha sonra değiştirilemez. Lütfen doğru seçeneği işaretlediğinizden emin olunuz.',
                          style: TextStyle(fontSize: 10, color: Color(0xFFAA9000), height: 1.4),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _CinsiyetToggle(
                    secili: _cinsiyet,
                    onChanged: (val) => setState(() => _cinsiyet = val),
                  ),
                  if (_cinsiyet == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 4),
                      child: Text(
                        'Lütfen bir seçenek belirtin.',
                        style: TextStyle(fontSize: 11, color: Colors.red.shade400),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _handleRegister,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white))
                    : const Text('Kayıt Ol', style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('VEYA', style: TextStyle(color: context.colors.textSecondary)),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _isLoading
                    ? null
                    : () async {
                        setState(() => _isLoading = true);
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await context.read<AuthProvider>().signInWithGoogle();
                        } catch (e) {
                          messenger.showSnackBar(
                            SnackBar(content: Text(_parseAuthError(e))),
                          );
                        } finally {
                          if (mounted) setState(() => _isLoading = false);
                        }
                      },
                icon: Image.asset('assets/images/google_logo.png', height: 22),
                label: Text('Google ile Kayıt Ol', style: TextStyle(color: context.colors.textPrimary)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(color: context.colors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hanımefendi / Beyefendi — kayan toggle seçimi
class _CinsiyetToggle extends StatelessWidget {
  final String? secili;
  final ValueChanged<String> onChanged;

  const _CinsiyetToggle({required this.secili, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final bool isHanim = secili == 'hanim';
    final bool isBey = secili == 'bey';

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: context.colors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border, width: 1),
      ),
      padding: const EdgeInsets.all(4),
      child: Stack(
        children: [
          if (secili != null)
            AnimatedAlign(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeInOut,
              alignment: isHanim ? Alignment.centerLeft : Alignment.centerRight,
              child: FractionallySizedBox(
                widthFactor: 0.5,
                child: Container(
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.10),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => onChanged('hanim'),
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 220),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isHanim ? FontWeight.w700 : FontWeight.w500,
                        color: isHanim ? context.colors.textPrimary : context.colors.textTertiary,
                      ),
                      child: const Text('Hanımefendi'),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => onChanged('bey'),
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 220),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isBey ? FontWeight.w700 : FontWeight.w500,
                        color: isBey ? context.colors.textPrimary : context.colors.textTertiary,
                      ),
                      child: const Text('Beyefendi'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

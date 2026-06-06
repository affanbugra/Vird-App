import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../app_colors.dart';
import '../../app_theme.dart';
import '../../providers/auth_provider.dart';

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

  Future<void> _handleRegister() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) return;

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
          // cinsiyet ProfileSetupScreen'de alınır (requiresCinsiyet: true)
        });
      } catch (e) {
        debugPrint('Profil Firestore yazma hatası: $e');
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
      // ProfilSetup'ı manuel pushlamak yerine AuthWrapper'a bırakıyoruz.
      // E-posta kaydı sonrası AuthProvider'da needsProfileSetup true yapıldığı için root (AuthWrapper)
      // otomatik olarak ProfileSetupScreen'i gösterecektir. Sadece RegisterScreen'i aradan çıkarıyoruz.
      Navigator.popUntil(context, (route) => route.isFirst);
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
                          if (mounted) {
                            Navigator.popUntil(context, (route) => route.isFirst);
                          }
                        } catch (e) {
                          if (mounted) {
                            messenger.showSnackBar(
                              SnackBar(content: Text(_parseAuthError(e))),
                            );
                          }
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


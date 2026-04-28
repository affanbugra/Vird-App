import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../app_colors.dart';
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
      default:
        return 'Bir hata oluştu. Lütfen tekrar deneyin.';
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

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.updateDisplayName(name);
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'name': name,
          'email': user.email,
          'city': '',
          'university': '',
          'createdAt': FieldValue.serverTimestamp(),
          'isPro': false,
          'hasanat': 0,
          'seri': 0,
          'totalPages': 0,
          'hatimCount': 0,
        });
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ProfileSetupScreen(name: name),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_parseAuthError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Yeni Hesap Oluştur',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textDark),
              ),
              const SizedBox(height: 8),
              const Text(
                'Kuran hedeflerini takip etmeye başlamak için aramıza katıl.',
                style: TextStyle(color: AppColors.textMid),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'İsim Soyisim',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'E-posta',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Şifre',
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
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('VEYA', style: TextStyle(color: AppColors.textMid)),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _isLoading
                    ? null
                    : () async {
                        setState(() => _isLoading = true);
                        try {
                          await context.read<AuthProvider>().signInWithGoogle();
                          // Yönlendirme main.dart tarafından otomatik yapılacak
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(_parseAuthError(e))),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _isLoading = false);
                        }
                      },
                icon: Image.network(
                  'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/120px-Google_%22G%22_logo.svg.png',
                  height: 24,
                  errorBuilder: (_, _, _) => const Text('G', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4285F4))),
                ),
                label: const Text('Google ile Kayıt Ol', style: TextStyle(color: AppColors.textDark)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: const BorderSide(color: AppColors.borderGrey),
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

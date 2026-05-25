import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app_colors.dart';
import '../../app_theme.dart';

class MagicLinkConfirmScreen extends StatefulWidget {
  final String link;
  const MagicLinkConfirmScreen({super.key, required this.link});

  @override
  State<MagicLinkConfirmScreen> createState() => _MagicLinkConfirmScreenState();
}

class _MagicLinkConfirmScreenState extends State<MagicLinkConfirmScreen> {
  final _emailCtrl = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) return;
    setState(() { _isLoading = true; _error = null; });
    try {
      await FirebaseAuth.instance.signInWithEmailLink(
        email: email,
        emailLink: widget.link,
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _error = switch (e.code) {
            'invalid-action-code' => 'Bu bağlantı artık geçerli değil. Yeni bir bağlantı gönder.',
            'expired-action-code' => 'Bağlantının süresi dolmuş. Yeni bir bağlantı gönder.',
            'invalid-email' => 'E-posta adresi hatalı.',
            'user-disabled' => 'Bu hesap devre dışı bırakılmış.',
            _ => 'Giriş başarısız: ${e.code}',
          };
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _error = 'Bir hata oluştu.'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.link_rounded, size: 56, color: AppColors.teal),
              const SizedBox(height: 24),
              Text(
                'Giriş Bağlantısı',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Giriş yapabilmek için hesabınızın e-posta adresini girin.',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(fontSize: 14, color: context.colors.textSecondary),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'E-posta',
                  labelStyle: GoogleFonts.nunito(color: context.colors.textSecondary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.teal, width: 2),
                  ),
                  errorText: _error,
                ),
                onSubmitted: (_) => _confirm(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _confirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('Giriş Yap',
                          style: GoogleFonts.nunito(
                            fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

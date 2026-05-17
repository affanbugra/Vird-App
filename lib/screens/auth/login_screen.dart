import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import '../../app_colors.dart';
import '../../app_assets.dart';
import '../../providers/auth_provider.dart';
import 'register_screen.dart';

Future<void> _showForgotPasswordSheet(BuildContext context) async {
  final emailController = TextEditingController();
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _ForgotPasswordSheet(emailController: emailController),
  );
  emailController.dispose();
}

class _ForgotPasswordSheet extends StatefulWidget {
  final TextEditingController emailController;
  const _ForgotPasswordSheet({required this.emailController});

  @override
  State<_ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<_ForgotPasswordSheet> {
  bool _isLoading = false;
  bool _sent = false;

  Future<void> _send() async {
    final email = widget.emailController.text.trim();
    if (email.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.setLanguageCode('tr');
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) setState(() { _isLoading = false; _sent = true; });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      final msg = e.code == 'user-not-found'
          ? 'Bu e-posta ile kayıtlı hesap bulunamadı.'
          : 'Bir hata oluştu. Tekrar dene.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: const EdgeInsets.all(12),
      padding: EdgeInsets.fromLTRB(24, 28, 24, 24 + bottom),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.all(Radius.circular(24)),
      ),
      child: _sent ? _SuccessContent() : _FormContent(
        emailController: widget.emailController,
        isLoading: _isLoading,
        onSend: _send,
        onClose: () => Navigator.pop(context),
      ),
    );
  }
}

class _FormContent extends StatelessWidget {
  final TextEditingController emailController;
  final bool isLoading;
  final VoidCallback onSend;
  final VoidCallback onClose;

  const _FormContent({
    required this.emailController,
    required this.isLoading,
    required this.onSend,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.tealLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_reset_rounded, color: AppColors.teal, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Şifreni Sıfırla',
                    style: GoogleFonts.nunito(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  Text(
                    'Mailine sıfırlama bağlantısı gönderelim',
                    style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textMid),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close, color: AppColors.textLight),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        const SizedBox(height: 24),
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
          style: GoogleFonts.nunito(fontSize: 15, color: AppColors.textDark),
          decoration: InputDecoration(
            labelText: 'E-posta adresi',
            labelStyle: GoogleFonts.nunito(color: AppColors.textMid),
            prefixIcon: const Icon(Icons.mail_outline_rounded, color: AppColors.textLight, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.borderGrey),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.borderGrey),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.teal, width: 2),
            ),
            filled: true,
            fillColor: AppColors.lightGrey,
          ),
        ),
        const SizedBox(height: 20),
        _PrimaryButton(
          onPressed: isLoading ? null : onSend,
          isLoading: isLoading,
          label: 'BAĞLANTI GÖNDER',
        ),
      ],
    );
  }
}

class _SuccessContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            color: AppColors.successBg,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.mark_email_read_outlined, color: AppColors.successGreen, size: 32),
        ),
        const SizedBox(height: 16),
        Text(
          'Bağlantı Gönderildi!',
          style: GoogleFonts.nunito(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Mailine bir sıfırlama bağlantısı gönderdik.\nBağlantıya tıklayıp yeni şifreni belirle.',
          textAlign: TextAlign.center,
          style: GoogleFonts.nunito(fontSize: 14, color: AppColors.textMid, height: 1.5),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: _PrimaryButton(
            onPressed: () => Navigator.pop(context),
            isLoading: false,
            label: 'TAMAM',
          ),
        ),
      ],
    );
  }
}

String _parseAuthError(dynamic e) {
  if (e is FirebaseAuthException) {
    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-posta veya şifre hatalı.';
      case 'invalid-email':
        return 'Geçersiz e-posta adresi.';
      case 'user-disabled':
        return 'Bu hesap devre dışı bırakıldı.';
      case 'too-many-requests':
        return 'Çok fazla deneme. Birkaç dakika sonra tekrar dene.';
      case 'network-request-failed':
        return 'İnternet bağlantısı yok. Bağlantını kontrol et.';
      case 'popup-closed-by-user':
      case 'cancelled-by-user':
        return 'Google girişi iptal edildi.';
      case 'unauthorized-domain':
        return 'Bu alan adı yetkilendirilmemiş.';
      case 'popup-blocked':
        return 'Açılır pencere engellendi. Tarayıcı ayarlarını kontrol et.';
      case 'account-exists-with-different-credential':
        return 'Bu e-posta başka bir giriş yöntemiyle kayıtlı. E-posta ve şifreyle dene.';
      default:
        return 'Bir hata oluştu: ${e.code}. Tekrar dene.';
    }
  }
  return 'Bir hata oluştu. Tekrar dene.';
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      await context.read<AuthProvider>().signInWithEmail(
            _emailController.text.trim(),
            _passwordController.text.trim(),
          );
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Image.asset(AppAssets.logo, height: 72),
              const SizedBox(height: 28),
              Text(
                "Hoş Geldin!",
                style: GoogleFonts.nunito(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                "Düzenli okumalarla Hasanat biriktirir,\nkalıcı bir alışkanlık kazanırsın.",
                style: GoogleFonts.nunito(fontSize: 14, color: AppColors.textMid, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),
              AutofillGroup(
                child: Column(
                  children: [
                    _InputField(
                      controller: _emailController,
                      label: 'E-posta',
                      icon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                    ),
                    const SizedBox(height: 12),
                    _InputField(
                      controller: _passwordController,
                      label: 'Şifre',
                      icon: Icons.lock_outline_rounded,
                      obscureText: _obscurePassword,
                      autofillHints: const [AutofillHints.password],
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: AppColors.textLight,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _showForgotPasswordSheet(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Şifremi unuttum',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: AppColors.teal,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _PrimaryButton(
                onPressed: _isLoading ? null : _handleLogin,
                isLoading: _isLoading,
                label: 'GİRİŞ YAP',
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Expanded(child: Divider(color: AppColors.borderGrey)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'VEYA',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textLight,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider(color: AppColors.borderGrey)),
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
                label: Text(
                  'Google ile Giriş Yap',
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AppColors.borderGrey, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Hesabın yok mu? ',
                    style: GoogleFonts.nunito(fontSize: 14, color: AppColors.textMid),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                    ),
                    child: Text(
                      'Kayıt Ol',
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.teal,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final List<String>? autofillHints;
  final Widget? suffixIcon;

  const _InputField({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.autofillHints,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      style: GoogleFonts.nunito(fontSize: 15, color: AppColors.textDark),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.nunito(color: AppColors.textMid, fontSize: 14),
        prefixIcon: Icon(icon, color: AppColors.textLight, size: 20),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderGrey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderGrey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.teal, width: 2),
        ),
        filled: true,
        fillColor: AppColors.lightGrey,
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  final String label;

  const _PrimaryButton({
    required this.onPressed,
    required this.isLoading,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        height: 52,
        decoration: BoxDecoration(
          color: disabled ? AppColors.borderGrey : AppColors.teal,
          borderRadius: BorderRadius.circular(999),
          border: Border(
            bottom: BorderSide(
              color: disabled ? Colors.transparent : AppColors.tealDark,
              width: 4,
            ),
          ),
        ),
        alignment: Alignment.center,
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
              )
            : Text(
                label,
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: disabled ? AppColors.textLight : Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }
}


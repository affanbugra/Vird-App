import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_colors.dart';
import '../app_theme.dart';

class MandatorySetupSheet extends StatefulWidget {
  final Map<String, dynamic> userData;

  const MandatorySetupSheet({super.key, required this.userData});

  static Future<void> show(BuildContext context, Map<String, dynamic> userData) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => WillPopScope(
        onWillPop: () async => false, // Kapatılamaz yap
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: MandatorySetupSheet(userData: userData),
        ),
      ),
    );
  }

  @override
  State<MandatorySetupSheet> createState() => _MandatorySetupSheetState();
}

class _MandatorySetupSheetState extends State<MandatorySetupSheet> {
  bool _isLoading = false;
  String? _selectedCinsiyet;
  bool _cinsiyetError = false;

  final _usernameCtrl = TextEditingController();
  String? _usernameStatus;
  String? _usernameErrorText;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // Mevcut verileri doldur
    _selectedCinsiyet = widget.userData['cinsiyet'] as String?;
    final existingUsername = widget.userData['username'] as String?;
    if (existingUsername != null && existingUsername.isNotEmpty) {
      _usernameCtrl.text = existingUsername;
      _usernameStatus = 'available';
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _usernameCtrl.dispose();
    super.dispose();
  }

  void _onUsernameChanged(String value) {
    _debounce?.cancel();
    final trimmed = value.trim().toLowerCase();

    if (trimmed.isEmpty) {
      setState(() {
        _usernameStatus = null;
        _usernameErrorText = null;
      });
      return;
    }
    if (trimmed.length < 3) {
      setState(() {
        _usernameStatus = 'invalid';
        _usernameErrorText = 'En az 3 karakter olmalı.';
      });
      return;
    }
    if (trimmed.length > 20) {
      setState(() {
        _usernameStatus = 'invalid';
        _usernameErrorText = 'En fazla 20 karakter olabilir.';
      });
      return;
    }
    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(trimmed)) {
      setState(() {
        _usernameStatus = 'invalid';
        _usernameErrorText = 'Sadece harf, rakam ve _ kullanabilirsin.';
      });
      return;
    }

    setState(() {
      _usernameStatus = 'loading';
      _usernameErrorText = null;
    });
    _debounce = Timer(const Duration(milliseconds: 600), () => _checkUnique(trimmed));
  }

  Future<void> _checkUnique(String username) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: username)
          .get();
      final isCurrentUser = query.docs.length == 1 && query.docs.first.id == currentUid;
      final taken = query.docs.isNotEmpty && !isCurrentUser;
      if (mounted) {
        setState(() {
          _usernameStatus = taken ? 'taken' : 'available';
          _usernameErrorText = taken ? 'Bu kullanıcı adı zaten alınmış.' : null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _usernameStatus = 'invalid';
          _usernameErrorText = 'Kontrol sırasında hata oluştu.';
        });
      }
    }
  }

  bool get _canSave {
    if (_selectedCinsiyet == null) return false;
    if (_usernameStatus != 'available' || _usernameCtrl.text.trim().isEmpty) return false;
    return true;
  }

  Future<void> _saveProfileInfo() async {
    if (!_canSave) {
      if (_selectedCinsiyet == null) setState(() => _cinsiyetError = true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'username': _usernameCtrl.text.trim().toLowerCase(),
          'cinsiyet': _selectedCinsiyet,
        }, SetOptions(merge: true));
      }
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profil kaydedilirken hata: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: context.colors.border,
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Zorunlu Kurulum',
            style: GoogleFonts.nunito(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: context.colors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Uygulamayı kullanmaya devam edebilmek için kullanıcı adı ve cinsiyet seçimi yapmanız gerekmektedir.',
            style: GoogleFonts.nunito(
              fontSize: 14,
              color: context.colors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          
          // Cinsiyet Seçimi
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Cinsiyet',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text('*', style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.info_outline, size: 11, color: Color(0xFFBBAB00)),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Text(
                      'Bu seçim yalnızca bir kez yapılabilir ve daha sonra değiştirilemez.',
                      style: TextStyle(fontSize: 10, color: Color(0xFFAA9000), height: 1.4),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _CinsiyetToggle(
                secili: _selectedCinsiyet,
                onChanged: (val) => setState(() {
                  _selectedCinsiyet = val;
                  _cinsiyetError = false;
                }),
              ),
              if (_cinsiyetError)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: Text(
                    'Lütfen bir seçenek belirtin.',
                    style: TextStyle(fontSize: 11, color: Colors.red.shade400),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),

          // Kullanıcı Adı Seçimi
          Row(
            children: [
              Text(
                'Kullanıcı Adı',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textSecondary,
                ),
              ),
              const SizedBox(width: 4),
              const Text('*', style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          _UsernameField(
            controller: _usernameCtrl,
            status: _usernameStatus,
            errorText: _usernameErrorText,
            onChanged: _onUsernameChanged,
          ),
          const SizedBox(height: 6),
          Text(
            'Harf, rakam ve _ kullanabilirsin · En az 3, en fazla 20 karakter',
            style: GoogleFonts.nunito(fontSize: 10.5, color: context.colors.textTertiary),
          ),
          const SizedBox(height: 32),

          ElevatedButton(
            onPressed: (_isLoading || !_canSave) ? null : _saveProfileInfo,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.teal,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white))
                : const Text('Kaydet ve Devam Et', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _UsernameField extends StatelessWidget {
  final TextEditingController controller;
  final String? status;
  final String? errorText;
  final ValueChanged<String> onChanged;

  const _UsernameField({
    required this.controller,
    required this.status,
    required this.errorText,
    required this.onChanged,
  });

  Widget? _buildSuffix() {
    if (status == 'loading') {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (status == 'available') return const Icon(Icons.check_circle_outline, color: AppColors.teal, size: 20);
    if (status == 'taken' || status == 'invalid') return Icon(Icons.cancel_outlined, color: Colors.red, size: 20);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final hasError = (status == 'taken' || status == 'invalid') && errorText != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          onChanged: onChanged,
          maxLength: 20,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            prefixText: '@',
            prefixStyle: GoogleFonts.nunito(
              color: AppColors.teal,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
            counterText: '',
            hintText: 'kullanici_adi',
            hintStyle: GoogleFonts.nunito(color: context.colors.textTertiary),
            suffixIcon: _buildSuffix(),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: status == 'available' ? AppColors.teal : (hasError ? Colors.red : AppColors.teal),
                width: 2,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: hasError ? Colors.red.shade300 : context.colors.border,
              ),
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 5, left: 4),
            child: Text(errorText!, style: TextStyle(fontSize: 11, color: Colors.red.shade400)),
          ),
      ],
    );
  }
}

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
        border: Border.all(
          color: context.colors.border,
          width: 1,
        ),
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

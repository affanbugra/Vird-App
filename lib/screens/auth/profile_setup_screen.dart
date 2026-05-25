import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:provider/provider.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app_colors.dart';
import '../../app_theme.dart';
import '../../constants/app_constants.dart';
import '../../utils/text_utils.dart';
import '../../providers/auth_provider.dart';

class ProfileSetupScreen extends StatefulWidget {
  final String name;
  final bool requiresCinsiyet;
  const ProfileSetupScreen({super.key, required this.name, this.requiresCinsiyet = false});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  bool _isLoading = false;
  String? _selectedCity;
  String? _selectedUniversity;
  String? _selectedCinsiyet;
  bool _cinsiyetError = false;

  final _usernameCtrl = TextEditingController();
  String? _usernameStatus;
  String? _usernameErrorText;
  Timer? _debounce;

  late final List<String> _sortedCities;
  late final List<String> _sortedUniversities;

  @override
  void initState() {
    super.initState();
    _sortedCities = List.from(AppConstants.cities)..sort(_turkishCompare);
    _sortedUniversities = List.from(AppConstants.universities)..sort(_turkishCompare);
  }

  int _turkishCompare(String a, String b) {
    String normalizeForSort(String text) {
      return text.toLowerCase()
          .replaceAll('ç', 'cz')
          .replaceAll('ğ', 'gz')
          .replaceAll('ı', 'hz')
          .replaceAll('i', 'i')
          .replaceAll('ö', 'oz')
          .replaceAll('ş', 'sz')
          .replaceAll('ü', 'uz');
    }
    return normalizeForSort(a).compareTo(normalizeForSort(b));
  }

  bool _turkishSearchFilter(String item, String filter) => turkishContains(item, filter);

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
      setState(() { _usernameStatus = null; _usernameErrorText = null; });
      return;
    }
    if (trimmed.length < 3) {
      setState(() { _usernameStatus = 'invalid'; _usernameErrorText = 'En az 3 karakter olmalı.'; });
      return;
    }
    if (trimmed.length > 20) {
      setState(() { _usernameStatus = 'invalid'; _usernameErrorText = 'En fazla 20 karakter olabilir.'; });
      return;
    }
    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(trimmed)) {
      setState(() { _usernameStatus = 'invalid'; _usernameErrorText = 'Sadece harf, rakam ve _ kullanabilirsin.'; });
      return;
    }

    setState(() { _usernameStatus = 'loading'; _usernameErrorText = null; });
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
        setState(() { _usernameStatus = 'invalid'; _usernameErrorText = 'Kontrol sırasında hata oluştu.'; });
      }
    }
  }

  bool get _canSave {
    if (widget.requiresCinsiyet && _selectedCinsiyet == null) return false;
    if (_usernameStatus != 'available' || _usernameCtrl.text.trim().isEmpty) return false;
    return true;
  }

  Future<void> _saveProfileInfo() async {
    if (!_canSave) {
      if (widget.requiresCinsiyet && _selectedCinsiyet == null) setState(() => _cinsiyetError = true);
      return;
    }

    setState(() => _isLoading = true);

    final authProvider = context.read<AuthProvider>();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'name': widget.name,
          'email': user.email,
          'city': _selectedCity ?? '',
          'university': _selectedUniversity ?? '',
          'createdAt': FieldValue.serverTimestamp(),
          'username': _usernameCtrl.text.trim().toLowerCase(),
          if (widget.requiresCinsiyet && _selectedCinsiyet != null)
            'cinsiyet': _selectedCinsiyet,
        }, SetOptions(merge: true));
      }
      // Firestore başarılı → tamamla ve geç
      if (mounted) {
        authProvider.completeProfileSetup();
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } catch (e) {
      // Hata varsa sıkışıp kal, kullanıcı tekrar deneyebilir
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
    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: Icon(Icons.arrow_back, color: context.colors.textPrimary),
                onPressed: () => Navigator.pop(context),
              )
            : const SizedBox.shrink(),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Biraz Kendinden Bahset',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: context.colors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                widget.requiresCinsiyet
                    ? 'Cinsiyet seçimi zorunludur. Şehir ve üniversite isteğe bağlıdır.'
                    : 'Bu bilgiler ekip eşleşmelerinde ve profilinde görünecek. (İsteğe bağlı)',
                style: TextStyle(color: context.colors.textSecondary),
              ),
              const SizedBox(height: 32),
              if (widget.requiresCinsiyet) ...[  
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
              ],
              
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
              const SizedBox(height: 24),
              DropdownSearch<String>(
                items: (filter, loadProps) => _sortedCities,
                filterFn: _turkishSearchFilter,
                popupProps: const PopupProps.menu(
                  showSearchBox: true,
                  searchFieldProps: TextFieldProps(
                    decoration: InputDecoration(
                      hintText: "Şehir ara...",
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                decoratorProps: DropDownDecoratorProps(
                  decoration: InputDecoration(
                    labelText: 'Yaşadığın Şehir',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.location_city, color: AppColors.teal),
                  ),
                ),
                onSelected: (value) => setState(() => _selectedCity = value),
                selectedItem: _selectedCity,
              ),
              const SizedBox(height: 16),
              DropdownSearch<String>(
                items: (filter, loadProps) => _sortedUniversities,
                filterFn: _turkishSearchFilter,
                popupProps: const PopupProps.menu(
                  showSearchBox: true,
                  searchFieldProps: TextFieldProps(
                    decoration: InputDecoration(
                      hintText: "Üniversite ara...",
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                decoratorProps: DropDownDecoratorProps(
                  decoration: InputDecoration(
                    labelText: 'Üniversite',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.school, color: AppColors.teal),
                  ),
                ),
                onSelected: (value) => setState(() => _selectedUniversity = value),
                selectedItem: _selectedUniversity,
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
                    : const Text('Tamamla ve Başla', style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
              const SizedBox(height: 16),
              if (!widget.requiresCinsiyet)
                TextButton(
                  onPressed: () async {
                    final authProvider = context.read<AuthProvider>();
                    final user = FirebaseAuth.instance.currentUser;
                    if (user != null) {
                      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
                        'name': widget.name,
                        'email': user.email,
                        'city': '',
                        'university': '',
                        'createdAt': FieldValue.serverTimestamp(),
                      }, SetOptions(merge: true));
                    }
                    authProvider.completeProfileSetup();
                    if (context.mounted) {
                      Navigator.popUntil(context, (route) => route.isFirst);
                    }
                  },
                  child: Text('Bu adımı atla', style: TextStyle(color: context.colors.textSecondary)),
                ),
            ],
          ),
        ),
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
    if (status == 'taken' || status == 'invalid') return Icon(Icons.cancel_outlined, color: Colors.red.shade400, size: 20);
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

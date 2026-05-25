import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:provider/provider.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../../app_colors.dart';
import '../../app_theme.dart';
import '../../constants/app_constants.dart';
import '../../utils/text_utils.dart';
import '../../providers/auth_provider.dart';

class ProfileSetupScreen extends StatefulWidget {
  final String name;
  const ProfileSetupScreen({super.key, required this.name});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  bool _isLoading = false;
  String? _selectedCity;
  String? _selectedUniversity;

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

  Future<void> _saveProfileInfo() async {
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
        }, SetOptions(merge: true));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profil kaydedilirken hata: $e')),
        );
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
      authProvider.completeProfileSetup();
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
                'Bu bilgiler ekip eşleşmelerinde ve profilinde görünecek. (İsteğe bağlı)',
                style: TextStyle(color: context.colors.textSecondary),
              ),
              const SizedBox(height: 32),
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
                onPressed: _isLoading ? null : _saveProfileInfo,
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

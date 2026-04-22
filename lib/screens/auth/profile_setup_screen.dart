import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../../app_colors.dart';
import '../../constants/app_constants.dart';

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

  bool _turkishSearchFilter(String item, String filter) {
    if (filter.isEmpty) return true;
    String normalize(String text) {
      return text.toLowerCase()
          .replaceAll('ı', 'i')
          .replaceAll('i̇', 'i')
          .replaceAll('ğ', 'g')
          .replaceAll('ü', 'u')
          .replaceAll('ş', 's')
          .replaceAll('ö', 'o')
          .replaceAll('ç', 'c');
    }
    return normalize(item).contains(normalize(filter));
  }

  Future<void> _saveProfileInfo() async {
    setState(() => _isLoading = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'name': widget.name,
          'email': user.email,
          'city': _selectedCity ?? 'Şehir belirtilmedi',
          'university': _selectedUniversity ?? 'Üniversite belirtilmedi',
          'createdAt': FieldValue.serverTimestamp(),
        });
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
      Navigator.popUntil(context, (route) => route.isFirst);
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
                'Biraz Kendinden Bahset',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textDark),
              ),
              const SizedBox(height: 8),
              const Text(
                'Bu bilgiler ekip eşleşmelerinde ve profilinde görünecek. (İsteğe bağlı)',
                style: TextStyle(color: AppColors.textMid),
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
                onSelected: (value) {
                  setState(() {
                    _selectedCity = value;
                  });
                },
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
                onSelected: (value) {
                  setState(() {
                    _selectedUniversity = value;
                  });
                },
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
                onPressed: () {
                  // Atla butonu - Profil bilgilerini girmeden devam et
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
                child: const Text('Bu adımı atla', style: TextStyle(color: AppColors.textMid)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

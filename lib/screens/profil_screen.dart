import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:dropdown_search/dropdown_search.dart';
import '../app_colors.dart';
import '../providers/auth_provider.dart';
import '../constants/app_constants.dart';

class ProfilScreen extends StatefulWidget {
  const ProfilScreen({super.key});

  @override
  State<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends State<ProfilScreen> {
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

  void _showEditProfileBottomSheet(BuildContext context, String currentName, String currentCity, String currentUni, String? currentAvatar) {
    final nameController = TextEditingController(text: currentName == 'İsimsiz Kullanıcı' ? '' : currentName);
    String? selectedCity = currentCity == 'Şehir belirtilmedi' ? null : currentCity;
    String? selectedUniversity = currentUni == 'Üniversite belirtilmedi' ? null : currentUni;
    String? selectedAvatar = currentAvatar;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Profili Güncelle', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    const Text('Avatar Seç', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textMid)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 80,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: AppConstants.avatarSeeds.length,
                        itemBuilder: (context, index) {
                          final seed = AppConstants.avatarSeeds[index];
                          final isSelected = selectedAvatar == seed;
                          final avatarUrl = 'https://api.dicebear.com/7.x/micah/png?seed=$seed&backgroundColor=transparent';
                          
                          return GestureDetector(
                            onTap: () => setModalState(() => selectedAvatar = seed),
                            child: Container(
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? AppColors.teal : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 36,
                                backgroundColor: isSelected ? AppColors.tealLight : Colors.grey.shade100,
                                backgroundImage: NetworkImage(avatarUrl),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'İsim Soyisim',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.person, color: AppColors.teal),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownSearch<String>(
                      items: (filter, loadProps) => _sortedCities,
                      filterFn: _turkishSearchFilter,
                      popupProps: const PopupProps.menu(
                        showSearchBox: true,
                        searchFieldProps: TextFieldProps(
                          decoration: InputDecoration(hintText: "Şehir ara...", prefixIcon: Icon(Icons.search)),
                        ),
                      ),
                      decoratorProps: DropDownDecoratorProps(
                        decoration: InputDecoration(
                          labelText: 'Yaşadığın Şehir',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.location_city, color: AppColors.teal),
                        ),
                      ),
                      onSelected: (value) => setModalState(() => selectedCity = value),
                      selectedItem: selectedCity,
                    ),
                    const SizedBox(height: 16),
                    DropdownSearch<String>(
                      items: (filter, loadProps) => _sortedUniversities,
                      filterFn: _turkishSearchFilter,
                      popupProps: const PopupProps.menu(
                        showSearchBox: true,
                        searchFieldProps: TextFieldProps(
                          decoration: InputDecoration(hintText: "Üniversite ara...", prefixIcon: Icon(Icons.search)),
                        ),
                      ),
                      decoratorProps: DropDownDecoratorProps(
                        decoration: InputDecoration(
                          labelText: 'Üniversite',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.school, color: AppColors.teal),
                        ),
                      ),
                      onSelected: (value) => setModalState(() => selectedUniversity = value),
                      selectedItem: selectedUniversity,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              final newName = nameController.text.trim();
                              if (newName.isEmpty) return; // İsim boş bırakılamaz

                              setModalState(() => isSaving = true);
                              final user = FirebaseAuth.instance.currentUser;
                              if (user != null) {
                                await user.updateDisplayName(newName);
                                await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
                                  'city': selectedCity ?? 'Şehir belirtilmedi',
                                  'university': selectedUniversity ?? 'Üniversite belirtilmedi',
                                  'name': newName,
                                  'avatarSeed': selectedAvatar,
                                  'email': user.email,
                                }, SetOptions(merge: true));
                              }
                              if (context.mounted) Navigator.pop(context);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.teal,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: isSaving
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white))
                          : const Text('Kaydet', style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text('Kullanıcı bulunamadı'));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Profil',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 24),
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                Map<String, dynamic>? data;
                if (snapshot.hasData && snapshot.data!.exists) {
                  data = snapshot.data!.data() as Map<String, dynamic>;
                }

                final name = data?['name'] ?? user.displayName ?? 'İsimsiz Kullanıcı';
                final city = data?['city'] ?? 'Şehir belirtilmedi';
                final university = data?['university'] ?? 'Üniversite belirtilmedi';
                final avatarSeed = data?['avatarSeed'] as String?;

                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: AppColors.tealLight,
                          backgroundImage: avatarSeed != null 
                              ? NetworkImage('https://api.dicebear.com/7.x/micah/png?seed=$avatarSeed&backgroundColor=transparent') 
                              : null,
                          child: avatarSeed == null 
                              ? const Icon(Icons.person, size: 40, color: AppColors.teal)
                              : null,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          name,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textDark),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.location_city, size: 16, color: AppColors.textMid),
                            const SizedBox(width: 4),
                            Text(city, style: const TextStyle(color: AppColors.textMid)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.school, size: 16, color: AppColors.textMid),
                            const SizedBox(width: 4),
                            Flexible(child: Text(university, style: const TextStyle(color: AppColors.textMid), overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () => _showEditProfileBottomSheet(context, name, city, university, avatarSeed),
                          icon: const Icon(Icons.edit, size: 18, color: AppColors.teal),
                          label: const Text('Profili Güncelle', style: TextStyle(color: AppColors.teal)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.teal),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () {
                context.read<AuthProvider>().signOut();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.errorRed,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Çıkış Yap', style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

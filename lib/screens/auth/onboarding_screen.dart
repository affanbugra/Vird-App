import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../app_colors.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onCompleted;
  const OnboardingScreen({super.key, required this.onCompleted});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _onboardingData = [
    {
      "title": "İbadetlerini Takip Et",
      "text": "Günlük okumalarını, hatimlerini ve namazlarını kolayca takip et.",
      "icon": "menu_book"
    },
    {
      "title": "Kuran Haritanı Oluştur",
      "text": "Okuduğun sayfalarla kendi ısı haritanı oluştur ve ilerlemeni gör.",
      "icon": "map"
    },
    {
      "title": "Arkadaşlarınla Yarış",
      "text": "Ekiplere katıl, hasanat puanları topla ve liderlik tablosuna gir.",
      "icon": "group"
    },
  ];

  IconData _getIconData(String name) {
    switch (name) {
      case "menu_book":
        return Icons.menu_book;
      case "map":
        return Icons.map;
      case "group":
        return Icons.group;
      default:
        return Icons.star;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              flex: 3,
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (value) => setState(() => _currentPage = value),
                itemCount: _onboardingData.length,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _getIconData(_onboardingData[index]["icon"]!),
                        size: 100,
                        color: AppColors.teal,
                      ),
                      const SizedBox(height: 40),
                      Text(
                        _onboardingData[index]["title"]!,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _onboardingData[index]["text"]!,
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.textMid,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _onboardingData.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 5),
                        height: 8,
                        width: _currentPage == index ? 24 : 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index ? AppColors.teal : AppColors.borderGrey,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (_currentPage == _onboardingData.length - 1) {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('showHome', true);
                            widget.onCompleted();
                          } else {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeIn,
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.teal,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          _currentPage == _onboardingData.length - 1 ? "Başla" : "İleri",
                          style: const TextStyle(fontSize: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

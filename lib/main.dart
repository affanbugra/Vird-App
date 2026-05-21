import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'app_colors.dart';
import 'app_assets.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'services/notification_service.dart';
import 'services/home_widget_service.dart';
import 'utils/app_theme.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/auth/onboarding_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/hatimlerim_screen.dart';
import 'screens/ekipler_screen.dart';
import 'screens/profil_screen.dart';
import 'screens/vird_screen.dart';
import 'widgets/log_entry_bottom_sheet.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  await NotificationService.init();
  await HomeWidgetService.init();

  final prefs = await SharedPreferences.getInstance();
  final showHome = prefs.getBool('showHome') ?? false;

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ],
        child: VirdApp(showHome: showHome),
      ),
    );
}

class VirdApp extends StatelessWidget {
  final bool showHome;
  const VirdApp({super.key, required this.showHome});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Vird',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.getTheme(themeProvider.themeType),
          home: AuthWrapper(initialShowHome: showHome),
        );
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  final bool initialShowHome;
  const AuthWrapper({super.key, required this.initialShowHome});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  late bool _showHome;

  @override
  void initState() {
    super.initState();
    _showHome = widget.initialShowHome;
  }

  void _completeOnboarding() => setState(() => _showHome = true);

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        if (auth.isLoading) return const SplashScreen();
        if (auth.isAuthenticated) {
          // Widget verilerini güncelle (uygulama her açılışında)
          HomeWidgetService.updateWidgetData();
          return const MainScreen();
        }
        return _showHome
            ? const LoginScreen()
            : OnboardingScreen(onCompleted: _completeOnboarding);
      },
    );
  }
}

// ─── Ana ekran ─────────────────────────────────────────────────────────────
// Sekme sırası: Hatimlerim · Ekipler · [+ LOG FAB] · VİRD · Profil

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HatimlerimScreen(),
    EkiplerScreen(),
    VirdScreen(),
    ProfilScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.95, end: 1.0).animate(animation),
              child: child,
            ),
          );
        },
        child: KeyedSubtree(
          key: ValueKey(_currentIndex),
          child: _screens[_currentIndex],
        ),
      ),
      floatingActionButton: _LogFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _MainBottomNav(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

// ─── Log girişi FAB ────────────────────────────────────────────────────────
class _LogFAB extends StatefulWidget {
  @override
  State<_LogFAB> createState() => _LogFABState();
}

class _LogFABState extends State<_LogFAB> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        LogEntryBottomSheet.show(context);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        transform: Matrix4.translationValues(0, _pressed ? 3 : 0, 0),
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          color: AppColors.teal,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.tealDark,
              offset: Offset(0, _pressed ? 2 : 5),
              blurRadius: 0,
            ),
            BoxShadow(
              color: AppColors.tealDark.withValues(alpha: 0.35),
              offset: const Offset(0, 8),
              blurRadius: 14,
            ),
          ],
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),
    );
  }
}

// ─── Alt navigasyon ────────────────────────────────────────────────────────
class _MainBottomNav extends StatelessWidget {
  final int currentIndex;
  final void Function(int) onTap;

  const _MainBottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      notchMargin: 8,
      shape: const CircularNotchedRectangle(),
      color: Theme.of(context).bottomAppBarTheme.color ?? context.scaffoldBg,
      elevation: 8,
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          _NavItem(
            icon: Icons.menu_book_outlined,
            activeIcon: Icons.menu_book,
            label: 'Hatimlerim',
            active: currentIndex == 0,
            onTap: () => onTap(0),
          ),
          _NavItem(
            icon: Icons.group_outlined,
            activeIcon: Icons.group,
            label: 'Ekipler',
            active: currentIndex == 1,
            onTap: () => onTap(1),
          ),
          // FAB için boşluk + اِقْرَأْ etiketi (diğer sekmelerle aynı hizada)
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 36), // indicator(9) + icon(24) + gap(3)
                Text(
                  'اِقْرَأْ',
                  style: GoogleFonts.amiri(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.teal,
                  ),
                ),
              ],
            ),
          ),
          _NavItem(
            isVird: true,
            label: 'VİRD',
            active: currentIndex == 2,
            onTap: () => onTap(2),
          ),
          _NavItem(
            icon: Icons.person_outline,
            activeIcon: Icons.person,
            label: 'Profil',
            active: currentIndex == 3,
            onTap: () => onTap(3),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData? icon;
  final IconData? activeIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final bool isVird;

  const _NavItem({
    this.icon,
    this.activeIcon,
    required this.label,
    required this.active,
    required this.onTap,
    this.isVird = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.teal : AppColors.textLight;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Aktif göstergesi — animasyonlu üst çizgi
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              height: 3,
              width: active ? 24 : 0,
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: AppColors.teal,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            // İkon — animasyonlu geçiş
            if (isVird)
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: active ? 1.0 : 0.4,
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 200),
                  scale: active ? 1.1 : 1.0,
                  child: Image.asset(AppAssets.logo, height: 38),
                ),
              )
            else ...[
              AnimatedScale(
                duration: const Duration(milliseconds: 200),
                scale: active ? 1.15 : 1.0,
                child: Icon(
                  active ? (activeIcon ?? icon) : icon,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  color: color,
                ),
                child: Text(label),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

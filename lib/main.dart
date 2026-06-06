import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'app_colors.dart';
import 'app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/user_provider.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/auth/onboarding_screen.dart';
import 'screens/auth/login_screen.dart';
import 'widgets/mandatory_setup_sheet.dart';
import 'screens/auth/magic_link_confirm_screen.dart';
import 'screens/auth/profile_setup_screen.dart';
import 'screens/hatimlerim_screen.dart';
import 'screens/ekipler_screen.dart';
import 'screens/profil_screen.dart';
import 'screens/gunluk_takipler_screen.dart';
import 'widgets/log_entry_bottom_sheet.dart';
import 'services/streak_freeze_service.dart';

Future<void> _logErrorToFirestore(FlutterErrorDetails details) async {
  try {
    final stack = details.stack?.toString() ?? '';
    await FirebaseFirestore.instance.collection('app_errors').add({
      'error': details.exceptionAsString(),
      'stack': stack.length > 2000 ? stack.substring(0, 2000) : stack,
      'library': details.library ?? '',
      'createdAt': FieldValue.serverTimestamp(),
      'platform': kIsWeb ? 'web' : 'mobile',
    });
  } catch (_) {}
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Kırmızı hata ekranını kullanıcı dostu widget ile değiştir
  ErrorWidget.builder = (FlutterErrorDetails details) =>
      _AppErrorWidget(details: details);

  // Widget render hatalarını yakala
  FlutterError.onError = (FlutterErrorDetails details) {
    if (kDebugMode) FlutterError.presentError(details);
    _logErrorToFirestore(details);
  };

  // Async/Future/microtask hatalarını yakala (Promise rejection dahil)
  // Bu olmadan Flutter Web'de kırmızı ekran gösterir ve Firestore'a gitmez.
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    _logErrorToFirestore(FlutterErrorDetails(
      exception: error,
      stack: stack,
      library: 'async',
    ));
    return true; // true = hatayı yutar, uygulama çökmez
  };

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  final prefs = await SharedPreferences.getInstance();

  // Web'de magic link ile giriş kontrolü
  String? pendingMagicLink;
  if (kIsWeb) {
    final link = Uri.base.toString();
    if (FirebaseAuth.instance.isSignInWithEmailLink(link)) {
      final email = prefs.getString('emailForSignIn');
      if (email != null) {
        // Aynı cihaz: e-posta localStorage'da mevcut, otomatik giriş
        try {
          await FirebaseAuth.instance.signInWithEmailLink(
            email: email,
            emailLink: link,
          );
        } catch (e) {
          // Otomatik giriş başarısız — kullanıcıya onay ekranı göster
          debugPrint('Magic link otomatik giriş hatası: $e');
          pendingMagicLink = link;
        } finally {
          await prefs.remove('emailForSignIn');
        }
      } else {
        // Farklı cihaz: e-postayı kullanıcıdan iste
        pendingMagicLink = link;
      }
    }
  }

  final showHome = prefs.getBool('showHome') ?? false;

  final themeProvider = ThemeProvider();
  await themeProvider.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, UserProvider>(
          create: (_) => UserProvider(),
          update: (_, auth, user) {
            user!.listenToUser(auth.user?.uid);
            return user;
          },
        ),
      ],
      child: VirdApp(showHome: showHome, pendingMagicLink: pendingMagicLink),
    ),
  );
}

class VirdApp extends StatelessWidget {
  final bool showHome;
  final String? pendingMagicLink;
  const VirdApp({super.key, required this.showHome, this.pendingMagicLink});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return MaterialApp(
      title: 'Vird',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeProvider.themeMode,
      home: AuthWrapper(initialShowHome: showHome, pendingMagicLink: pendingMagicLink),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  final bool initialShowHome;
  final String? pendingMagicLink;
  const AuthWrapper({super.key, required this.initialShowHome, this.pendingMagicLink});

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
          if (auth.needsProfileSetup) {
            return ProfileSetupScreen(name: auth.user?.displayName ?? '', requiresCinsiyet: true);
          }
          return const MainScreen();
        }
        // Farklı cihazdan açılan magic link
        if (widget.pendingMagicLink != null) {
          return MagicLinkConfirmScreen(link: widget.pendingMagicLink!);
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

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  bool _mandatorySetupShown = false;

  final List<Widget> _screens = const [
    HatimlerimScreen(),
    EkiplerScreen(),
    GunlukTakiplerScreen(),
    ProfilScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _triggerAutoFreeze();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _triggerAutoFreeze();
    }
  }

  Future<void> _triggerAutoFreeze() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        await StreakFreezeService.autoApplyFreezes(uid);
      } catch (e) {
        debugPrint('Auto-freeze check failed: $e');
      }
    }
  }

  /// UserProvider veri gelince zorunlu kurulum ekranını tetikle
  void _checkMandatorySetup(UserProvider userProvider) {
    if (!userProvider.needsMandatorySetup || _mandatorySetupShown) return;
    _mandatorySetupShown = true;
    // Firestore'dan son veriyi al
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final userData = doc.data() ?? {};
      if (!mounted) return;
      await MandatorySetupSheet.show(context, userData);
      // Sheet kapandıktan sonra flag sıfırla (tekrar açılabilsin gerekirse)
      _mandatorySetupShown = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // UserProvider izle — zorunlu kurulum kontrolü
    final userProvider = context.watch<UserProvider>();
    _checkMandatorySetup(userProvider);

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
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
      color: context.colors.surface,
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
            icon: Icons.water_drop_outlined,
            activeIcon: Icons.water_drop,
            label: 'Alışkanlıklar',
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
  const _NavItem({
    this.icon,
    this.activeIcon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.teal : context.colors.textTertiary;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Aktif göstergesi — üstte ince teal çizgi
            Container(
              height: 3,
              width: 24,
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: active ? AppColors.teal : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Icon(
              active ? (activeIcon ?? icon) : icon,
              color: color,
              size: 24,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 11,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Kullanıcı Dostu Hata Ekranı ──────────────────────────────────────────
class _AppErrorWidget extends StatelessWidget {
  final FlutterErrorDetails details;
  const _AppErrorWidget({required this.details});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.surface,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72, height: 72,
                decoration: const BoxDecoration(
                  color: Color(0xFFFEF2F2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline, size: 36, color: Color(0xFFEF4444)),
              ),
              const SizedBox(height: 20),
              Text(
                'Bir şeyler ters gitti',
                style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800,
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Beklenmedik bir hata oluştu.\nGeliştirici bilgilendirildi.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14, color: context.colors.textSecondary, height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              TextButton(
                onPressed: () {
                  try { Navigator.of(context).pop(); } catch (_) {}
                },
                child: const Text(
                  'Geri Dön',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF00897B),
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

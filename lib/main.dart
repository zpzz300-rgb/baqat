// lib/main.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'providers/app_provider.dart';
import 'services/app_theme.dart';
import 'services/supabase_service.dart';
import 'services/auth_service.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/activation_screen.dart';
import 'services/notification_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'widgets/phone_required_dialog.dart';

/// مفتاح عام للـ ScaffoldMessenger عشان نعرض رسالة (SnackBar) فوق أي شاشة،
/// حتى من داخل الـ Provider اللي مالوش BuildContext.
final GlobalKey<ScaffoldMessengerState> rootMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// رسالة حمرا واضحة: محاولة تعديل وانت من غير نت — التعديل مش هيتحفظ.
void showOfflineWriteBlocked() {
  final m = rootMessengerKey.currentState;
  if (m == null) return;
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    content: Row(children: [
      const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 20),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          '🚫 مفيش إنترنت — التعديل مش هيتحفظ. اتصل بالنت وحاول تاني.',
          style: GoogleFonts.cairo(
              fontWeight: FontWeight.w800, fontSize: 13, color: Colors.white),
        ),
      ),
    ]),
    backgroundColor: const Color(0xFFD32F2F),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    margin: const EdgeInsets.all(16),
    duration: const Duration(seconds: 3),
  ));
}

/// شريط أحمر دائم أعلى الشاشة طول ما مفيش نت — تنبيه وقائي قبل أي تعديل.
class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();
  @override
  Widget build(BuildContext context) {
    final online = context.watch<AppProvider>().isOnline;
    if (online) return const SizedBox.shrink();
    return Material(
      color: const Color(0xFFD32F2F),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'مفيش إنترنت — أي تعديل دلوقتي مش هيتحفظ',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                      color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('⚠️ Failed to load .env file: $e');
  }

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Color(0xFF0d47a1),
    statusBarIconBrightness: Brightness.light,
  ));

  try {
    await SupabaseService.initialize();
    // استرجاع سياق الموظف (لو كان داخل كموظف) قبل تحميل أي بيانات
    await SupabaseService.restoreEmployeeContext();
  } catch (e) {
    debugPrint('❌ Supabase initialization failed: $e');
  }

  await Permission.notification.request();
  await NotificationService.init();
  // Phase 4: طلب إذن exact alarm + إصلاح الـ exception القديم
  await NotificationService.requestPermissions();

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppProvider()..init(),
      child: const TelecomApp(),
    ),
  );
}

class TelecomApp extends StatelessWidget {
  const TelecomApp({super.key});
  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (ctx, prov, _) {
        // ربط الرسالة الحمرا: أي كتابة تتمنع بسبب عدم وجود نت تعرض تنبيه.
        prov.onOfflineWriteBlocked = showOfflineWriteBlocked;
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'باقات الاتصالات',
          scaffoldMessengerKey: rootMessengerKey,
          theme: AppTheme.resolve(prov.themeStyle, prov.fontSize, prov.darkMode),
          locale: const Locale('ar', 'EG'),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('ar', 'EG')],
          // شريط أحمر دائم أعلى كل الشاشات وقت عدم الاتصال.
          builder: (context, child) => Column(
            children: [
              const _OfflineBanner(),
              Expanded(child: child ?? const SizedBox.shrink()),
            ],
          ),
          home: prov.loading ? const _Splash() : const _AuthGate(),
        );
      },
    );
  }
}

// ─── Auth Gate ────────────────────────────────────────────────────
class _AuthGate extends StatefulWidget {
  const _AuthGate();
  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> with WidgetsBindingObserver {
  bool _checkingCloud = false;
  bool _syncing = false; // يمنع تداخل أكتر من مزامنة في نفس الوقت

  late final StreamSubscription<AuthState> _authSubscription;
  RealtimeChannel? _empChannel; // اشتراك حالة الموظف (للطرد الفوري)

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // استمع لتغييرات الـ Auth (login / logout)
    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.signedIn) {
        _onSignedIn();
      } else if (event == AuthChangeEvent.signedOut) {
        if (mounted) {
          context.read<AppProvider>().stopRealtime();
          setState(() {});
        }
      }
    });
    // لو الجلسة موجودة من قبل
    if (SupabaseService.isLoggedIn) _onSignedIn();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription.cancel();
    super.dispose();
  }

  /// عند رجوع التطبيق للواجهة — اسحب أحدث نسخة من السيرفر بصمت.
  /// ده بيقلّل تأخير المزامنة من غير ما تحتاج تقفل وتفتح.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        mounted &&
        SupabaseService.isLoggedIn &&
        !_syncing &&
        !_checkingCloud) {
      _syncing = true;
      context.read<AppProvider>().loadFromCloud().whenComplete(() {
        _syncing = false;
      });
    }
  }

  Future<void> _onSignedIn() async {
    if (!mounted) return;
    setState(() => _checkingCloud = true);

    try {
      // جيب البيانات من السيرفر
      final prov = context.read<AppProvider>();
      await prov.loadFromCloud();

      // مزامنة لحظية بين الأجهزة على نفس البيانات
      prov.startRealtime();

      // سجّل هوية الجهاز بعد الدخول — عشان لوحة الإدارة تعرف مين ده
      // (مالك ولا موظف، وتابع لأنهي محل) بدل ما يفضل «بدون اسم».
      AuthService.reportIdentity();

      if (SupabaseService.isEmployee) {
        // الموظف: حمّل المجموعات الموكلة له (للفلترة والسرية)
        await prov.loadMyAssignments();
        // الموظف: اشترك على حالته — لو المالك فصله/حذفه يتقفل فوراً
        _empChannel ??= SupabaseService.subscribeOwnEmployeeStatus((status) {
          if (status != 'active') _kickEmployee();
        });
      } else {
        // المالك: اتأكد إن عنده ملف وكود محل
        await SupabaseService.ensureOwnerProfile();

        // الرقم مربوط بالحساب — فمبنسألش غير لو الحساب نفسه مالوش رقم خالص
        final hasPhone = await AuthService.accountHasPhone();
        if (!hasPhone && mounted) {
          await showPhoneRequiredDialog(context);
        }
      }
    } catch (e) {
      debugPrint('❌ Failed to load cloud data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ أثناء تحميل البيانات')),
        );
      }
    } finally {
      if (mounted) setState(() => _checkingCloud = false);
    }
  }

  /// طرد الموظف فوراً (المالك أوقفه أو حذفه): يخرج ويمسح أي بيانات محلية.
  Future<void> _kickEmployee() async {
    _empChannel = null;
    final prov = context.read<AppProvider>();
    prov.wipeInMemoryData(); // امسح بيانات المحل من الذاكرة فوراً
    await SupabaseService.signOut();
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Colors.red,
        content: Text('تم إيقاف حسابك من قِبَل المالك',
            textAlign: TextAlign.center),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingCloud) return const _Splash(msg: 'جاري تحميل بياناتك...');

    // مش logged in
    if (!SupabaseService.isLoggedIn) return const LoginScreen();

    // Logged in — check trial/activation
    return _ActivationGate(onSignOut: () async {
      await SupabaseService.signOut();
      if (mounted) setState(() {});
    });
  }
}

// ─── Activation Gate ──────────────────────────────────────────────
class _ActivationGate extends StatefulWidget {
  final VoidCallback onSignOut;
  const _ActivationGate({required this.onSignOut});
  @override
  State<_ActivationGate> createState() => _ActivationGateState();
}

class _ActivationGateState extends State<_ActivationGate> {
  AppStatus _status = AppStatus.loading;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final s = await AuthService.checkStatus();
    if (mounted) setState(() => _status = s);
  }

  @override
  Widget build(BuildContext context) {
    switch (_status) {
      case AppStatus.loading:
        return const _Splash();
      case AppStatus.trial:
        return _TrialBanner(
            onExpired: () => setState(() => _status = AppStatus.expired));
      case AppStatus.activated:
        return const HomeScreen();
      case AppStatus.expired:
        return ActivationScreen(
          isExpired: true,
          onActivated: () => setState(() => _status = AppStatus.activated),
        );
    }
  }
}

// ─── Trial Banner ─────────────────────────────────────────────────
class _TrialBanner extends StatefulWidget {
  final VoidCallback onExpired;
  const _TrialBanner({required this.onExpired});
  @override
  State<_TrialBanner> createState() => _TrialBannerState();
}

class _TrialBannerState extends State<_TrialBanner> {
  int _days = 30;
  bool _show = true;

  @override
  void initState() {
    super.initState();
    AuthService.trialDaysLeft().then((d) {
      if (!mounted) return;
      setState(() => _days = d);
      if (d <= 0) widget.onExpired();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      if (_show)
        Material(
          color: _days <= 7 ? const Color(0xFFb71c1c) : const Color(0xFF1565c0),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(children: [
                Expanded(
                    child: Text(
                  _days <= 3
                      ? '🚨 متبقي $_days أيام فقط! فعّل التطبيق الآن'
                      : _days <= 7
                          ? '⚠️ الفترة التجريبية تنتهي خلال $_days أيام'
                          : '🕒 فترة تجريبية — متبقي $_days يوم',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700),
                )),
                GestureDetector(
                  onTap: () => _showActivation(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('تفعيل',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() => _show = false),
                  child:
                      const Icon(Icons.close, color: Colors.white70, size: 16),
                ),
              ]),
            ),
          ),
        ),
      const Expanded(child: HomeScreen()),
    ]);
  }

  void _showActivation(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActivationScreen(
          isExpired: false,
          onActivated: () {
            Navigator.pop(context);
            widget.onExpired(); // triggers re-check which sets activated
          },
        ),
      ),
    );
  }
}

// ─── Splash ───────────────────────────────────────────────────────
class _Splash extends StatelessWidget {
  final String msg;
  const _Splash({this.msg = ''});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0d47a1),
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('📡', style: TextStyle(fontSize: 60)),
          const SizedBox(height: 16),
          const Text('باقات الاتصالات',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 24),
          const CircularProgressIndicator(color: Colors.white),
          if (msg.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(msg,
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ]),
      ),
    );
  }
}

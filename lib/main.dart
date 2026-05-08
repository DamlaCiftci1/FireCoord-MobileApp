import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'utils/app_theme.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'models/app_models.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const FireCoordApp());
}

class FireCoordApp extends StatelessWidget {
  const FireCoordApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppStateProvider(),
      child: MaterialApp(
        title: 'FireCoord',
        theme: buildAppTheme(),
        debugShowCheckedModeBanner: false,
        home: const SplashScreen(),
      ),
    );
  }
}

// ---- Global State ----

class AppStateProvider extends ChangeNotifier {
  AppUser? currentUser;
  List<Fire> fires = [];
  List<Team> teams = [];
  List<AppNotification> notifications = [];
  int _notifBadge = 0;
  int get notifBadge => _notifBadge;

  void setUser(AppUser? user) {
    currentUser = user;
    notifyListeners();
  }

  void setFires(List<Fire> f) { fires = f; notifyListeners(); }
  void setTeams(List<Team> t) { teams = t; notifyListeners(); }
  void setNotifications(List<AppNotification> n) {
    notifications = n;
    _notifBadge = n.where((x) => !x.read).length;
    notifyListeners();
  }
}

// ---- Splash / Session Restore ----

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await DatabaseService.seedIfEmpty();
    final user = await AuthService.restoreSession();
    if (!mounted) return;
    final provider = context.read<AppStateProvider>();
    if (user != null) {
      provider.setUser(user);
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🔥', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text('FIRECOORD',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 4,
                )),
            const SizedBox(height: 32),
            const SizedBox(
              width: 24, height: 24,
              child: CircularProgressIndicator(
                color: AppColors.primary, strokeWidth: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

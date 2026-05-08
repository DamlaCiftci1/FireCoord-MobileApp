import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';
import '../services/auth_service.dart';
import '../models/app_models.dart';
import '../utils/app_theme.dart';
import 'login_screen.dart';
import 'map_screen.dart';
import 'fires_screen.dart';
import 'teams_screen.dart';
import 'notifications_screen.dart';
import 'management_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  late final List<Widget> _pages;
  late final List<BottomNavigationBarItem> _navItems;

  @override
  void initState() {
    super.initState();
    _startSubscriptions();
    _startLocationIfNeeded();
  }

  void _startSubscriptions() {
    final provider = context.read<AppStateProvider>();

    DatabaseService.firesStream().listen((fires) {
      if (mounted) provider.setFires(fires);
    });
    DatabaseService.teamsStream().listen((teams) {
      if (mounted) provider.setTeams(teams);
    });
    DatabaseService.notificationsStream().listen((notifs) {
      if (mounted) provider.setNotifications(notifs);
    });
  }

  void _startLocationIfNeeded() {
    final user = AuthService.currentUser;
    if (user != null && (user.isSef || user.isEkip) && user.teamId.isNotEmpty) {
      LocationService.startTracking(user.teamId);
    }
  }

  @override
  void dispose() {
    LocationService.stopTracking();
    super.dispose();
  }

  List<BottomNavigationBarItem> _buildNavItems(AppUser? user) {
    final items = [
      const BottomNavigationBarItem(icon: Icon(Icons.map_outlined), activeIcon: Icon(Icons.map), label: 'Harita'),
      const BottomNavigationBarItem(icon: Icon(Icons.local_fire_department_outlined), activeIcon: Icon(Icons.local_fire_department), label: 'Yangınlar'),
      const BottomNavigationBarItem(icon: Icon(Icons.groups_outlined), activeIcon: Icon(Icons.groups), label: 'Ekipler'),
    ];
    // Notifications always visible
    items.add(const BottomNavigationBarItem(
      icon: Icon(Icons.notifications_outlined),
      activeIcon: Icon(Icons.notifications),
      label: 'Bildirimler',
    ));
    // Management only for merkez/sef
    if (user != null && (user.isMerkez || user.isSef)) {
      items.add(const BottomNavigationBarItem(
        icon: Icon(Icons.admin_panel_settings_outlined),
        activeIcon: Icon(Icons.admin_panel_settings),
        label: 'Yönetim',
      ));
    }
    return items;
  }

  List<Widget> _buildPages(AppUser? user) {
    final pages = [
      const MapScreen(),
      const FiresScreen(),
      const TeamsScreen(),
      const NotificationsScreen(),
    ];
    if (user != null && (user.isMerkez || user.isSef)) {
      pages.add(const ManagementScreen());
    }
    return pages;
  }

  Future<void> _logout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppStateProvider>();
    final user = provider.currentUser;
    final navItems = _buildNavItems(user);
    final pages = _buildPages(user);

    // Clamp index in case pages shrink
    final safeIndex = _currentIndex.clamp(0, pages.length - 1);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(children: [
          const Text('🔥 ', style: TextStyle(fontSize: 18)),
          const Text('FIRECOORD', style: TextStyle(color: AppColors.primary, letterSpacing: 2)),
        ]),
        actions: [
          // Active fires badge
          if (provider.fires.isNotEmpty)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.4)),
                ),
                child: Text(
                  '${provider.fires.length} Yangın',
                  style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          // User info
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Center(
              child: Text(
                user?.name.split(' ').first ?? '',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
            color: AppColors.surface,
            onSelected: (v) { if (v == 'logout') _logout(); },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'logout',
                child: Row(children: [
                  const Icon(Icons.logout, color: AppColors.danger, size: 18),
                  const SizedBox(width: 8),
                  Text('Çıkış Yap', style: TextStyle(color: AppColors.danger)),
                ]),
              ),
            ],
          ),
        ],
      ),
      body: pages[safeIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Consumer<AppStateProvider>(
          builder: (_, prov, __) {
            final items = _buildNavItems(prov.currentUser);
            return BottomNavigationBar(
              currentIndex: safeIndex,
              items: items.map((item) {
                // Add badge on notifications tab
                if (item.label == 'Bildirimler' && prov.notifBadge > 0) {
                  return BottomNavigationBarItem(
                    icon: Badge(
                      label: Text('${prov.notifBadge}'),
                      child: item.icon,
                    ),
                    activeIcon: Badge(
                      label: Text('${prov.notifBadge}'),
                      child: item.activeIcon ?? item.icon,
                    ),
                    label: item.label,
                  );
                }
                return item;
              }).toList(),
              onTap: (i) => setState(() => _currentIndex = i),
            );
          },
        ),
      ),
    );
  }
}

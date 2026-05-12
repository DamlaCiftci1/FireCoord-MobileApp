import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';
import '../services/auth_service.dart';
import '../models/app_models.dart';
import '../utils/app_theme.dart';
import '../utils/role_permissions.dart';
import 'login_screen.dart';
import 'map_screen.dart';
import 'fires_screen.dart';
import 'teams_screen.dart';
import 'notifications_screen.dart';
import 'my_task_screen.dart';
import 'route_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _startSubscriptions();
    _startLocationIfNeeded();
  }

  void _startSubscriptions() {
    final provider = context.read<AppStateProvider>();
    DatabaseService.firesStream().listen((f) { if (mounted) provider.setFires(f); });
    DatabaseService.extinguishedFiresStream().listen((f) { if (mounted) provider.setExtinguishedFires(f); });
    DatabaseService.teamsStream().listen((t) { if (mounted) provider.setTeams(t); });
    DatabaseService.notificationsStream().listen((n) { if (mounted) provider.setNotifications(n); });
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

  List<_TabDef> _buildTabDefs(AppUser? user) {
    final tabs = RoleBasedController.getTabs(user);
    return tabs.map((t) => _tabDefFor(t, user)).toList();
  }

  _TabDef _tabDefFor(AppTab tab, AppUser? user) {
    switch (tab) {
      case AppTab.myTask:
        return _TabDef(
          page: const MyTaskScreen(),
          item: const BottomNavigationBarItem(
            icon: Icon(Icons.assignment_outlined),
            activeIcon: Icon(Icons.assignment),
            label: 'Görevim',
          ),
        );
      case AppTab.map:
        return _TabDef(
          page: const MapScreen(),
          item: const BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map),
            label: 'Harita',
          ),
        );
      case AppTab.fires:
        return _TabDef(
          page: const FiresScreen(),
          item: const BottomNavigationBarItem(
            icon: Icon(Icons.local_fire_department_outlined),
            activeIcon: Icon(Icons.local_fire_department),
            label: 'Yangınlar',
          ),
        );
      case AppTab.teams:
        return _TabDef(
          page: const TeamsScreen(),
          item: BottomNavigationBarItem(
            icon: const Icon(Icons.groups_outlined),
            activeIcon: const Icon(Icons.groups),
            label: user?.isSef == true ? 'Ekibim' : 'Ekipler',
          ),
        );
      case AppTab.route:
        return _TabDef(
          page: const RouteScreen(),
          item: const BottomNavigationBarItem(
            icon: Icon(Icons.directions_outlined),
            activeIcon: Icon(Icons.directions),
            label: 'Rota',
          ),
        );
      case AppTab.notifications:
        return _TabDef(
          page: const NotificationsScreen(),
          item: const BottomNavigationBarItem(
            icon: Icon(Icons.notifications_outlined),
            activeIcon: Icon(Icons.notifications),
            label: 'Bildirimler',
          ),
        );
    }
  }

  Future<void> _logout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppStateProvider>();
    final user = provider.currentUser;
    final tabDefs = _buildTabDefs(user);
    if (tabDefs.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await AuthService.logout();
        if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      });
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    final safeIndex = _currentIndex.clamp(0, tabDefs.length - 1);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Row(children: [
          Text('🔥 ', style: TextStyle(fontSize: 18)),
          Text('FIRECOORD',
              style: TextStyle(color: AppColors.primary, letterSpacing: 2)),
        ]),
        actions: [
          if (provider.fires.isNotEmpty)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '${provider.fires.length} Yangın',
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
          if (user != null)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _roleColor(user.role).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${RoleBasedController.roleIcon(user.role)} ${user.name.split(' ').first}',
                  style: TextStyle(
                      color: _roleColor(user.role),
                      fontSize: 11,
                      fontWeight: FontWeight.w500),
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
                  Icon(Icons.logout, color: AppColors.danger, size: 18),
                  const SizedBox(width: 8),
                  Text('Çıkış Yap', style: TextStyle(color: AppColors.danger)),
                ]),
              ),
            ],
          ),
        ],
      ),
      body: tabDefs[safeIndex].page,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Consumer<AppStateProvider>(
          builder: (_, prov, __) {
            final defs = _buildTabDefs(prov.currentUser);
            return BottomNavigationBar(
              currentIndex: safeIndex,
              items: defs.map((def) {
                if (def.item.label == 'Bildirimler' && prov.notifBadge > 0) {
                  return BottomNavigationBarItem(
                    icon: Badge(
                      label: Text('${prov.notifBadge}'),
                      child: def.item.icon,
                    ),
                    activeIcon: Badge(
                      label: Text('${prov.notifBadge}'),
                      child: def.item.activeIcon,
                    ),
                    label: def.item.label,
                  );
                }
                return def.item;
              }).toList(),
              onTap: (i) => setState(() => _currentIndex = i),
            );
          },
        ),
      ),
    );
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'sef':    return AppColors.warning;
      default:       return AppColors.info;
    }
  }
}

class _TabDef {
  final Widget page;
  final BottomNavigationBarItem item;
  const _TabDef({required this.page, required this.item});
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models/app_models.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';

class ManagementScreen extends StatefulWidget {
  const ManagementScreen({super.key});

  @override
  State<ManagementScreen> createState() => _ManagementScreenState();
}

class _ManagementScreenState extends State<ManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: AppColors.surface,
          child: TabBar(
            controller: _tabs,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textMuted,
            indicatorColor: AppColors.primary,
            tabs: const [Tab(text: 'Kullanıcılar'), Tab(text: 'Ekipler')],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _UsersTab(),
              _TeamsManagementTab(),
            ],
          ),
        ),
      ],
    );
  }
}

// ---- Users Tab ----

class _UsersTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppUser>>(
      stream: DatabaseService.usersStream(),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }
        final users = snap.data!;
        final currentUser = AuthService.currentUser;

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: users.length,
          itemBuilder: (_, i) {
            final u = users[i];
            final isMe = currentUser?.id == u.id;
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _roleColor(u.role).withOpacity(0.15),
                  child: Text(_roleIcon(u.role), style: const TextStyle(fontSize: 18)),
                ),
                title: Row(children: [
                  Text(u.name,
                      style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
                  if (isMe) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.info.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('Sen', style: TextStyle(color: AppColors.info, fontSize: 9)),
                    ),
                  ],
                ]),
                subtitle: Text(
                  '${u.username}  •  ${u.roleLabel}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _roleColor(u.role).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(u.roleLabel,
                      style: TextStyle(
                          color: _roleColor(u.role), fontSize: 10, fontWeight: FontWeight.w600)),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'merkez': return AppColors.primary;
      case 'sef': return AppColors.warning;
      default: return AppColors.info;
    }
  }

  String _roleIcon(String role) {
    switch (role) {
      case 'merkez': return '🏢';
      case 'sef': return '👨‍🚒';
      default: return '🧑‍🤝‍🧑';
    }
  }
}

// ---- Teams Management Tab ----

class _TeamsManagementTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (_, provider, __) {
        final teams = provider.teams;
        final fires = provider.fires;

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: teams.length,
          itemBuilder: (_, i) {
            final team = teams[i];
            final sColor = statusColor(team.status);
            final assignedFire = team.assignedFire != null
                ? fires.firstWhere((f) => f.id == team.assignedFire, orElse: () => fires.isEmpty ? _dummyFire(team.assignedFire!) : fires.first)
                : null;

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Text('🚒 ', style: TextStyle(fontSize: 18)),
                      Expanded(
                        child: Text(team.name,
                            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                      ),
                      _statusChip(team.statusLabel, sColor),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      _stat('🆔', team.vehicleId),
                      _stat('👤', team.chief),
                      _stat('👥', '${team.personnel} kişi'),
                    ]),
                    const SizedBox(height: 6),
                    Row(children: [
                      _stat('💧', '${team.water}%'),
                      _stat('🎯', team.assignedFire ?? 'Görev yok'),
                      const Spacer(),
                    ]),
                    const SizedBox(height: 10),
                    // Status change buttons (merkez only)
                    if (AuthService.currentUser?.isMerkez == true)
                      Wrap(
                        spacing: 6,
                        children: ['available', 'on_duty', 'maintenance'].map((s) {
                          final isActive = team.status == s;
                          final label = {'available': 'Uygun', 'on_duty': 'Görevde', 'maintenance': 'Bakım'}[s]!;
                          return GestureDetector(
                            onTap: isActive ? null : () async {
                              await DatabaseService.updateTeamStatus(team.id, s);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: isActive ? statusColor(s).withOpacity(0.2) : AppColors.border.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isActive ? statusColor(s) : AppColors.border,
                                ),
                              ),
                              child: Text(label,
                                  style: TextStyle(
                                    color: isActive ? statusColor(s) : AppColors.textMuted,
                                    fontSize: 11, fontWeight: FontWeight.w500,
                                  )),
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Fire _dummyFire(String id) => Fire(id: id, lat: 0, lng: 0, startTime: DateTime.now());

  Widget _stat(String icon, String value) {
    return Expanded(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$icon ', style: const TextStyle(fontSize: 12)),
          Flexible(
            child: Text(value,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
      );
}

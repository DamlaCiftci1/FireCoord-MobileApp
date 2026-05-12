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
  late bool _isSef;

  @override
  void initState() {
    super.initState();
    final user = AuthService.currentUser;
    _isSef = user?.isSef == true;
    // Şef için: Ekipler + Durum Raporu (2 sekme)
    // Merkez için: Kullanıcılar + Ekipler (2 sekme)
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabs      = _isSef
        ? const [Tab(text: 'Ekipler'), Tab(text: 'Durum Raporu')]
        : const [Tab(text: 'Kullanıcılar'), Tab(text: 'Ekipler')];
    final tabViews  = _isSef
        ? [_TeamsManagementTab(), _StatusReportTab()]
        : [_UsersTab(), _TeamsManagementTab()];

    return Column(
      children: [
        Container(
          color: AppColors.surface,
          child: TabBar(
            controller: _tabs,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textMuted,
            indicatorColor: AppColors.primary,
            tabs: tabs,
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: tabViews,
          ),
        ),
      ],
    );
  }
}

// ---- Users Tab ----

class _UsersTab extends StatefulWidget {
  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  void _showAddUserDialog() {
    final nameCtrl = TextEditingController();
    final usernameCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final teamCtrl = TextEditingController();
    String role = 'ekip';

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Yeni Kullanıcı',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(nameCtrl, 'Ad Soyad'),
                const SizedBox(height: 10),
                _field(usernameCtrl, 'Kullanıcı Adı'),
                const SizedBox(height: 10),
                _field(passwordCtrl, 'Şifre', obscure: true),
                const SizedBox(height: 10),
                _field(emailCtrl, 'E-posta'),
                const SizedBox(height: 10),
                _field(teamCtrl, 'Ekip ID (opsiyonel, örn: T001)'),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: role,
                  dropdownColor: AppColors.surface,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(labelText: 'Rol'),
                  items: const [
                    DropdownMenuItem(value: 'ekip', child: Text('Ekip Üyesi')),
                    DropdownMenuItem(value: 'sef', child: Text('İtfaiye Şefi')),
                    DropdownMenuItem(value: 'merkez', child: Text('Merkez Op.')),
                  ],
                  onChanged: (v) => setDialogState(() => role = v ?? 'ekip'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal', style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty || usernameCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                await DatabaseService.addUser(
                  name: nameCtrl.text.trim(),
                  username: usernameCtrl.text.trim(),
                  password: passwordCtrl.text.trim().isEmpty ? '1234' : passwordCtrl.text.trim(),
                  role: role,
                  email: emailCtrl.text.trim(),
                  teamId: teamCtrl.text.trim(),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Ekle'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, {bool obscure = false}) =>
      TextField(
        controller: ctrl,
        obscureText: obscure,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        decoration: InputDecoration(labelText: label),
      );

  @override
  Widget build(BuildContext context) {
    final isMerkez = AuthService.currentUser?.isMerkez == true;
    return StreamBuilder<List<AppUser>>(
      stream: DatabaseService.usersStream(),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }
        final users = snap.data!;
        final currentUser = AuthService.currentUser;

        return Stack(
          children: [
            ListView.builder(
              padding: EdgeInsets.fromLTRB(8, 8, 8, isMerkez ? 80 : 16),
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
                          style: const TextStyle(
                              color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
                      if (isMe) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.info.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('Sen',
                              style: TextStyle(color: AppColors.info, fontSize: 9)),
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
                              color: _roleColor(u.role),
                              fontSize: 10,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                );
              },
            ),
            if (isMerkez)
              Positioned(
                bottom: 16,
                right: 16,
                child: FloatingActionButton.extended(
                  heroTag: 'add_user',
                  onPressed: _showAddUserDialog,
                  backgroundColor: AppColors.primary,
                  icon: const Icon(Icons.person_add),
                  label: const Text('Kullanıcı Ekle'),
                ),
              ),
          ],
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

class _TeamsManagementTab extends StatefulWidget {
  @override
  State<_TeamsManagementTab> createState() => _TeamsManagementTabState();
}

class _TeamsManagementTabState extends State<_TeamsManagementTab> {
  void _showTeamSheet({Team? existing}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (_) => _TeamEditSheet(existing: existing),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (_, provider, __) {
        final teams = provider.teams;
        final isMerkez = AuthService.currentUser?.isMerkez == true;

        return Stack(
          children: [
            ListView.builder(
              padding: EdgeInsets.fromLTRB(8, 8, 8, isMerkez ? 80 : 16),
              itemCount: teams.length,
              itemBuilder: (_, i) {
                final team = teams[i];
                final sColor = statusColor(team.status);

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
                                style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14)),
                          ),
                          _statusChip(team.statusLabel, sColor),
                          if (isMerkez) ...[
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _showTeamSheet(existing: team),
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: AppColors.info.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: AppColors.info.withOpacity(0.3)),
                                ),
                                child: const Icon(Icons.edit,
                                    size: 15, color: AppColors.info),
                              ),
                            ),
                          ],
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
                        if (isMerkez)
                          Wrap(
                            spacing: 6,
                            children: ['available', 'on_duty', 'maintenance'].map((s) {
                              final isActive = team.status == s;
                              final label = {
                                'available': 'Uygun',
                                'on_duty': 'Görevde',
                                'maintenance': 'Bakım'
                              }[s]!;
                              return GestureDetector(
                                onTap: isActive
                                    ? null
                                    : () async {
                                        await DatabaseService.updateTeamStatus(team.id, s);
                                      },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? statusColor(s).withOpacity(0.2)
                                        : AppColors.border.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isActive
                                          ? statusColor(s)
                                          : AppColors.border,
                                    ),
                                  ),
                                  child: Text(label,
                                      style: TextStyle(
                                        color: isActive
                                            ? statusColor(s)
                                            : AppColors.textMuted,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
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
            ),
            if (isMerkez)
              Positioned(
                bottom: 16,
                right: 16,
                child: FloatingActionButton.extended(
                  heroTag: 'add_team',
                  onPressed: () => _showTeamSheet(),
                  backgroundColor: AppColors.success,
                  icon: const Icon(Icons.group_add),
                  label: const Text('Ekip Ekle'),
                ),
              ),
          ],
        );
      },
    );
  }

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
        child: Text(label,
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
      );
}

// ---- Team Edit / Add Sheet ----

class _TeamEditSheet extends StatefulWidget {
  final Team? existing;
  const _TeamEditSheet({this.existing});

  @override
  State<_TeamEditSheet> createState() => _TeamEditSheetState();
}

class _TeamEditSheetState extends State<_TeamEditSheet> {
  late TextEditingController _nameCtrl;
  late TextEditingController _vehicleCtrl;
  late TextEditingController _chiefCtrl;
  late int _water;
  late int _personnel;
  late List<String> _equipment;
  bool _saving = false;

  final _allEquipment = ['maske', 'hortum', 'söndürücü', 'ilkyardım', 'kıskaç'];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _vehicleCtrl = TextEditingController(text: widget.existing?.vehicleId ?? '');
    _chiefCtrl = TextEditingController(text: widget.existing?.chief ?? '');
    _water = widget.existing?.water ?? 100;
    _personnel = widget.existing?.personnel ?? 4;
    _equipment = List.from(widget.existing?.equipment ?? ['maske', 'hortum', 'söndürücü']);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _vehicleCtrl.dispose();
    _chiefCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    if (widget.existing != null) {
      await DatabaseService.updateTeam(
        widget.existing!.id,
        name: _nameCtrl.text.trim(),
        vehicleId: _vehicleCtrl.text.trim(),
        chief: _chiefCtrl.text.trim(),
        water: _water,
        personnel: _personnel,
        equipment: _equipment,
      );
    } else {
      await DatabaseService.addTeam(
        name: _nameCtrl.text.trim(),
        vehicleId: _vehicleCtrl.text.trim(),
        chief: _chiefCtrl.text.trim(),
        water: _water,
        personnel: _personnel,
        equipment: _equipment,
      );
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(
                isEdit ? 'Ekip Düzenle' : 'Yeni Ekip',
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.textMuted),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: _nameCtrl,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(labelText: 'Ekip Adı'),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _vehicleCtrl,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(labelText: 'Araç ID'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _chiefCtrl,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(labelText: 'Şef Adı'),
                ),
              ),
            ]),
            const SizedBox(height: 14),
            Text('Su Seviyesi: $_water%',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            Slider(
              value: _water.toDouble(),
              min: 0, max: 100, divisions: 20,
              activeColor: AppColors.info,
              label: '$_water%',
              onChanged: (v) => setState(() => _water = v.round()),
            ),
            Text('Personel: $_personnel kişi',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            Slider(
              value: _personnel.toDouble(),
              min: 1, max: 10, divisions: 9,
              activeColor: AppColors.info,
              label: '$_personnel',
              onChanged: (v) => setState(() => _personnel = v.round()),
            ),
            const SizedBox(height: 4),
            const Text('Ekipman:',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _allEquipment.map((e) {
                final has = _equipment.contains(e);
                return GestureDetector(
                  onTap: () =>
                      setState(() => has ? _equipment.remove(e) : _equipment.add(e)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: has
                          ? AppColors.success.withOpacity(0.15)
                          : AppColors.border.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: has
                              ? AppColors.success.withOpacity(0.5)
                              : AppColors.border),
                    ),
                    child: Text(e,
                        style: TextStyle(
                          color: has ? AppColors.success : AppColors.textMuted,
                          fontSize: 13,
                        )),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isEdit ? AppColors.info : AppColors.success,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text(isEdit ? 'Güncelle' : 'Ekip Oluştur'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---- Şef: Durum Raporu Sekmesi ----

class _StatusReportTab extends StatefulWidget {
  @override
  State<_StatusReportTab> createState() => _StatusReportTabState();
}

class _StatusReportTabState extends State<_StatusReportTab> {
  final _noteCtrl = TextEditingController();
  String _selectedStatus = 'normal';
  bool _sending = false;

  static const _statuses = {
    'normal':    ('✅', 'Normal', AppColors.success),
    'warning':   ('⚠️', 'Dikkat Gerekli', AppColors.warning),
    'critical':  ('🚨', 'Kritik Durum', AppColors.danger),
    'support':   ('🆘', 'Destek Talep', AppColors.info),
  };

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final user = AuthService.currentUser;
    if (user == null) return;
    setState(() => _sending = true);

    final status = _statuses[_selectedStatus]!;
    final note   = _noteCtrl.text.trim();
    final msg    = note.isEmpty
        ? '${status.$1} [${user.name}] Saha durumu: ${status.$2}'
        : '${status.$1} [${user.name}] Saha durumu: ${status.$2} — $note';

    final notifType = switch (_selectedStatus) {
      'critical' => 'danger',
      'warning'  => 'warning',
      'support'  => 'danger',
      _          => 'success',
    };
    await DatabaseService.addNotification(msg, notifType);
    _noteCtrl.clear();
    setState(() => _sending = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Durum raporu merkeze iletildi'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Başlık
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(children: [
            const Text('👨‍🚒', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user?.name ?? '',
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                  const Text('İtfaiye Şefi — Merkeze Durum Raporu',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),

        // Durum seçimi
        const Text('Saha Durumu',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13)),
        const SizedBox(height: 10),
        ..._statuses.entries.map((e) {
          final selected = _selectedStatus == e.key;
          final (icon, label, color) = e.value;
          return GestureDetector(
            onTap: () => setState(() => _selectedStatus = e.key),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: selected ? color.withOpacity(0.12) : AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected ? color : AppColors.border,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Row(children: [
                Text(icon, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(label,
                      style: TextStyle(
                          color: selected ? color : AppColors.textSecondary,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                          fontSize: 13)),
                ),
                if (selected)
                  Icon(Icons.check_circle, color: color, size: 18),
              ]),
            ),
          );
        }),

        const SizedBox(height: 14),
        const Text('Ek Not (opsiyonel)',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13)),
        const SizedBox(height: 8),
        TextField(
          controller: _noteCtrl,
          maxLines: 3,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Saha notu, konum veya ek bilgi girin...',
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _sending ? null : _send,
            icon: _sending
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.send, size: 18),
            label: const Text('Merkeze Gönder'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}

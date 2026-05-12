import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models/app_models.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';

/// Şef için: yalnızca kendi ekibi gösterilir (web ile aynı davranış)
class TeamsScreen extends StatelessWidget {
  const TeamsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (_, provider, __) {
        final user = AuthService.currentUser;
        final allTeams = provider.teams;

        // Web: getMyTeams() = teams.filter(t => t.chiefUserId === user.id)
        // Şef yalnızca kendi ekip(ler)ini görür — çoklu ekip desteği
        final teams = (user?.isSef == true)
            ? allTeams.where((t) => t.chiefUserId == user!.id).toList()
            : allTeams;

        if (teams.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('🚒', style: TextStyle(fontSize: 48)),
                SizedBox(height: 12),
                Text('Ekip bulunamadı',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
              ],
            ),
          );
        }

        return Column(
          children: [
            _buildHeader(teams, provider.fires),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(top: 8, bottom: 16),
                itemCount: teams.length,
                itemBuilder: (_, i) => _TeamCard(
                  team: teams[i],
                  fires: provider.fires,
                  user: user,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(List<Team> teams, List<Fire> fires) {
    final available = teams.where((t) => t.status == 'available').length;
    final onDuty = teams.where((t) => t.status == 'on_duty' || t.status == 'on_route').length;
    final maintenance = teams.where((t) => t.status == 'maintenance').length;

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statChip('🟢', '$available Uygun', AppColors.success),
          _statChip('🟡', '$onDuty Görevde', AppColors.warning),
          if (maintenance > 0)
            _statChip('🔧', '$maintenance Bakım', AppColors.textMuted),
        ],
      ),
    );
  }

  Widget _statChip(String icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(icon, style: const TextStyle(fontSize: 13)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ---- Team Card ----

class _TeamCard extends StatefulWidget {
  final Team team;
  final List<Fire> fires;
  final AppUser? user;
  const _TeamCard({required this.team, required this.fires, this.user});

  @override
  State<_TeamCard> createState() => _TeamCardState();
}

class _TeamCardState extends State<_TeamCard> {
  bool _expanded = false;

  // Şef bu ekibin chiefUserId'sine göre sahiplik kontrolü (çoklu ekip)
  bool get _isMyTeam =>
      widget.user != null && widget.team.chiefUserId == widget.user!.id;
  bool get _canEdit =>
      widget.user != null && widget.user!.isSef && _isMyTeam;

  @override
  Widget build(BuildContext context) {
    final team = widget.team;
    final sColor = statusColor(team.status);
    final score = team.readinessScore;

    return Card(
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: sColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: sColor.withValues(alpha: 0.5)),
              ),
              child: const Center(child: Text('🚒', style: TextStyle(fontSize: 20))),
            ),
            title: Row(children: [
              Expanded(
                child: Text(team.name,
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
              ),
              _statusBadge(team.statusLabel, sColor),
            ]),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(children: [
                  Text('${team.vehicleId} • ${team.chief}',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 11)),
                  if (_isMyTeam) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('Benim Ekibim',
                          style: TextStyle(color: AppColors.info, fontSize: 9)),
                    ),
                  ],
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  const Text('💧 ', style: TextStyle(fontSize: 12)),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: team.waterPercent,
                        backgroundColor: AppColors.border,
                        color: _waterColor(team.waterPercent),
                        minHeight: 5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('${team.water}%',
                      style: TextStyle(
                          color: _waterColor(team.waterPercent), fontSize: 11)),
                ]),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _scoreCircle(score),
                const SizedBox(width: 4),
                Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textMuted),
              ],
            ),
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          if (_expanded) _buildExpandedSection(context),
        ],
      ),
    );
  }

  Widget _buildExpandedSection(BuildContext context) {
    final team = widget.team;
    Fire? assignedFire;
    if (team.assignedFire != null) {
      assignedFire = widget.fires.where((f) => f.id == team.assignedFire).firstOrNull;
    }

    return Column(
      children: [
        const Divider(height: 1, color: AppColors.border),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                _statTile('👥 Personel', '${team.personnel} kişi'),
                _statTile('📍 Konum',
                    '${team.lat.toStringAsFixed(3)}, ${team.lng.toStringAsFixed(3)}'),
                _statTile('🎯 Görev',
                    team.assignedFire != null ? team.assignedFire! : 'Yok'),
              ]),
              const SizedBox(height: 10),

              // Atanan yangın bilgisi
              if (assignedFire != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    const Text('🔥 ', style: TextStyle(fontSize: 16)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${assignedFire.id} — ${assignedFire.intensityLabel} şiddet',
                              style: const TextStyle(
                                  color: AppColors.danger,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                          Text('${assignedFire.terrainLabel} • ${assignedFire.elapsedStr}',
                              style: const TextStyle(
                                  color: AppColors.textSecondary, fontSize: 11)),
                        ],
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 10),
              ],

              // Ekipman
              const Text('Ekipman:',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: team.equipment.map((e) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppColors.success.withValues(alpha: 0.3)),
                      ),
                      child: Text(e,
                          style: const TextStyle(
                              color: AppColors.success, fontSize: 11)),
                    )).toList(),
              ),

              if (_canEdit) ...[
                const SizedBox(height: 12),
                // Satır 1: Görev bitir + Ekipman güncelle
                Row(children: [
                  if (team.assignedFire != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await DatabaseService.completeTask(team.id, team.assignedFire);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text('Görev tamamlandı!'),
                              backgroundColor: AppColors.success,
                              behavior: SnackBarBehavior.floating,
                            ));
                          }
                        },
                        icon: const Icon(Icons.check_circle_outline, size: 16),
                        label: const Text('Görevi Bitir', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.success,
                          side: const BorderSide(color: AppColors.success),
                        ),
                      ),
                    ),
                  if (team.assignedFire != null) const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showEquipmentSheet(context),
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Ekipman Güncelle', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.surfaceLight,
                        foregroundColor: AppColors.textPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                // Satır 2: Bakım modu toggle (web: chiefs can toggle maintenance)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final goMaintenance = team.status != 'maintenance';
                      await DatabaseService.toggleTeamMaintenance(team.id, goMaintenance);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(goMaintenance
                              ? '${team.name} bakım moduna alındı'
                              : '${team.name} uygun duruma getirildi'),
                          backgroundColor: goMaintenance ? AppColors.warning : AppColors.success,
                          behavior: SnackBarBehavior.floating,
                        ));
                      }
                    },
                    icon: Icon(
                      team.status == 'maintenance' ? Icons.check_circle_outline : Icons.build_outlined,
                      size: 16,
                    ),
                    label: Text(
                      team.status == 'maintenance' ? 'Bakımdan Çıkar' : 'Bakım Moduna Al',
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: team.status == 'maintenance' ? AppColors.success : AppColors.warning,
                      side: BorderSide(
                          color: team.status == 'maintenance' ? AppColors.success : AppColors.warning),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Satır 3: Su seviyesi hızlı güncelleme
                _WaterUpdateRow(team: widget.team),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _showEquipmentSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (_) => _EquipmentEditSheet(team: widget.team),
    );
  }

  Widget _statusBadge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text,
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w600)),
      );

  Widget _statTile(String label, String value) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
            const SizedBox(height: 2),
            Text(value,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis),
          ],
        ),
      );

  Widget _scoreCircle(int score) {
    final color = score >= 70
        ? AppColors.success
        : score >= 40
            ? AppColors.warning
            : AppColors.danger;
    return Container(
      width: 34, height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: Center(
        child: Text('$score',
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Color _waterColor(double pct) {
    if (pct >= 0.7) return AppColors.success;
    if (pct >= 0.4) return AppColors.warning;
    return AppColors.danger;
  }
}

// ---- Su Seviyesi Hızlı Güncelleme ----

class _WaterUpdateRow extends StatefulWidget {
  final Team team;
  const _WaterUpdateRow({required this.team});

  @override
  State<_WaterUpdateRow> createState() => _WaterUpdateRowState();
}

class _WaterUpdateRowState extends State<_WaterUpdateRow> {
  late int _water;
  bool _saving = false;

  @override
  void didUpdateWidget(_WaterUpdateRow old) {
    super.didUpdateWidget(old);
    if (old.team.water != widget.team.water) {
      _water = widget.team.water;
    }
  }

  @override
  void initState() {
    super.initState();
    _water = widget.team.water;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await DatabaseService.updateTeamWaterLevel(widget.team.id, _water);
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('💧 ', style: TextStyle(fontSize: 14)),
            Text('Su Seviyesi: $_water%',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const Spacer(),
            SizedBox(
              height: 28,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.info,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  textStyle: const TextStyle(fontSize: 11),
                  minimumSize: Size.zero,
                ),
                child: _saving
                    ? const SizedBox(width: 12, height: 12,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Kaydet'),
              ),
            ),
          ]),
          Slider(
            value: _water.toDouble(),
            min: 0, max: 100, divisions: 20,
            activeColor: _water >= 50 ? AppColors.info : AppColors.danger,
            label: '$_water%',
            onChanged: (v) => setState(() => _water = v.round()),
          ),
        ],
      ),
    );
  }
}

// ---- Equipment Edit Sheet ----

class _EquipmentEditSheet extends StatefulWidget {
  final Team team;
  const _EquipmentEditSheet({required this.team});

  @override
  State<_EquipmentEditSheet> createState() => _EquipmentEditSheetState();
}

class _EquipmentEditSheetState extends State<_EquipmentEditSheet> {
  late int _water;
  late int _personnel;
  late List<String> _equipment;
  bool _saving = false;

  static const _allEquipment = ['maske', 'hortum', 'söndürücü', 'ilkyardım', 'kıskaç'];

  @override
  void initState() {
    super.initState();
    _water = widget.team.water;
    _personnel = widget.team.personnel;
    _equipment = List.from(widget.team.equipment);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await DatabaseService.updateTeamEquipment(
        widget.team.id, _water, _personnel, _equipment);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('Ekipman Güncelle',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close, color: AppColors.textMuted),
              onPressed: () => Navigator.pop(context),
            ),
          ]),
          const SizedBox(height: 16),
          Text('Su Seviyesi: $_water%',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          Slider(
            value: _water.toDouble(),
            min: 0, max: 100, divisions: 20,
            activeColor: AppColors.info,
            label: '$_water%',
            onChanged: (v) => setState(() => _water = v.round()),
          ),
          const SizedBox(height: 4),
          Text('Personel Sayısı: $_personnel',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          Slider(
            value: _personnel.toDouble(),
            min: 0, max: 10, divisions: 10,
            activeColor: AppColors.info,
            label: '$_personnel',
            onChanged: (v) => setState(() => _personnel = v.round()),
          ),
          const SizedBox(height: 8),
          const Text('Ekipman:',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _allEquipment.map((e) {
              final has = _equipment.contains(e);
              return GestureDetector(
                onTap: () =>
                    setState(() => has ? _equipment.remove(e) : _equipment.add(e)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: has
                        ? AppColors.success.withValues(alpha: 0.15)
                        : AppColors.border.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: has
                          ? AppColors.success.withValues(alpha: 0.5)
                          : AppColors.border,
                    ),
                  ),
                  child: Text(e,
                      style: TextStyle(
                          color: has ? AppColors.success : AppColors.textMuted,
                          fontSize: 13)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Kaydet'),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models/app_models.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';

/// Ekip Üyesi rolüne özel görev takip ekranı.
class MyTaskScreen extends StatelessWidget {
  const MyTaskScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (_, provider, __) {
        final user = AuthService.currentUser;
        if (user == null) return const SizedBox();

        final myTeam = provider.teams
            .where((t) => t.id == user.teamId)
            .firstOrNull;

        final assignedFire = myTeam?.assignedFire != null
            ? provider.fires
                .where((f) => f.id == myTeam!.assignedFire)
                .firstOrNull
            : null;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _RoleHeader(user: user, team: myTeam),
            const SizedBox(height: 14),
            if (assignedFire != null)
              _FireTaskCard(fire: assignedFire, team: myTeam!)
            else
              const _NoTaskCard(),
            const SizedBox(height: 14),
            if (myTeam != null) _TeamEquipmentCard(team: myTeam),
            const SizedBox(height: 14),
            const _GpsStatusCard(),
          ],
        );
      },
    );
  }
}

// ─── Rol başlığı ────────────────────────────────────────────────

class _RoleHeader extends StatelessWidget {
  final AppUser user;
  final Team? team;
  const _RoleHeader({required this.user, this.team});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: AppColors.info.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Center(child: Text('🧑‍🚒', style: TextStyle(fontSize: 22))),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user.name,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15)),
              const SizedBox(height: 2),
              Text(
                team != null
                    ? '${team!.name}  •  ${team!.vehicleId}'
                    : 'Ekip atanmamış',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.info.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text('Ekip Üyesi',
              style: TextStyle(
                  color: AppColors.info,
                  fontSize: 10,
                  fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}

// ─── Görev yok kartı ────────────────────────────────────────────

class _NoTaskCard extends StatelessWidget {
  const _NoTaskCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        children: [
          Text('✅', style: TextStyle(fontSize: 40)),
          SizedBox(height: 10),
          Text('Aktif görev yok',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          SizedBox(height: 6),
          Text(
            'Şef tarafından görev atandığında\nburada görünecek.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── Aktif yangın görevi kartı ──────────────────────────────────

class _FireTaskCard extends StatefulWidget {
  final Fire fire;
  final Team team;
  const _FireTaskCard({required this.fire, required this.team});

  @override
  State<_FireTaskCard> createState() => _FireTaskCardState();
}

class _FireTaskCardState extends State<_FireTaskCard> {
  bool _completing = false;
  bool _alreadyDone = false;
  int _completedCount = 0;
  int _totalCount = 0;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void didUpdateWidget(_FireTaskCard old) {
    super.didUpdateWidget(old);
    if (old.fire.id != widget.fire.id) _loadStatus();
  }

  Future<void> _loadStatus() async {
    final user = AuthService.currentUser;
    if (user == null) return;
    final done = await DatabaseService.hasUserCompleted(
        widget.fire.id, widget.team.id, user.id);
    final status = await DatabaseService.teamCompletionStatus(
        widget.fire.id, widget.team.id);
    if (mounted) {
      setState(() {
        _alreadyDone = done;
        _completedCount = status.completed;
        _totalCount = status.total;
      });
    }
  }

  Future<void> _complete() async {
    final user = AuthService.currentUser;
    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Görevi Tamamla',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          '${widget.fire.id} yangınındaki göreviniz tamamlandı olarak işaretlensin mi?',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text('Tamamla'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _completing = true);
    // Bireysel tamamlama — userId ile
    await DatabaseService.completeTask(
      widget.team.id,
      widget.fire.id,
      userId: user.id,
    );
    if (mounted) {
      setState(() => _completing = false);
      await _loadStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final fire = widget.fire;
    final iColor = intensityColor(fire.intensity);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: iColor.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Column(children: [
        // Başlık
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: iColor.withValues(alpha: 0.08),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(children: [
            const Text('🔥', style: TextStyle(fontSize: 26)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AKTİF GÖREV: ${fire.id}',
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(
                    '${fire.intensityLabel} şiddet  •  ${fire.terrainLabel}',
                    style: TextStyle(
                        color: iColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(fire.elapsedStr,
                  style: const TextStyle(
                      color: AppColors.danger,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ),
          ]),
        ),

        // Detaylar
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            Row(children: [
              _InfoTile('📍 Konum',
                  '${fire.lat.toStringAsFixed(4)}, ${fire.lng.toStringAsFixed(4)}'),
              _InfoTile('💨 Rüzgar', fire.direction),
              _InfoTile('📏 Çap', '${fire.radius.toStringAsFixed(0)} m'),
              _InfoTile('⚡ Yayılma', '${fire.spreadRate.toStringAsFixed(0)} m/tick'),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              _InfoTile('🌿 Arazi', fire.terrainLabel),
              _InfoTile('📡 Bildiren', fire.reportedBy),
              _InfoTile('👥 Görevli', '${fire.assignedTeams.length} ekip'),
              _InfoTile('🚒 Ekibim', widget.team.name),
            ]),
            const SizedBox(height: 14),

            // Su seviyesi
            Row(children: [
              const Text('💧 Su: ', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: widget.team.waterPercent,
                    backgroundColor: AppColors.border,
                    color: widget.team.waterPercent >= 0.5
                        ? AppColors.info
                        : AppColors.danger,
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('${widget.team.water}%',
                  style: TextStyle(
                      color: widget.team.waterPercent >= 0.5
                          ? AppColors.info
                          : AppColors.danger,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 14),

            // Ekip ilerleme göstergesi
            if (_totalCount > 0) ...[
              Row(children: [
                const Text('👥 Ekip ilerleme: ',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                Text('$_completedCount / $_totalCount üye tamamladı',
                    style: TextStyle(
                      color: _completedCount == _totalCount
                          ? AppColors.success
                          : AppColors.warning,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    )),
              ]),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _totalCount > 0 ? _completedCount / _totalCount : 0,
                  backgroundColor: AppColors.border,
                  color: _completedCount == _totalCount
                      ? AppColors.success
                      : AppColors.warning,
                  minHeight: 5,
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Buton: zaten tamamladıysa farklı göster
            if (_alreadyDone)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: AppColors.success, size: 18),
                    SizedBox(width: 8),
                    Text('Görevinizi Tamamladınız',
                        style: TextStyle(
                            color: AppColors.success,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _completing ? null : _complete,
                  icon: _completing
                      ? const SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.check_circle, size: 18),
                  label: const Text('Görevi Tamamla'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
          ]),
        ),
      ]),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  const _InfoTile(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(children: [
        Text(label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}

// ─── Ekip ekipman kartı ─────────────────────────────────────────

class _TeamEquipmentCard extends StatelessWidget {
  final Team team;
  const _TeamEquipmentCard({required this.team});

  @override
  Widget build(BuildContext context) {
    final waterColor = team.waterPercent >= 0.7
        ? AppColors.success
        : team.waterPercent >= 0.4
            ? AppColors.warning
            : AppColors.danger;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('🚒  ', style: TextStyle(fontSize: 16)),
          Expanded(
            child: Text(team.name,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor(team.status).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(team.statusLabel,
                style: TextStyle(
                    color: statusColor(team.status),
                    fontSize: 10,
                    fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          const Text('💧 ', style: TextStyle(fontSize: 13)),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: team.waterPercent,
                backgroundColor: AppColors.border,
                color: waterColor,
                minHeight: 7,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('${team.water}%',
              style: TextStyle(
                  color: waterColor, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _Chip('👥 ${team.personnel} kişi'),
          const SizedBox(width: 6),
          _Chip('🔧 ${team.equipment.length} ekipman'),
          const SizedBox(width: 6),
          _Chip('🆔 ${team.vehicleId}'),
        ]),
        if (team.equipment.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6, runSpacing: 6,
            children: team.equipment
                .map((e) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: AppColors.success.withValues(alpha: 0.3)),
                      ),
                      child: Text(e,
                          style: const TextStyle(
                              color: AppColors.success, fontSize: 11)),
                    ))
                .toList(),
          ),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _showEquipmentSheet(context, team),
            icon: const Icon(Icons.edit, size: 16),
            label: const Text('Ekipmanı Güncelle'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.info,
              side: const BorderSide(color: AppColors.info),
            ),
          ),
        ),
      ]),
    );
  }

  void _showEquipmentSheet(BuildContext context, Team team) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      isScrollControlled: true,
      builder: (_) => _EquipmentSheet(team: team),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  const _Chip(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.border.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: const TextStyle(
              color: AppColors.textSecondary, fontSize: 11)),
    );
  }
}

// ─── GPS durum kartı ────────────────────────────────────────────

class _GpsStatusCard extends StatelessWidget {
  const _GpsStatusCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.35)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.gps_fixed, color: AppColors.success, size: 18),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('GPS Konum Paylaşımı',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                      fontSize: 13)),
              SizedBox(height: 2),
              Text('Konumunuz şefe otomatik iletiliyor',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 11)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.circle, size: 8, color: AppColors.success),
              SizedBox(width: 4),
              Text('Aktif',
                  style: TextStyle(
                      color: AppColors.success,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ]),
    );
  }
}

// ─── Ekipman güncelleme sayfası ──────────────────────────────────

class _EquipmentSheet extends StatefulWidget {
  final Team team;
  const _EquipmentSheet({required this.team});

  @override
  State<_EquipmentSheet> createState() => _EquipmentSheetState();
}

class _EquipmentSheetState extends State<_EquipmentSheet> {
  late int _water;
  late int _personnel;
  late List<String> _equipment;
  bool _saving = false;

  static const _all = ['maske', 'hortum', 'söndürücü', 'ilkyardım', 'kıskaç'];

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
                onPressed: () => Navigator.pop(context)),
          ]),
          const SizedBox(height: 14),
          Text('Su Seviyesi: $_water%',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          Slider(
            value: _water.toDouble(), min: 0, max: 100, divisions: 20,
            activeColor: AppColors.info, label: '$_water%',
            onChanged: (v) => setState(() => _water = v.round()),
          ),
          Text('Personel: $_personnel kişi',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          Slider(
            value: _personnel.toDouble(), min: 0, max: 10, divisions: 10,
            activeColor: AppColors.info, label: '$_personnel',
            onChanged: (v) => setState(() => _personnel = v.round()),
          ),
          const SizedBox(height: 4),
          const Text('Ekipman:',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _all.map((e) {
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
                            : AppColors.border),
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
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Kaydet'),
            ),
          ),
        ],
      ),
    );
  }
}

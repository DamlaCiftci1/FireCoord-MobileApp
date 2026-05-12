import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models/app_models.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';

class FiresScreen extends StatefulWidget {
  const FiresScreen({super.key});

  @override
  State<FiresScreen> createState() => _FiresScreenState();
}

class _FiresScreenState extends State<FiresScreen> {
  bool _showExtinguished = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (ctx, provider, __) {
        final fires = provider.fires;
        final extinguished = provider.extinguishedFires;
        final user = AuthService.currentUser;

        if (fires.isEmpty && extinguished.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('✅', style: TextStyle(fontSize: 48)),
                SizedBox(height: 12),
                Text('Aktif yangın yok',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
              ],
            ),
          );
        }

        return Column(
          children: [
            _buildSummaryBar(fires, extinguished),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: 8, bottom: 16),
                children: [
                  // Aktif yangınlar
                  if (fires.isNotEmpty) ...[
                    _sectionHeader('🔥 Aktif Yangınlar', fires.length, AppColors.danger),
                    ...fires.map((f) => _FireCard(fire: f, teams: provider.teams, user: user)),
                  ] else
                    _emptySection('✅ Aktif yangın yok'),

                  // Sönen yangınlar toggle
                  if (extinguished.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _extinguishedHeader(extinguished.length),
                    if (_showExtinguished)
                      ...extinguished.map((f) => _ExtinguishedCard(fire: f)),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryBar(List<Fire> fires, List<Fire> extinguished) {
    final high = fires.where((f) => f.intensity == 'high').length;
    final medium = fires.where((f) => f.intensity == 'medium').length;
    final unassigned = fires.where((f) => f.assignedTeams.isEmpty).length;

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Text('🔥 ', style: TextStyle(fontSize: 14)),
          Text('${fires.length} Aktif  ',
              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
          if (high > 0) _badge('$high Yüksek', AppColors.danger),
          const SizedBox(width: 4),
          if (medium > 0) _badge('$medium Orta', AppColors.warning),
          const Spacer(),
          if (unassigned > 0) _badge('$unassigned Ekipsiz', AppColors.warning),
          if (extinguished.isNotEmpty) ...[
            const SizedBox(width: 4),
            _badge('${extinguished.length} Söndü', AppColors.textMuted),
          ],
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(children: [
        Text(title, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text('$count', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }

  Widget _extinguishedHeader(int count) {
    return InkWell(
      onTap: () => setState(() => _showExtinguished = !_showExtinguished),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          const Text('💧', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Text('Söndürülen Yangınlar ($count)',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
          const Spacer(),
          Icon(
            _showExtinguished ? Icons.expand_less : Icons.expand_more,
            color: AppColors.textMuted,
          ),
        ]),
      ),
    );
  }

  Widget _emptySection(String msg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(msg, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(text,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

// ---- Söndürülen yangın kartı (salt-okunur) ----

class _ExtinguishedCard extends StatelessWidget {
  final Fire fire;
  const _ExtinguishedCard({required this.fire});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: AppColors.textMuted.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border),
          ),
          child: const Center(child: Text('💧', style: TextStyle(fontSize: 16))),
        ),
        title: Row(children: [
          Text(fire.id,
              style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.textMuted.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text('Söndürüldü',
                style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
          ),
        ]),
        subtitle: Text(
          '${fire.terrainLabel}  •  ${fire.reportedBy}  •  ${fire.elapsedStr}',
          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
        ),
        trailing: Text(
          '${fire.radius.toStringAsFixed(0)}m',
          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
        ),
      ),
    );
  }
}

// ---- Fire Card ----

class _FireCard extends StatefulWidget {
  final Fire fire;
  final List<Team> teams;
  final AppUser? user;
  const _FireCard({required this.fire, required this.teams, this.user});

  @override
  State<_FireCard> createState() => _FireCardState();
}

class _FireCardState extends State<_FireCard> {
  bool _expanded = false;
  bool _assigning = false;
  bool _extinguishing = false;

  bool get _isSef => widget.user?.isSef == true;

  // Web: getMyTeams() — chiefUserId === user.id
  List<Team> get _myTeams {
    final uid = widget.user?.id ?? '';
    return widget.teams.where((t) => t.chiefUserId == uid).toList();
  }

  // Dispatch edilebilir ekipler (bu yangına atanmamış, bakımda değil)
  List<Team> _dispatchable(Fire fire) =>
      _myTeams.where((t) =>
          !fire.assignedTeams.contains(t.id) && t.status != 'maintenance').toList();

  // Tek ekip varsa direkt ata, birden fazlaysa seçim dialogu göster
  Future<void> _assignMyTeam() async {
    final dispatchable = _dispatchable(widget.fire);
    if (dispatchable.isEmpty) return;

    Team? chosen;
    if (dispatchable.length == 1) {
      chosen = dispatchable.first;
    } else {
      // Birden fazla ekip → kullanıcı seçsin
      chosen = await showDialog<Team>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Hangi Ekibi Gönder?',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 15)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: dispatchable.map((t) => ListTile(
              leading: const Text('🚒', style: TextStyle(fontSize: 20)),
              title: Text(t.name, style: const TextStyle(color: AppColors.textPrimary)),
              subtitle: Text('Su: ${t.water}%  •  ${t.personnel} kişi',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              onTap: () => Navigator.pop(context, t),
            )).toList(),
          ),
        ),
      );
    }
    if (chosen == null) return;
    setState(() => _assigning = true);
    await DatabaseService.assignTeamToFire(chosen.id, widget.fire.id);
    if (mounted) {
      _showSnack('${chosen.name} yangına atandı!', AppColors.success);
      setState(() => _assigning = false);
    }
  }

  Future<void> _extinguishFire() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Yangını Söndür',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          '${widget.fire.id} yangını söndürüldü olarak işaretlensin mi? '
          'Görevdeki ekipler otomatik serbest bırakılacak.',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.info),
            child: const Text('Söndür'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _extinguishing = true);
    await DatabaseService.extinguishFire(widget.fire.id);
    if (mounted) {
      setState(() => _extinguishing = false);
      _showSnack('${widget.fire.id} söndürüldü!', AppColors.success);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fire = widget.fire;
    final iColor = intensityColor(fire.intensity);
    final userId = widget.user?.id ?? '';

    // Web: dispatch butonu sadece assignedChiefs içindeyse gösterilir
    final isChiefAssigned = _isSef && fire.assignedChiefs.contains(userId);

    // Benim ekiplerimden bu yangına atanmış olanlar
    final myAssignedTeamIds = _myTeams
        .map((t) => t.id)
        .where((id) => fire.assignedTeams.contains(id))
        .toList();
    final anyMyTeamOnFire = myAssignedTeamIds.isNotEmpty;

    final canAssign = isChiefAssigned && _dispatchable(fire).isNotEmpty;
    final canExtinguish = _isSef && isChiefAssigned;

    return Card(
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: iColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: iColor.withValues(alpha: 0.4)),
              ),
              child: const Center(child: Text('🔥', style: TextStyle(fontSize: 18))),
            ),
            title: Row(children: [
              Text(fire.id,
                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              _statusBadge(fire.intensityLabel, iColor),
              if (anyMyTeamOnFire) ...[
                const SizedBox(width: 6),
                _statusBadge('Ekibim Görevde', AppColors.success),
              ],
            ]),
            subtitle: Text(
              '${fire.terrainLabel}  •  ${fire.reportedBy}  •  ${fire.elapsedStr}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${fire.radius.toStringAsFixed(0)}m',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
                if (canExtinguish) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: _extinguishing ? null : _extinguishFire,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.info.withValues(alpha: 0.4)),
                      ),
                      child: _extinguishing
                          ? const SizedBox(
                              width: 12, height: 12,
                              child: CircularProgressIndicator(color: AppColors.info, strokeWidth: 2))
                          : const Icon(Icons.water_drop, size: 14, color: AppColors.info),
                    ),
                  ),
                ],
                const SizedBox(width: 4),
                Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textMuted),
              ],
            ),
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          if (_expanded) ...[
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    _infoCell('📍 Konum',
                        '${fire.lat.toStringAsFixed(4)}, ${fire.lng.toStringAsFixed(4)}'),
                    _infoCell('💨 Yön', fire.direction),
                    _infoCell('📏 Çap', '${fire.radius.toStringAsFixed(0)} m'),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    _infoCell('🌿 Arazi', fire.terrainLabel),
                    _infoCell('⚡ Yayılma', '${fire.spreadRate.toStringAsFixed(0)} m/tick'),
                    _infoCell('⏱ Süre', fire.elapsedStr),
                  ]),
                  const SizedBox(height: 12),

                  // Görevli ekipler
                  Row(children: [
                    const Text('Görevli Ekipler: ',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    if (fire.assignedTeams.isEmpty)
                      const Text('Atanmamış',
                          style: TextStyle(color: AppColors.warning, fontSize: 12))
                    else
                      ...fire.assignedTeams.map((id) {
                        final isMyTeam = myAssignedTeamIds.contains(id);
                        return Container(
                          margin: const EdgeInsets.only(right: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (isMyTeam ? AppColors.success : AppColors.info).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(id,
                              style: TextStyle(
                                  color: isMyTeam ? AppColors.success : AppColors.info,
                                  fontSize: 11)),
                        );
                      }),
                  ]),

                  // Şefin ekibini ata butonu
                  // Şef atanmış ama henüz ekip dispatch etmemiş
                  if (isChiefAssigned && canAssign) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _assigning ? null : _assignMyTeam,
                        icon: _assigning
                            ? const SizedBox(
                                width: 14, height: 14,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.send, size: 16),
                        label: Text(_dispatchable(fire).length == 1
                            ? 'Ekibimi Ata (${_dispatchable(fire).first.name})'
                            : 'Ekip Seç & Gönder (${_dispatchable(fire).length} ekip)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          textStyle: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                  ],

                  // Şef atanmamış — bilgi mesajı
                  if (_isSef && !isChiefAssigned) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.textMuted.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Text(
                        'ℹ️  Bu yangına şef olarak atanmadınız. Merkez sizi atayana kadar ekip gönderemezsiniz.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],

                  // Ekip(ler) zaten görevde
                  if (anyMyTeamOnFire) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
                      ),
                      child: Center(
                        child: Text(
                          '✅  Ekibiniz bu yangında görevde (${myAssignedTeamIds.join(", ")})',
                          style: const TextStyle(color: AppColors.success, fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }

  Widget _infoCell(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models/app_models.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';

class FiresScreen extends StatelessWidget {
  const FiresScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (_, provider, __) {
        final fires = provider.fires;
        if (fires.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('✅', style: TextStyle(fontSize: 48)),
                SizedBox(height: 12),
                Text('Aktif yangın yok', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
              ],
            ),
          );
        }
        return Column(
          children: [
            _buildSummaryBar(fires),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(top: 8, bottom: 16),
                itemCount: fires.length,
                itemBuilder: (_, i) => _FireCard(fire: fires[i], teams: provider.teams),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryBar(List<Fire> fires) {
    final high = fires.where((f) => f.intensity == 'high').length;
    final medium = fires.where((f) => f.intensity == 'medium').length;
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          const Text('🔥 ', style: TextStyle(fontSize: 14)),
          Text('${fires.length} Aktif Yangın  ',
              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
          if (high > 0)
            _badge('$high Yüksek', AppColors.danger),
          const SizedBox(width: 6),
          if (medium > 0)
            _badge('$medium Orta', AppColors.warning),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _FireCard extends StatefulWidget {
  final Fire fire;
  final List<Team> teams;
  const _FireCard({required this.fire, required this.teams});

  @override
  State<_FireCard> createState() => _FireCardState();
}

class _FireCardState extends State<_FireCard> {
  bool _expanded = false;
  bool _assigning = false;

  Future<void> _assignBestTeam() async {
    setState(() => _assigning = true);
    final available = widget.teams.where((t) => t.status == 'available').toList();
    if (available.isEmpty) {
      if (mounted) _showSnack('Uygun ekip bulunamadı!', AppColors.warning);
      setState(() => _assigning = false);
      return;
    }
    available.sort((a, b) => b.readinessScore.compareTo(a.readinessScore));
    final best = available.first;
    await DatabaseService.assignTeamToFire(best.id, widget.fire.id);
    if (mounted) _showSnack('${best.name} atandı!', AppColors.success);
    setState(() => _assigning = false);
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
    final user = AuthService.currentUser;
    final canAssign = user != null && (user.isMerkez || user.isSef);
    final iColor = intensityColor(fire.intensity);

    return Card(
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: iColor.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: iColor.withOpacity(0.4)),
              ),
              child: const Center(child: Text('🔥', style: TextStyle(fontSize: 18))),
            ),
            title: Row(children: [
              Text(fire.id, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              _statusBadge(fire.intensityLabel, iColor),
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
                const SizedBox(width: 4),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  color: AppColors.textMuted,
                ),
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
                  // Fire info grid
                  Row(
                    children: [
                      _infoCell('📍 Konum', '${fire.lat.toStringAsFixed(4)}, ${fire.lng.toStringAsFixed(4)}'),
                      _infoCell('💨 Yayılma', fire.direction),
                      _infoCell('🌡️ Çap', '${fire.radius.toStringAsFixed(0)} m'),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Assigned teams
                  Row(children: [
                    const Text('Görevli Ekipler: ', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    if (fire.assignedTeams.isEmpty)
                      const Text('Atanmamış', style: TextStyle(color: AppColors.warning, fontSize: 12))
                    else
                      ...fire.assignedTeams.map((id) =>
                          Container(
                            margin: const EdgeInsets.only(right: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.info.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(id, style: const TextStyle(color: AppColors.info, fontSize: 11)),
                          )),
                  ]),
                  const SizedBox(height: 12),

                  if (canAssign)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _assigning ? null : _assignBestTeam,
                        icon: _assigning
                            ? const SizedBox(width: 14, height: 14,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.send, size: 16),
                        label: const Text('En İyi Ekibi Ata'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          textStyle: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
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
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }

  Widget _infoCell(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models/app_models.dart';
import '../utils/app_theme.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _mapController = MapController();
  static const _center = LatLng(39.9208, 32.8700);

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (_, provider, __) {
        return Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: const MapOptions(
                initialCenter: _center,
                initialZoom: 13,
                backgroundColor: Color(0xFF1a1a2e),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.firecoord.mobile',
                ),
                CircleLayer(
                  circles: provider.fires.map((fire) => CircleMarker(
                    point: LatLng(fire.lat, fire.lng),
                    radius: fire.radius,
                    useRadiusInMeter: true,
                    color: Colors.red.withOpacity(0.2),
                    borderColor: Colors.red.withOpacity(0.6),
                    borderStrokeWidth: 1.5,
                  )).toList(),
                ),
                MarkerLayer(
                  markers: provider.teams.map((team) {
                    final color = statusColor(team.status);
                    return Marker(
                      point: LatLng(team.lat, team.lng),
                      width: 36,
                      height: 36,
                      child: _TeamMarker(team: team, color: color),
                    );
                  }).toList(),
                ),
                MarkerLayer(
                  markers: provider.fires.map((fire) => Marker(
                    point: LatLng(fire.lat, fire.lng),
                    width: 36,
                    height: 36,
                    child: _FireMarker(fire: fire),
                  )).toList(),
                ),
              ],
            ),

            Positioned(
              top: 0, left: 0, right: 0,
              child: _buildStatsBar(provider),
            ),

            Positioned(
              right: 12, bottom: 80,
              child: Column(children: [
                _mapBtn(Icons.add, () => _mapController.move(
                  _mapController.camera.center,
                  _mapController.camera.zoom + 1,
                )),
                const SizedBox(height: 8),
                _mapBtn(Icons.remove, () => _mapController.move(
                  _mapController.camera.center,
                  _mapController.camera.zoom - 1,
                )),
                const SizedBox(height: 8),
                _mapBtn(Icons.my_location, () => _mapController.move(_center, 13)),
              ]),
            ),

            Positioned(
              bottom: 12, left: 12,
              child: _buildLegend(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatsBar(AppStateProvider provider) {
    final available = provider.teams.where((t) => t.status == 'available').length;
    final onDuty = provider.teams.where((t) => t.status == 'on_duty').length;
    return Container(
      color: AppColors.surface.withOpacity(0.95),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statChip('🔥', '${provider.fires.length} Yangın', AppColors.primary),
          _statChip('🟢', '$available Uygun', AppColors.success),
          _statChip('🟡', '$onDuty Görevde', AppColors.warning),
        ],
      ),
    );
  }

  Widget _statChip(String icon, String label, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(icon, style: const TextStyle(fontSize: 13)),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    ],
  );

  Widget _buildLegend() => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: AppColors.surface.withOpacity(0.92),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _legendRow('🔥', 'Yangın', Colors.red),
        _legendRow('🚒', 'Uygun Ekip', AppColors.success),
        _legendRow('🚒', 'Görevde', AppColors.warning),
        _legendRow('⭕', 'Yayılma Alanı', Colors.red.withOpacity(0.5)),
      ],
    ),
  );

  Widget _legendRow(String icon, String label, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(icon, style: const TextStyle(fontSize: 12)),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(color: color, fontSize: 11)),
    ]),
  );

  Widget _mapBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 38, height: 38,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Icon(icon, color: AppColors.textPrimary, size: 18),
    ),
  );
}

// ---- Fire Marker ----

class _FireMarker extends StatefulWidget {
  final Fire fire;
  const _FireMarker({required this.fire});
  @override
  State<_FireMarker> createState() => _FireMarkerState();
}

class _FireMarkerState extends State<_FireMarker> {
  bool _showInfo = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _showInfo = !_showInfo),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 1.5),
            ),
            child: const Center(child: Text('🔥', style: TextStyle(fontSize: 18))),
          ),
          if (_showInfo)
            Positioned(
              bottom: 40, left: -60,
              child: Container(
                width: 150,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(widget.fire.id,
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 12)),
                    Text('${widget.fire.intensityLabel} • ${widget.fire.terrainLabel}',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                    Text('Süre: ${widget.fire.elapsedStr}',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---- Team Marker ----

class _TeamMarker extends StatefulWidget {
  final Team team;
  final Color color;
  const _TeamMarker({required this.team, required this.color});
  @override
  State<_TeamMarker> createState() => _TeamMarkerState();
}

class _TeamMarkerState extends State<_TeamMarker> {
  bool _showInfo = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _showInfo = !_showInfo),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: widget.color.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: widget.color, width: 1.5),
            ),
            child: const Center(child: Text('🚒', style: TextStyle(fontSize: 17))),
          ),
          if (_showInfo)
            Positioned(
              bottom: 38, left: -55,
              child: Container(
                width: 140,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(widget.team.name,
                        style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 12)),
                    Text(widget.team.statusLabel,
                        style: TextStyle(color: widget.color, fontSize: 11)),
                    Text('Su: ${widget.team.water}% • ${widget.team.personnel} kişi',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

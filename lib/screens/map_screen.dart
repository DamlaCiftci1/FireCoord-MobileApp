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
  static const _initialCenter = LatLng(39.9208, 32.8700);
  static const _initialZoom = 13.0;

  List<CircleMarker> _circles = [];
  List<Marker> _markers = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<AppStateProvider>();
    _buildMapObjects(provider.fires, provider.teams);
  }

  void _buildMapObjects(List<Fire> fires, List<Team> teams) {
    final circles = <CircleMarker>[];
    final markers = <Marker>[];

    for (final fire in fires) {
      circles.add(CircleMarker(
        point: LatLng(fire.lat, fire.lng),
        radius: fire.radius,
        useRadiusInMeter: true,
        color: Colors.red.withValues(alpha:0.2),
        borderColor: Colors.red.withValues(alpha:0.6),
        borderStrokeWidth: 1.5,
      ));

      markers.add(Marker(
        point: LatLng(fire.lat, fire.lng),
        width: 44,
        height: 68,
        child: GestureDetector(
          onTap: () => _showFireInfo(fire),
          child: Column(
            children: [
              const Text('🔥', style: TextStyle(fontSize: 28)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha:0.85),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  fire.intensityLabel,
                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ));
    }

    for (final team in teams) {
      final color = _teamColor(team.status);
      markers.add(Marker(
        point: LatLng(team.lat, team.lng),
        width: 44,
        height: 68,
        child: GestureDetector(
          onTap: () => _showTeamInfo(team),
          child: Column(
            children: [
              const Text('🚒', style: TextStyle(fontSize: 28)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: color.withValues(alpha:0.85),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  team.statusLabel,
                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ));
    }

    if (mounted) {
      setState(() {
        _circles = circles;
        _markers = markers;
      });
    }
  }

  Color _teamColor(String status) {
    switch (status) {
      case 'available': return Colors.green;
      case 'on_duty': return Colors.orange;
      case 'on_route': return Colors.cyan;
      default: return Colors.blueGrey;
    }
  }

  void _showFireInfo(Fire fire) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('🔥 ${fire.id}', style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('Yoğunluk', fire.intensityLabel),
            _infoRow('Arazi', fire.terrainLabel),
            _infoRow('Süre', fire.elapsedStr),
            _infoRow('Konum', '${fire.lat.toStringAsFixed(4)}, ${fire.lng.toStringAsFixed(4)}'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kapat')),
        ],
      ),
    );
  }

  void _showTeamInfo(Team team) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('🚒 ${team.name}', style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('Durum', team.statusLabel),
            _infoRow('Su', '${team.water}%'),
            _infoRow('Personel', '${team.personnel} kişi'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kapat')),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text('$label: ', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (_, provider, __) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _buildMapObjects(provider.fires, provider.teams);
        });

        return Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: const MapOptions(
                initialCenter: _initialCenter,
                initialZoom: _initialZoom,
                maxZoom: 19,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  maxZoom: 19,
                  retinaMode: RetinaMode.isHighDensity(context),
                  userAgentPackageName: 'com.firecoord.mobile',
                ),
                CircleLayer(circles: _circles),
                MarkerLayer(markers: _markers),
              ],
            ),

            // Legend
            Positioned(
              bottom: 16,
              left: 16,
              child: _buildLegend(),
            ),

            // Zoom controls
            Positioned(
              right: 16,
              bottom: 80,
              child: Column(
                children: [
                  _mapBtn(Icons.add, () {
                    _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom + 1,
                    );
                  }),
                  const SizedBox(height: 8),
                  _mapBtn(Icons.remove, () {
                    _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom - 1,
                    );
                  }),
                  const SizedBox(height: 8),
                  _mapBtn(Icons.my_location, () {
                    _mapController.move(_initialCenter, _initialZoom);
                  }),
                ],
              ),
            ),

            // Stats bar
            Positioned(
              top: 0, left: 0, right: 0,
              child: _buildStatsBar(provider),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatsBar(AppStateProvider provider) {
    final activeFires = provider.fires.length;
    final availableTeams = provider.teams.where((t) => t.status == 'available').length;
    final onDutyTeams = provider.teams.where((t) => t.status == 'on_duty').length;

    return Container(
      color: AppColors.surface.withValues(alpha:0.95),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statChip('🔥', '$activeFires Yangın', AppColors.primary),
          _statChip('🟢', '$availableTeams Uygun', AppColors.success),
          _statChip('🟡', '$onDutyTeams Görevde', AppColors.warning),
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

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha:0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _legendItem('🔥', 'Yangın', Colors.red),
          _legendItem('🚒', 'Uygun Ekip', Colors.green),
          _legendItem('🚒', 'Görevde', Colors.orange),
          _legendItem('⭕', 'Yayılma Alanı', Colors.red.withValues(alpha:0.5)),
        ],
      ),
    );
  }

  Widget _legendItem(String icon, String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _mapBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, color: AppColors.textPrimary, size: 20),
      ),
    );
  }
}

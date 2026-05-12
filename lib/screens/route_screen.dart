import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models/app_models.dart';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';

class RouteScreen extends StatefulWidget {
  const RouteScreen({super.key});

  @override
  State<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends State<RouteScreen> {
  final _mapController = MapController();

  String? _selectedFireId;
  String? _selectedTeamId;

  bool _calculating = false;
  List<LatLng> _routePoints = [];
  double? _distanceKm;
  double? _etaMin;
  double? _suitabilityScore;
  String? _routeError;

  // Web'deki teamScore() fonksiyonunun birebir karşılığı
  double _teamScore(Team team, Fire fire) {
    if (team.status == 'maintenance') return 0;
    final dist = _haversine(team.lat, team.lng, fire.lat, fire.lng);
    final waterScore = team.maxWater > 0 ? team.water / team.maxWater : 0;
    final personnelScore = math.min(team.personnel / 5.0, 1.0);
    final distScore = math.max(0, 1 - dist / 30.0);
    final statusBonus = team.status == 'available' ? 0.2 : 0.0;
    return waterScore * 0.35 + personnelScore * 0.25 + distScore * 0.3 + statusBonus;
  }

  double _haversine(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLng = (lng2 - lng1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  List<Team> _myTeams(List<Team> all) {
    final user = AuthService.currentUser;
    if (user == null) return [];
    // Web: getMyTeams() = teams.filter(t => t.chiefUserId === user.id)
    return all.where((t) => t.chiefUserId == user.id).toList();
  }

  List<Fire> _myFires(List<Fire> all) {
    final user = AuthService.currentUser;
    if (user == null) return [];
    // Şefin atandığı yangınlar (assignedChiefs içinde user.id olanlar)
    return all.where((f) => f.assignedChiefs.contains(user.id)).toList();
  }

  Future<void> _calculateRoute(Team team, Fire fire) async {
    setState(() {
      _calculating = true;
      _routePoints = [];
      _routeError = null;
      _distanceKm = null;
      _etaMin = null;
      _suitabilityScore = null;
    });

    // Uygunluk skoru (web'deki teamScore)
    final score = _teamScore(team, fire);
    _suitabilityScore = (score * 100).roundToDouble();

    // OSRM ile gerçek rota
    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${team.lng},${team.lat};${fire.lng},${fire.lat}'
        '?overview=full&geometries=geojson',
      );
      final res = await http.get(url).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final route = data['routes'][0];
        _distanceKm = (route['distance'] as num) / 1000.0;
        _etaMin = (route['duration'] as num) / 60.0;

        // GeoJSON koordinatlarını LatLng listesine çevir
        final coords = (route['geometry']['coordinates'] as List)
            .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
            .toList();
        _routePoints = coords;
      } else {
        _fallbackToStraightLine(team, fire);
      }
    } catch (_) {
      _fallbackToStraightLine(team, fire);
    }

    // Haritayı rota sınırlarına göre ayarla
    if (_routePoints.length >= 2 && mounted) {
      final bounds = LatLngBounds.fromPoints(_routePoints);
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(40)),
      );
    }

    if (mounted) setState(() => _calculating = false);
  }

  void _fallbackToStraightLine(Team team, Fire fire) {
    _routePoints = [LatLng(team.lat, team.lng), LatLng(fire.lat, fire.lng)];
    _distanceKm = _haversine(team.lat, team.lng, fire.lat, fire.lng);
    // ETA: mesafe / ekip hızı (km/h) * 60 dk
    final speedKmh = team.speed > 0 ? team.speed.toDouble() : 60.0;
    _etaMin = (_distanceKm! / speedKmh) * 60;
    _routeError = 'Çevrimiçi rota alınamadı — düz çizgi gösteriliyor';
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
        final myTeams = _myTeams(provider.teams);
        final myFires = _myFires(provider.fires);

        // Seçili fire/team objelerini bul
        final selFire = myFires.where((f) => f.id == _selectedFireId).firstOrNull;
        final selTeam = myTeams.where((t) => t.id == _selectedTeamId).firstOrNull;

        return Column(
          children: [
            // ── Seçim paneli ──────────────────────────────────
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(children: [
                    Expanded(
                      child: _dropdown<String>(
                        label: '🔥 Yangın Seç',
                        value: _selectedFireId,
                        items: myFires.isEmpty
                            ? [const DropdownMenuItem(value: '__none', child: Text('Atanmış yangın yok', overflow: TextOverflow.ellipsis))]
                            : myFires.map((f) => DropdownMenuItem(
                                  value: f.id,
                                  child: Text(
                                    '${f.id} — ${f.intensityLabel}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                )).toList(),
                        onChanged: myFires.isEmpty
                            ? null
                            : (v) => setState(() {
                                  _selectedFireId = v;
                                  _routePoints = [];
                                }),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _dropdown<String>(
                        label: '🚒 Ekip Seç',
                        value: _selectedTeamId,
                        items: myTeams.isEmpty
                            ? [const DropdownMenuItem(value: '__none', child: Text('Ekip yok', overflow: TextOverflow.ellipsis))]
                            : myTeams.map((t) => DropdownMenuItem(
                                  value: t.id,
                                  child: Text(
                                    t.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                )).toList(),
                        onChanged: myTeams.isEmpty
                            ? null
                            : (v) => setState(() {
                                  _selectedTeamId = v;
                                  _routePoints = [];
                                }),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: (_calculating || selFire == null || selTeam == null)
                          ? null
                          : () => _calculateRoute(selTeam, selFire),
                      icon: _calculating
                          ? const SizedBox(
                              width: 14, height: 14,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.route, size: 18),
                      label: Text(_calculating ? 'Hesaplanıyor…' : 'Rotayı Hesapla'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.info,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── İstatistik kartı ──────────────────────────────
            if (_distanceKm != null) _buildStatsCard(selTeam, selFire),

            // ── Uyarı ─────────────────────────────────────────
            if (_routeError != null)
              Container(
                color: AppColors.warning.withValues(alpha: 0.1),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Row(children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 16),
                  const SizedBox(width: 6),
                  Expanded(child: Text(_routeError!, style: const TextStyle(color: AppColors.warning, fontSize: 11))),
                ]),
              ),

            // ── Harita ────────────────────────────────────────
            Expanded(
              child: _buildMap(selTeam, selFire),
            ),

            // ── Boş durum mesajı ──────────────────────────────
            if (myFires.isEmpty)
              Container(
                color: AppColors.surface,
                padding: const EdgeInsets.all(12),
                child: const Text(
                  'ℹ️  Merkez sizi bir yangına atadığında rota planlayabilirsiniz.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildStatsCard(Team? team, Fire? fire) {
    final etaStr = _etaMin != null
        ? _etaMin! < 60
            ? '${_etaMin!.toStringAsFixed(0)} dk'
            : '${(_etaMin! / 60).toStringAsFixed(1)} sa'
        : '—';
    final distStr = _distanceKm != null ? '${_distanceKm!.toStringAsFixed(1)} km' : '—';
    final scoreColor = _suitabilityScore != null
        ? _suitabilityScore! >= 60
            ? AppColors.success
            : _suitabilityScore! >= 30
                ? AppColors.warning
                : AppColors.danger
        : AppColors.textMuted;

    return Container(
      color: AppColors.surfaceLight,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statCell('📍 Mesafe', distStr, AppColors.info),
          _statCell('⏱ ETA', etaStr, AppColors.warning),
          _statCell('⭐ Uygunluk', '${_suitabilityScore?.toStringAsFixed(0) ?? "—"}%', scoreColor),
          if (team != null) _statCell('💧 Su', '${team.water}%',
              team.waterPercent >= 0.5 ? AppColors.success : AppColors.danger),
          if (team != null) _statCell('👥', '${team.personnel} kişi', AppColors.textSecondary),
        ],
      ),
    );
  }

  Widget _statCell(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _buildMap(Team? team, Fire? fire) {
    final markers = <Marker>[];
    if (team != null) {
      markers.add(Marker(
        point: LatLng(team.lat, team.lng),
        width: 50, height: 60,
        child: Column(children: [
          const Text('🚒', style: TextStyle(fontSize: 28)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(4)),
            child: Text(team.name, style: const TextStyle(color: Colors.white, fontSize: 8), overflow: TextOverflow.ellipsis),
          ),
        ]),
      ));
    }
    if (fire != null) {
      markers.add(Marker(
        point: LatLng(fire.lat, fire.lng),
        width: 50, height: 60,
        child: Column(children: [
          const Text('🔥', style: TextStyle(fontSize: 28)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(4)),
            child: Text(fire.id, style: const TextStyle(color: Colors.white, fontSize: 8)),
          ),
        ]),
      ));
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: team != null
            ? LatLng(team.lat, team.lng)
            : const LatLng(39.9208, 32.8700),
        initialZoom: 12,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          maxZoom: 19,
          userAgentPackageName: 'com.firecoord.mobile',
        ),
        if (_routePoints.length >= 2)
          PolylineLayer(polylines: [
            Polyline(
              points: _routePoints,
              color: AppColors.info,
              strokeWidth: 4,
            ),
          ]),
        if (fire != null)
          CircleLayer(circles: [
            CircleMarker(
              point: LatLng(fire.lat, fire.lng),
              radius: fire.radius,
              useRadiusInMeter: true,
              color: AppColors.danger.withValues(alpha: 0.15),
              borderColor: AppColors.danger.withValues(alpha: 0.5),
              borderStrokeWidth: 1.5,
            ),
          ]),
        MarkerLayer(markers: markers),
      ],
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: DropdownButton<T>(
            value: value,
            items: items,
            onChanged: onChanged,
            dropdownColor: AppColors.surfaceLight,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
            isExpanded: true,
            underline: const SizedBox(),
          ),
        ),
      ],
    );
  }
}

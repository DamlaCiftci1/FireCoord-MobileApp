// ============================================================
//  FireCoord — Data Models
// ============================================================

class Fire {
  final String id;
  double lat;
  double lng;
  double radius;
  String direction;
  String intensity;
  String terrain;
  DateTime startTime;
  String status;
  String reportedBy;
  List<String> assignedTeams;
  double spreadRate;

  Fire({
    required this.id,
    required this.lat,
    required this.lng,
    this.radius = 200,
    this.direction = 'N',
    this.intensity = 'medium',
    this.terrain = 'forest',
    required this.startTime,
    this.status = 'active',
    this.reportedBy = 'Manual',
    this.assignedTeams = const [],
    this.spreadRate = 8,
  });

  factory Fire.fromJson(String id, Map<Object?, Object?> json) {
    List<String> teams = [];
    if (json['assignedTeams'] != null) {
      final raw = json['assignedTeams'];
      if (raw is Map) {
        teams = raw.values.map((e) => e.toString()).toList();
      } else if (raw is List) {
        teams = raw.whereType<String>().toList();
      }
    }
    return Fire(
      id: id,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      radius: (json['radius'] as num?)?.toDouble() ?? 200,
      direction: json['direction']?.toString() ?? 'N',
      intensity: json['intensity']?.toString() ?? 'medium',
      terrain: json['terrain']?.toString() ?? 'forest',
      startTime: DateTime.fromMillisecondsSinceEpoch(
          (json['startTime'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch),
      status: json['status']?.toString() ?? 'active',
      reportedBy: json['reportedBy']?.toString() ?? 'Manual',
      assignedTeams: teams,
      spreadRate: (json['spreadRate'] as num?)?.toDouble() ?? 8,
    );
  }

  Map<String, dynamic> toJson() => {
    'lat': lat,
    'lng': lng,
    'radius': radius,
    'direction': direction,
    'intensity': intensity,
    'terrain': terrain,
    'startTime': startTime.millisecondsSinceEpoch,
    'status': status,
    'reportedBy': reportedBy,
    'spreadRate': spreadRate,
  };

  String get intensityLabel =>
      {'high': 'Yüksek', 'medium': 'Orta', 'low': 'Düşük'}[intensity] ?? intensity;
  String get terrainLabel =>
      {'forest': 'Orman', 'urban': 'Kentsel', 'field': 'Tarla', 'mountain': 'Dağlık'}[terrain] ?? terrain;

  String get elapsedStr {
    final m = DateTime.now().difference(startTime).inMinutes;
    if (m < 60) return '$m dk';
    return '${m ~/ 60}s ${m % 60}dk';
  }
}

class Team {
  final String id;
  String name;
  String vehicleId;
  double lat;
  double lng;
  String status;
  int water;
  int maxWater;
  int personnel;
  List<String> equipment;
  String chief;
  String? assignedFire;

  Team({
    required this.id,
    required this.name,
    required this.vehicleId,
    required this.lat,
    required this.lng,
    this.status = 'available',
    this.water = 100,
    this.maxWater = 100,
    this.personnel = 4,
    this.equipment = const ['maske', 'hortum', 'söndürücü'],
    this.chief = '',
    this.assignedFire,
  });

  factory Team.fromJson(String id, Map<Object?, Object?> json) {
    List<String> equip = [];
    if (json['equipment'] != null) {
      final raw = json['equipment'];
      if (raw is Map) {
        equip = raw.values.map((e) => e.toString()).toList();
      } else if (raw is List) {
        equip = raw.whereType<String>().toList();
      }
    }
    return Team(
      id: id,
      name: json['name']?.toString() ?? id,
      vehicleId: json['vehicleId']?.toString() ?? '',
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      status: json['status']?.toString() ?? 'available',
      water: (json['water'] as num?)?.toInt() ?? 100,
      maxWater: (json['maxWater'] as num?)?.toInt() ?? 100,
      personnel: (json['personnel'] as num?)?.toInt() ?? 4,
      equipment: equip,
      chief: json['chief']?.toString() ?? '',
      assignedFire: json['assignedFire']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'vehicleId': vehicleId,
    'lat': lat,
    'lng': lng,
    'status': status,
    'water': water,
    'maxWater': maxWater,
    'personnel': personnel,
    'equipment': equipment,
    'chief': chief,
    if (assignedFire != null) 'assignedFire': assignedFire,
  };

  String get statusLabel =>
      {'available': 'Uygun', 'on_duty': 'Görevde', 'maintenance': 'Bakımda', 'on_route': 'Yolda'}[status] ?? status;

  double get waterPercent => maxWater > 0 ? water / maxWater : 0;

  int get readinessScore {
    int s = 0;
    if (water >= 70) s += 35;
    else if (water >= 40) s += 20;
    if (personnel >= 3) s += 25;
    else if (personnel >= 1) s += 15;
    if (equipment.length >= 3) s += 25;
    else if (equipment.length >= 2) s += 15;
    if (status == 'available') s += 15;
    return s;
  }
}

class AppUser {
  final String id;
  final String name;
  final String role;
  final String username;
  final String email;
  final String teamId;

  AppUser({
    required this.id,
    required this.name,
    required this.role,
    required this.username,
    required this.email,
    this.teamId = '',
  });

  factory AppUser.fromJson(String id, Map<Object?, Object?> json) {
    return AppUser(
      id: id,
      name: json['name']?.toString() ?? '',
      role: json['role']?.toString() ?? 'ekip',
      username: json['username']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      teamId: json['teamId']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'role': role,
    'username': username,
    'email': email,
    if (teamId.isNotEmpty) 'teamId': teamId,
  };

  String get roleLabel =>
      {'merkez': 'Merkez Op.', 'sef': 'İtfaiye Şefi', 'ekip': 'Ekip Üyesi'}[role] ?? role;

  bool get isMerkez => role == 'merkez';
  bool get isSef => role == 'sef';
  bool get isEkip => role == 'ekip';
}

class AppNotification {
  final String id;
  final String text;
  final String type;
  final DateTime time;
  bool read;

  AppNotification({
    required this.id,
    required this.text,
    required this.type,
    required this.time,
    this.read = false,
  });

  factory AppNotification.fromJson(String id, Map<Object?, Object?> json) {
    return AppNotification(
      id: id,
      text: json['text']?.toString() ?? '',
      type: json['type']?.toString() ?? 'info',
      time: DateTime.fromMillisecondsSinceEpoch(
          (json['time'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch),
      read: json['read'] == true,
    );
  }
}

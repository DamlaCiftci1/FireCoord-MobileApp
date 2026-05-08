import 'package:firebase_database/firebase_database.dart';
import '../models/app_models.dart';

// Seed data matching the web panel's data.js
const _seedFires = {
  'F001': {
    'lat': 39.9334, 'lng': 32.8597, 'radius': 350, 'direction': 'NE',
    'intensity': 'high', 'terrain': 'forest', 'status': 'active',
    'reportedBy': 'Sensör-A12', 'spreadRate': 12,
  },
  'F002': {
    'lat': 39.9050, 'lng': 32.8820, 'radius': 180, 'direction': 'E',
    'intensity': 'medium', 'terrain': 'urban', 'status': 'active',
    'reportedBy': 'İhbar Hattı', 'spreadRate': 6,
  },
};

const _seedTeams = {
  'T001': {
    'name': 'Ekip Alpha', 'vehicleId': 'V001',
    'lat': 39.9208, 'lng': 32.8541, 'status': 'available',
    'water': 80, 'maxWater': 100, 'personnel': 4,
    'equipment': ['maske', 'hortum', 'söndürücü'],
    'chief': 'Ahmet Yılmaz',
  },
  'T002': {
    'name': 'Ekip Beta', 'vehicleId': 'V002',
    'lat': 39.9280, 'lng': 32.8650, 'status': 'on_duty',
    'water': 45, 'maxWater': 100, 'personnel': 3,
    'equipment': ['maske', 'hortum'],
    'chief': 'Mehmet Demir', 'assignedFire': 'F001',
  },
  'T003': {
    'name': 'Ekip Gamma', 'vehicleId': 'V003',
    'lat': 39.9420, 'lng': 32.8380, 'status': 'available',
    'water': 95, 'maxWater': 100, 'personnel': 5,
    'equipment': ['maske', 'hortum', 'söndürücü'],
    'chief': 'Ayşe Kaya',
  },
  'T004': {
    'name': 'Ekip Delta', 'vehicleId': 'V004',
    'lat': 39.9080, 'lng': 32.8940, 'status': 'maintenance',
    'water': 20, 'maxWater': 100, 'personnel': 2,
    'equipment': ['maske'],
    'chief': 'Ali Şahin',
  },
};

class DatabaseService {
  static final _db = FirebaseDatabase.instance.ref();

  // ---- Seeding ----

  static Future<void> seedIfEmpty() async {
    final snap = await _db.child('fires').once();
    if (snap.snapshot.value == null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final e in _seedFires.entries) {
        await _db.child('fires/${e.key}').set({
          ...e.value,
          'startTime': now - (e.key == 'F001' ? 45 * 60000 : 15 * 60000),
        });
      }
      for (final e in _seedTeams.entries) {
        final data = Map<String, dynamic>.from(e.value as Map);
        data['equipment'] = {
          for (int i = 0; i < (data['equipment'] as List).length; i++)
            i.toString(): (data['equipment'] as List)[i]
        };
        await _db.child('teams/${e.key}').set(data);
      }
      await _seedNotifications();
    }
  }

  static Future<void> _seedNotifications() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final notifs = [
      {'text': 'F001 yangın alanı hızla büyüyor! Rüzgar NE yönünde 25 km/s.', 'type': 'danger', 'read': false, 'time': now - 1500000},
      {'text': 'Ekip Beta (V002) F001 yangın alanına yönlendirildi.', 'type': 'info', 'read': false, 'time': now - 1620000},
      {'text': 'Yeni yangın bildirimi: F002 - Kentsel bölge', 'type': 'warning', 'read': false, 'time': now - 300000},
      {'text': 'Ekip Delta bakım moduna alındı.', 'type': 'info', 'read': true, 'time': now - 3600000},
    ];
    for (int i = 0; i < notifs.length; i++) {
      await _db.child('notifications/N00${i + 1}').set(notifs[i]);
    }
  }

  // ---- Fires ----

  static Stream<List<Fire>> firesStream() {
    return _db.child('fires').onValue.map((event) {
      if (event.snapshot.value == null) return [];
      final raw = Map<Object?, Object?>.from(event.snapshot.value as Map);
      return raw.entries.map((e) {
        return Fire.fromJson(e.key.toString(), Map<Object?, Object?>.from(e.value as Map));
      }).where((f) => f.status == 'active').toList();
    });
  }

  static Future<void> addFire(double lat, double lng, String terrain) async {
    final ref = _db.child('fires').push();
    await ref.set({
      'lat': lat, 'lng': lng, 'radius': 100,
      'direction': 'N', 'intensity': 'low', 'terrain': terrain,
      'startTime': DateTime.now().millisecondsSinceEpoch,
      'status': 'active', 'reportedBy': 'Mobil Uygulama', 'spreadRate': 8,
    });
    await addNotification('Yeni yangın bildirimi: ${terrain} bölge', 'warning');
  }

  static Future<void> updateFireRadius(String fireId, double radius) async {
    await _db.child('fires/$fireId').update({'radius': radius});
  }

  // ---- Teams ----

  static Stream<List<Team>> teamsStream() {
    return _db.child('teams').onValue.map((event) {
      if (event.snapshot.value == null) return [];
      final raw = Map<Object?, Object?>.from(event.snapshot.value as Map);
      return raw.entries.map((e) {
        return Team.fromJson(e.key.toString(), Map<Object?, Object?>.from(e.value as Map));
      }).toList();
    });
  }

  static Future<void> updateTeamLocation(String teamId, double lat, double lng) async {
    await _db.child('teams/$teamId').update({'lat': lat, 'lng': lng});
  }

  static Future<void> updateTeamStatus(String teamId, String status) async {
    await _db.child('teams/$teamId').update({'status': status});
  }

  static Future<void> updateTeamEquipment(String teamId, int water, int personnel, List<String> equipment) async {
    await _db.child('teams/$teamId').update({
      'water': water,
      'personnel': personnel,
      'equipment': {for (int i = 0; i < equipment.length; i++) i.toString(): equipment[i]},
    });
    await addNotification('Ekip ekipman bilgisi güncellendi ($teamId)', 'info');
  }

  static Future<void> assignTeamToFire(String teamId, String fireId) async {
    await _db.child('teams/$teamId').update({'assignedFire': fireId, 'status': 'on_route'});
    // Add team to fire's assignedTeams list
    final key = DateTime.now().millisecondsSinceEpoch.toString();
    await _db.child('fires/$fireId/assignedTeams/$key').set(teamId);
    await addNotification('Ekip $teamId yangına atandı ($fireId)', 'info');
  }

  static Future<void> completeTask(String teamId) async {
    await _db.child('teams/$teamId').update({
      'assignedFire': null,
      'status': 'available',
    });
    await addNotification('Görev tamamlandı - Ekip $teamId uygun durumda', 'success');
  }

  // ---- Notifications ----

  static Stream<List<AppNotification>> notificationsStream() {
    return _db.child('notifications').onValue.map((event) {
      if (event.snapshot.value == null) return [];
      final raw = Map<Object?, Object?>.from(event.snapshot.value as Map);
      final list = raw.entries.map((e) {
        return AppNotification.fromJson(e.key.toString(), Map<Object?, Object?>.from(e.value as Map));
      }).toList();
      list.sort((a, b) => b.time.compareTo(a.time));
      return list;
    });
  }

  static Future<void> addNotification(String text, String type) async {
    final ref = _db.child('notifications').push();
    await ref.set({
      'text': text,
      'type': type,
      'time': DateTime.now().millisecondsSinceEpoch,
      'read': false,
    });
  }

  static Future<void> markNotificationRead(String notifId) async {
    await _db.child('notifications/$notifId').update({'read': true});
  }

  static Future<void> markAllRead() async {
    final snap = await _db.child('notifications').once();
    if (snap.snapshot.value == null) return;
    final raw = Map<Object?, Object?>.from(snap.snapshot.value as Map);
    for (final key in raw.keys) {
      await _db.child('notifications/$key').update({'read': true});
    }
  }

  // ---- Users ----

  static Stream<List<AppUser>> usersStream() {
    return _db.child('users').onValue.map((event) {
      if (event.snapshot.value == null) return [];
      final raw = Map<Object?, Object?>.from(event.snapshot.value as Map);
      return raw.entries.map((e) {
        return AppUser.fromJson(e.key.toString(), Map<Object?, Object?>.from(e.value as Map));
      }).toList();
    });
  }
}

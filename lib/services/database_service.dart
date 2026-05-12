import 'package:firebase_database/firebase_database.dart';
import '../models/app_models.dart';

// Seed verisi — Firebase boşsa eklenir (web-app ile aynı yapı)
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
    'water': 80, 'maxWater': 100, 'personnel': 4, 'speed': 60,
    'chief': 'Ahmet Yılmaz', 'chiefUserId': 'U002',
  },
  'T002': {
    'name': 'Ekip Beta', 'vehicleId': 'V002',
    'lat': 39.9280, 'lng': 32.8650, 'status': 'on_duty',
    'water': 45, 'maxWater': 100, 'personnel': 3, 'speed': 60,
    'chief': 'Mehmet Demir', 'chiefUserId': 'U003',
    'assignedFire': 'F001',
  },
  'T003': {
    'name': 'Ekip Gamma', 'vehicleId': 'V003',
    'lat': 39.9420, 'lng': 32.8380, 'status': 'available',
    'water': 95, 'maxWater': 100, 'personnel': 5, 'speed': 60,
    'chief': 'Ayşe Kaya', 'chiefUserId': 'U006',
  },
  'T004': {
    'name': 'Ekip Delta', 'vehicleId': 'V004',
    'lat': 39.9080, 'lng': 32.8940, 'status': 'maintenance',
    'water': 20, 'maxWater': 100, 'personnel': 2, 'speed': 60,
    'chief': 'Ali Şahin', 'chiefUserId': 'U007',
  },
};

String _nowTimeStr() {
  final now = DateTime.now();
  return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
}

class DatabaseService {
  static final _db = FirebaseDatabase.instance.ref();

  // ---- Seeding ----

  static Future<void> seedIfEmpty() async {
    final snap = await _db.child('fires').once();
    if (snap.snapshot.value == null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final e in _seedFires.entries) {
        final data = Map<String, dynamic>.from(e.value as Map);
        data['startTime'] = now - (e.key == 'F001' ? 45 * 60000 : 15 * 60000);
        await _db.child('fires/${e.key}').set(data);
      }
      for (final e in _seedTeams.entries) {
        final data = Map<String, dynamic>.from(e.value as Map);
        data['equipment'] = {'0': 'maske', '1': 'hortum', '2': 'söndürücü'};
        await _db.child('teams/${e.key}').set(data);
      }
      // T002 F001'e atanmış
      await _db.child('fires/F001/assignedTeams/T002').set(true);
      await _seedNotifications();
    }
  }

  static Future<void> _seedNotifications() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final notifs = [
      {
        'text': 'F001 yangın alanı hızla büyüyor! Rüzgar NE yönünde 25 km/s.',
        'type': 'danger', 'read': false,
        'time': _nowTimeStr(), 'id': now - 1500000,
      },
      {
        'text': 'Ekip Beta (V002) F001 yangın alanına yönlendirildi.',
        'type': 'info', 'read': false,
        'time': _nowTimeStr(), 'id': now - 1620000,
      },
      {
        'text': 'Yeni yangın bildirimi: F002 - Kentsel bölge',
        'type': 'warning', 'read': false,
        'time': _nowTimeStr(), 'id': now - 300000,
      },
      {
        'text': 'Ekip Delta bakım moduna alındı.',
        'type': 'info', 'read': true,
        'time': _nowTimeStr(), 'id': now - 3600000,
      },
    ];
    for (int i = 0; i < notifs.length; i++) {
      final id = (now - (i * 100000)).toString();
      await _db.child('notifications/$id').set(notifs[i]);
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

  static Future<void> updateFireRadius(String fireId, double radius) async {
    await _db.child('fires/$fireId').update({'radius': radius});
  }

  // Ekibin bakım modunu aç/kapat (web: chiefs can toggle maintenance)
  static Future<void> toggleTeamMaintenance(String teamId, bool inMaintenance) async {
    await _db.child('teams/$teamId').update({
      'status': inMaintenance ? 'maintenance' : 'available',
    });
    await addNotification(
      'Ekip $teamId ${inMaintenance ? "bakım moduna alındı" : "uygun duruma getirildi"}',
      'info',
    );
  }

  // Su seviyesini güncelle
  static Future<void> updateTeamWaterLevel(String teamId, int water) async {
    await _db.child('teams/$teamId').update({'water': water});
    await addNotification('Ekip $teamId su seviyesi güncellendi: $water%', 'info');
  }

  static Future<void> extinguishFire(String fireId) async {
    // Web formatıyla aynı: status=extinguished, assignedTeams={}
    await _db.child('fires/$fireId').update({
      'status': 'extinguished',
      'assignedTeams': {},
    });
    // Görevli ekipleri serbest bırak
    final snap = await _db.child('teams').once();
    if (snap.snapshot.value != null) {
      final raw = Map<Object?, Object?>.from(snap.snapshot.value as Map);
      for (final entry in raw.entries) {
        final teamData = Map<Object?, Object?>.from(entry.value as Map);
        if (teamData['assignedFire']?.toString() == fireId) {
          await _db.child('teams/${entry.key}').update({
            'assignedFire': null,
            'status': 'available',
          });
        }
      }
    }
    await addNotification('Yangın söndürüldü: $fireId', 'info');
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

  static Future<void> updateTeamWater(String teamId, int water) async {
    await _db.child('teams/$teamId').update({'water': water});
  }

  static Future<void> updateTeamEquipment(String teamId, int water, int personnel, List<String> equipment) async {
    await _db.child('teams/$teamId').update({
      'water': water,
      'personnel': personnel,
      'equipment': {for (int i = 0; i < equipment.length; i++) i.toString(): equipment[i]},
    });
    await addNotification('Ekip ekipman bilgisi güncellendi ($teamId)', 'info');
  }

  // Web formatıyla uyumlu atama:
  // teams/{teamId}/assignedFire = fireId
  // teams/{teamId}/status = 'on_route'
  // fires/{fireId}/assignedTeams/{teamId} = true  ← KEY=teamId, VALUE=true
  static Future<void> assignTeamToFire(String teamId, String fireId) async {
    await _db.child('teams/$teamId').update({
      'assignedFire': fireId,
      'status': 'on_route',
    });
    await _db.child('fires/$fireId/assignedTeams/$teamId').set(true);
    await addNotification('Ekip $teamId yangına atandı ($fireId)', 'info');
  }

  static Future<void> unassignTeamFromFire(String teamId, String fireId) async {
    await _db.child('teams/$teamId').update({
      'assignedFire': null,
      'status': 'available',
    });
    await _db.child('fires/$fireId/assignedTeams/$teamId').remove();
    await addNotification('Ekip $teamId yangından ayrıldı ($fireId)', 'info');
  }

  // ── Ekip üyesi bireysel tamamlama (web: taskCompletions/{teamId}/{userId})
  //
  // Ekip rolündeki kullanıcı tıklar → kendi tamamlaması kaydedilir.
  // Ekipteki TÜM üyeler tamamlayınca → ekip assignedTeams'den çıkar.
  // TÜM atanmış ekipler çıkınca → yangın söner.
  //
  // userId == null ise şef adına doğrudan tamamlama (bireysel takip yok).
  static Future<void> completeTask(
    String teamId,
    String? fireId, {
    String? userId,
  }) async {
    if (fireId == null) {
      // Yangın zaten yok — ekibi sadece serbest bırak
      await _db.child('teams/$teamId').update({'assignedFire': null, 'status': 'available'});
      await addNotification('Görev tamamlandı — Ekip $teamId uygun durumda', 'info');
      return;
    }

    if (userId != null) {
      // ── Ekip üyesi tamamlaması ──────────────────────────────────
      // Bireysel tamamlamayı kaydet
      await _db.child('fires/$fireId/taskCompletions/$teamId/$userId').set(true);

      // Bu ekibin tüm aktif üyelerini bul (users'dan teamId == teamId && role == 'ekip')
      final usersSnap = await _db.child('users').once();
      final memberIds = <String>[];
      if (usersSnap.snapshot.value != null) {
        final raw = Map<Object?, Object?>.from(usersSnap.snapshot.value as Map);
        for (final e in raw.entries) {
          final d = Map<Object?, Object?>.from(e.value as Map);
          if (d['teamId']?.toString() == teamId &&
              d['role']?.toString() == 'ekip' &&
              d['active'] != false) {
            memberIds.add(e.key.toString());
          }
        }
      }

      // Tamamlanmış üyeleri say
      final compSnap = await _db.child('fires/$fireId/taskCompletions/$teamId').once();
      final completedIds = <String>{};
      if (compSnap.snapshot.value != null) {
        final raw = Map<Object?, Object?>.from(compSnap.snapshot.value as Map);
        completedIds.addAll(
          raw.entries.where((e) => e.value == true).map((e) => e.key.toString()),
        );
      }

      final remaining = memberIds.where((id) => !completedIds.contains(id)).length;

      if (remaining > 0) {
        // Hâlâ tamamlamamış üye var
        await addNotification(
          'Ekip $teamId: ${completedIds.length}/${memberIds.length} üye görevi bitirdi',
          'info',
        );
        return; // henüz ekip bitmedi
      }
      // Ekibin tüm üyeleri tamamladı → devam et
    }

    // ── Ekip tamamlandı — assignedTeams'den çıkar ──────────────────
    await _db.child('teams/$teamId').update({'assignedFire': null, 'status': 'available'});
    await _db.child('fires/$fireId/assignedTeams/$teamId').remove();
    // taskCompletions bu ekip için temizle
    await _db.child('fires/$fireId/taskCompletions/$teamId').remove();

    // Tüm ekipler bitti mi?
    final assignedSnap = await _db.child('fires/$fireId/assignedTeams').once();
    final noTeamsLeft = assignedSnap.snapshot.value == null ||
        (assignedSnap.snapshot.value is Map &&
            (assignedSnap.snapshot.value as Map).isEmpty);

    if (noTeamsLeft) {
      await _db.child('fires/$fireId').update({'status': 'extinguished', 'assignedTeams': {}});
      await addNotification(
        '$fireId yangını söndürüldü — tüm ekipler görevi tamamladı! 🎉',
        'success',
      );
    } else {
      await addNotification('Görev tamamlandı — Ekip $teamId uygun durumda', 'info');
    }
  }

  // Ekip üyesinin tamamlama durumunu getir (gösterim için)
  static Future<bool> hasUserCompleted(String fireId, String teamId, String userId) async {
    final snap = await _db.child('fires/$fireId/taskCompletions/$teamId/$userId').once();
    return snap.snapshot.value == true;
  }

  // Ekipteki kaç kişi tamamladı / toplam kaç kişi var
  static Future<({int completed, int total})> teamCompletionStatus(
      String fireId, String teamId) async {
    final usersSnap = await _db.child('users').once();
    int total = 0;
    if (usersSnap.snapshot.value != null) {
      final raw = Map<Object?, Object?>.from(usersSnap.snapshot.value as Map);
      total = raw.entries.where((e) {
        final d = Map<Object?, Object?>.from(e.value as Map);
        return d['teamId']?.toString() == teamId &&
            d['role']?.toString() == 'ekip' &&
            d['active'] != false;
      }).length;
    }
    final compSnap = await _db.child('fires/$fireId/taskCompletions/$teamId').once();
    int completed = 0;
    if (compSnap.snapshot.value != null) {
      final raw = Map<Object?, Object?>.from(compSnap.snapshot.value as Map);
      completed = raw.values.where((v) => v == true).length;
    }
    return (completed: completed, total: total);
  }

  // Sönen yangınlar akışı (son 20 tane, yeniden eskiye)
  static Stream<List<Fire>> extinguishedFiresStream() {
    return _db.child('fires').onValue.map((event) {
      if (event.snapshot.value == null) return [];
      final raw = Map<Object?, Object?>.from(event.snapshot.value as Map);
      final list = raw.entries
          .map((e) => Fire.fromJson(
              e.key.toString(), Map<Object?, Object?>.from(e.value as Map)))
          .where((f) => f.status == 'extinguished')
          .toList();
      list.sort((a, b) => b.startTime.compareTo(a.startTime));
      return list.take(20).toList();
    });
  }

  // ---- Notifications ----

  // Web formatıyla aynı: key=timestamp, time='HH:MM' string
  static Stream<List<AppNotification>> notificationsStream() {
    return _db.child('notifications').onValue.map((event) {
      if (event.snapshot.value == null) return [];
      final raw = Map<Object?, Object?>.from(event.snapshot.value as Map);
      final list = raw.entries.map((e) {
        return AppNotification.fromJson(e.key.toString(), Map<Object?, Object?>.from(e.value as Map));
      }).toList();
      // Key timestamp olduğu için büyükten küçüğe sırala
      list.sort((a, b) {
        final aTs = int.tryParse(a.id) ?? 0;
        final bTs = int.tryParse(b.id) ?? 0;
        if (aTs != 0 && bTs != 0) return bTs.compareTo(aTs);
        return b.time.compareTo(a.time);
      });
      return list;
    });
  }

  static Future<void> addNotification(String text, String type) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    await _db.child('notifications/$ts').set({
      'id': ts,
      'text': text,
      'type': type,
      'time': _nowTimeStr(), // web formatı: 'HH:MM'
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

  // ---- Optimal Assignment (arka plan için, kullanıcı arayüzünde şef yalnızca kendi ekibini atar) ----

  static Map<String, String> calculateOptimalAssignment(List<Fire> fires, List<Team> teams) {
    final available = List<Team>.from(teams.where((t) => t.status == 'available'));
    final unassigned = fires.where((f) => f.assignedTeams.isEmpty).toList()
      ..sort((a, b) {
        const order = {'high': 0, 'medium': 1, 'low': 2};
        return (order[a.intensity] ?? 2).compareTo(order[b.intensity] ?? 2);
      });

    final result = <String, String>{};
    final used = <String>{};

    for (final fire in unassigned) {
      Team? best;
      double bestScore = -1;
      for (final team in available) {
        if (used.contains(team.id)) continue;
        final dlat = fire.lat - team.lat;
        final dlng = fire.lng - team.lng;
        final distScore = 50.0 / (1.0 + (dlat * dlat + dlng * dlng) * 5000);
        final score = distScore + team.readinessScore * 0.5;
        if (score > bestScore) {
          bestScore = score;
          best = team;
        }
      }
      if (best != null) {
        result[fire.id] = best.id;
        used.add(best.id);
      }
    }
    return result;
  }
}

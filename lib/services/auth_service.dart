import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/app_models.dart';

// Seed users – Firebase DB'de yoksa eklenir
const _seedUsers = [
  {'id': 'U001', 'name': 'Merkez Komutanı', 'role': 'merkez', 'username': 'admin', 'password': '1234', 'email': 'admin@firecoord.tr', 'teamId': ''},
  {'id': 'U002', 'name': 'Ahmet Yılmaz', 'role': 'sef', 'username': 'ahmet', 'password': '1234', 'email': 'ahmet@firecoord.tr', 'teamId': 'T001'},
  {'id': 'U003', 'name': 'Mehmet Demir', 'role': 'sef', 'username': 'mehmet', 'password': '1234', 'email': 'mehmet@firecoord.tr', 'teamId': 'T002'},
  {'id': 'U004', 'name': 'Ekip Üyesi 1', 'role': 'ekip', 'username': 'ekip1', 'password': '1234', 'email': 'ekip1@firecoord.tr', 'teamId': 'T001'},
  {'id': 'U005', 'name': 'Ekip Üyesi 2', 'role': 'ekip', 'username': 'ekip2', 'password': '1234', 'email': 'ekip2@firecoord.tr', 'teamId': 'T003'},
];

class AuthService {
  static AppUser? _currentUser;
  static AppUser? get currentUser => _currentUser;

  static final _db = FirebaseDatabase.instance.ref();

  static Future<void> seedUsersIfEmpty() async {
    final snap = await _db.child('users').once();
    if (snap.snapshot.value == null) {
      for (final u in _seedUsers) {
        await _db.child('users/${u['id']}').set({...u});
      }
    }
  }

  static Future<AppUser?> login(String username, String password) async {
    try {
      await seedUsersIfEmpty();
      final snap = await _db.child('users').once();
      if (snap.snapshot.value == null) return null;

      final raw = Map<Object?, Object?>.from(snap.snapshot.value as Map);
      for (final entry in raw.entries) {
        final data = Map<Object?, Object?>.from(entry.value as Map);
        if (data['username']?.toString() == username &&
            data['password']?.toString() == password) {
          final user = AppUser.fromJson(entry.key.toString(), data);
          _currentUser = user;
          // Persist session
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('fc_user', jsonEncode({
            'id': user.id,
            'name': user.name,
            'role': user.role,
            'username': user.username,
            'email': user.email,
            'teamId': user.teamId,
          }));
          return user;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<AppUser?> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('fc_user');
      if (raw == null) return null;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final user = AppUser(
        id: data['id'] ?? '',
        name: data['name'] ?? '',
        role: data['role'] ?? 'ekip',
        username: data['username'] ?? '',
        email: data['email'] ?? '',
        teamId: data['teamId'] ?? '',
      );
      _currentUser = user;
      return user;
    } catch (_) {
      return null;
    }
  }

  static Future<void> logout() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('fc_user');
  }
}

import '../models/app_models.dart';

/// Rol tabanlı yetki sistemi
/// Mobil uygulama: sadece sef ve ekip rolleri desteklenir.
/// Merkez operatörleri web uygulamasını kullanmalıdır.
class RoleBasedController {
  const RoleBasedController._();

  // ─── Yangın yetkileri ───────────────────────────────────────
  static bool canAssignTeam(AppUser? u) => u?.isSef == true;
  static bool canExtinguishFire(AppUser? u) => u?.isSef == true;

  // ─── Ekip yetkileri ─────────────────────────────────────────
  static bool canEditTeam(AppUser? u, String teamId) =>
      u?.isSef == true || u?.teamId == teamId;
  static bool canCompleteTask(AppUser? u, String teamId) =>
      u?.isSef == true || u?.teamId == teamId;

  // ─── Navigasyon yapısı ───────────────────────────────────────
  static List<AppTab> getTabs(AppUser? u) {
    if (u == null) return [];
    if (u.isSef) return sefTabs;
    if (u.isEkip) return ekipTabs;
    return []; // merkez mobilde desteklenmez
  }

  // Şef sekmeleri: Harita, Yangınlar, Ekibim, Rota, Bildirimler
  static const sefTabs = [
    AppTab.map,
    AppTab.fires,
    AppTab.teams,
    AppTab.route,
    AppTab.notifications,
  ];

  // Ekip üyesi sekmeleri: Görevim, Harita, Bildirimler
  static const ekipTabs = [
    AppTab.myTask,
    AppTab.map,
    AppTab.notifications,
  ];

  static String roleTitle(String role) {
    switch (role) {
      case 'sef':    return 'İtfaiye Şefi';
      case 'ekip':   return 'Ekip Üyesi';
      default:       return role;
    }
  }

  static String roleIcon(String role) {
    switch (role) {
      case 'sef':  return '👨‍🚒';
      default:     return '🧑‍🚒';
    }
  }
}

enum AppTab { myTask, map, fires, teams, route, notifications }

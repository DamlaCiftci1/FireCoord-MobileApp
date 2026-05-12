import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../models/app_models.dart';
import '../services/database_service.dart';
import '../utils/app_theme.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (_, provider, __) {
        final notifs = provider.notifications;
        if (notifs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('🔔', style: TextStyle(fontSize: 48)),
                SizedBox(height: 12),
                Text('Bildirim yok', style: TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          );
        }

        final unread = notifs.where((n) => !n.read).length;

        return Column(
          children: [
            if (unread > 0)
              Container(
                color: AppColors.surface,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Text('$unread okunmamış bildirim',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () async => await DatabaseService.markAllRead(),
                      child: const Text('Tümünü Okundu İşaretle',
                          style: TextStyle(color: AppColors.info, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView.separated(
                itemCount: notifs.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border, indent: 16, endIndent: 16),
                itemBuilder: (_, i) => _NotifTile(notif: notifs[i]),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _NotifTile extends StatelessWidget {
  final AppNotification notif;
  const _NotifTile({required this.notif});

  String _icon() {
    switch (notif.type) {
      case 'danger': return '🚨';
      case 'warning': return '⚠️';
      case 'success': return '✅';
      default: return 'ℹ️';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = notifTypeColor(notif.type);
    final timeStr = DateFormat('HH:mm').format(notif.time);

    return InkWell(
      onTap: () async {
        if (!notif.read) {
          await DatabaseService.markNotificationRead(notif.id);
        }
      },
      child: Container(
        color: notif.read ? Colors.transparent : color.withOpacity(0.04),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Center(child: Text(_icon(), style: const TextStyle(fontSize: 16))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notif.text,
                    style: TextStyle(
                      color: notif.read ? AppColors.textSecondary : AppColors.textPrimary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(timeStr, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                ],
              ),
            ),
            if (!notif.read)
              Container(
                width: 7, height: 7, margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }
}

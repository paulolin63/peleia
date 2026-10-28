import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Schedules a local reminder ~7 days after a scan to drive the 2nd analysis.
class EvolutionReminderService {
  EvolutionReminderService._();
  static final EvolutionReminderService instance = EvolutionReminderService._();

  static const _channelId = 'peleia_evolution';
  static const _notifId = 7007;

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> initialize() async {
    if (kIsWeb || _ready) return;
    try {
      tzdata.initializeTimeZones();
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      try {
        tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));
      } catch (_) {
        tz.setLocalLocation(tz.UTC);
      }
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
    );
    _ready = true;
  }

  Future<bool> _ensurePermission() async {
    if (kIsWeb) return false;
    if (defaultTargetPlatform == TargetPlatform.android) {
      final status = await Permission.notification.request();
      return status.isGranted || status.isLimited;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      return await ios?.requestPermissions(alert: true, badge: true, sound: true) ?? false;
    }
    return false;
  }

  /// Call after a successful analysis. Reschedules to +7 days from now.
  Future<void> scheduleAfterScan({Duration delay = const Duration(days: 7)}) async {
    if (kIsWeb) return;
    await initialize();
    final ok = await _ensurePermission();
    if (!ok) {
      debugPrint('Evolution reminder: notification permission denied');
      return;
    }

    await _plugin.cancel(id: _notifId);
    final when = tz.TZDateTime.now(tz.local).add(delay);
    var scheduled = tz.TZDateTime(tz.local, when.year, when.month, when.day, 10, 0);
    if (scheduled.isBefore(tz.TZDateTime.now(tz.local))) {
      scheduled = tz.TZDateTime.now(tz.local).add(const Duration(minutes: 2));
    }

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      'Evolucao da pele',
      channelDescription: 'Lembrete para comparar sua analise em 7 dias',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _plugin.zonedSchedule(
      id: _notifId,
      scheduledDate: scheduled,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: 'Sua pele mudou em 1 semana?',
      body: 'Tire a selfie de evolucao e compare oleosidade, acne e manchas.',
    );
    debugPrint('Evolution reminder scheduled for $scheduled');
  }

  Future<void> cancel() async {
    if (kIsWeb) return;
    await initialize();
    await _plugin.cancel(id: _notifId);
  }
}

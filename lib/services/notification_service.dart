import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../data/models/alert.dart';
import '../data/models/region.dart';

/// Notificações locais para alertas críticos (Android/iOS). No web é no-op.
///
/// A notificação apenas *avisa* o gestor que há um alerta para analisar;
/// ela não dispara nenhuma ação no território.
class NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> init() async {
    if (!supported || _ready) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      _ready = true;
    } catch (e) {
      debugPrint('Notificações indisponíveis: $e');
    }
  }

  /// Pede permissão (Android 13+/iOS). Chamado quando o usuário ativa a opção.
  Future<bool> requestPermission() async {
    await init();
    if (!_ready) return false;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) return await android.requestNotificationsPermission() ?? false;
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(alert: true, sound: true) ?? false;
    }
    return false;
  }

  Future<void> showCritical(TerritoryAlert alert) async {
    if (!_ready) return;
    final region = Territory.byId(alert.regionId).name;
    await _plugin.show(
      id: alert.id.hashCode & 0x7fffffff,
      title: 'Alerta crítico · $region',
      body: '${alert.title}. Toque no app para analisar — a decisão é sua.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'critical_alerts',
          'Alertas críticos',
          channelDescription: 'Alertas preditivos críticos que aguardam análise humana.',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: alert.id,
    );
  }
}

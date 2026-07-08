import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

/// 通知栏常驻服务：实时显示温湿度
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const int _ongoingId = 1001;
  static const String _channelId = 'champ_env_ongoing';
  static const String _channelName = '环境监测（常驻）';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  StreamSubscription<EnvData>? _sub;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: '常驻通知栏显示当前温湿度',
            importance: Importance.low,
            showBadge: false,
          ),
        );
    _initialized = true;
  }

  /// 绑定温湿度流，收到新数据就刷新通知栏
  void bindEnvStream(Stream<EnvData> envStream) {
    _sub?.cancel();
    _sub = envStream.asyncMap((d) async {
      await _showOngoing(d);
    }).listen((_) {});
  }

  Future<void> _showOngoing(EnvData d) async {
    if (!_initialized) await init();
    await _plugin.show(
      _ongoingId,
      'Champ 环境监测',
      '温度 ${d.temperature.toStringAsFixed(1)}°C  湿度 ${d.humidity.toStringAsFixed(0)}%  体感 ${d.heatIndex.toStringAsFixed(1)}°C',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: '常驻通知栏显示当前温湿度',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          autoCancel: false,
          showWhen: false,
          styleInformation: const DefaultStyleInformation(false, false),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: false,
          presentBadge: false,
        ),
      ),
    );
  }

  Future<void> cancel() async {
    _sub?.cancel();
    _sub = null;
    await _plugin.cancel(_ongoingId);
  }

  Future<bool> isOngoingEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notif_ongoing') ?? true;
  }

  Future<void> setOngoingEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_ongoing', enabled);
    if (!enabled) await cancel();
  }
}

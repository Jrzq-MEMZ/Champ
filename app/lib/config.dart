/// Champ App 全局配置
/// 把这里的值改成你部署后的实际参数

class AppConfig {
  // VPS 域名
  static const String domain = 'cheeoo.lol';

  // MQTT over WebSocket（经 Nginx TLS 反代）
  static const String mqttHost = domain;
  static const int mqttPort = 443;
  static const String mqttPath = '/mqtt';
  static const String mqttUser = 'app';
  static const String mqttPass = 'SDHKsagmTRQcg99kfb4s';
  static const bool mqttSecure = true; // wss

  // REST API
  static const String apiBase = 'https://$domain/api';
  static const String apiToken = '3cGxkyPLLH7xnm9hYSm4igxArHCnhJiS';

  // 默认设备
  static const String defaultDeviceId = 'esp32cam-01';
}

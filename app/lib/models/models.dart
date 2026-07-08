class EnvData {
  final double temperature;
  final double humidity;
  final double heatIndex;
  final int ts;

  EnvData({
    required this.temperature,
    required this.humidity,
    required this.heatIndex,
    required this.ts,
  });

  factory EnvData.fromJson(Map<String, dynamic> j) => EnvData(
        temperature: (j['temperature'] as num?)?.toDouble() ?? 0,
        humidity: (j['humidity'] as num?)?.toDouble() ?? 0,
        heatIndex: (j['heatIndex'] as num?)?.toDouble() ?? 0,
        ts: (j['ts'] as num?)?.toInt() ?? 0,
      );

  DateTime get time =>
      DateTime.fromMillisecondsSinceEpoch(ts * 1000);
}

class DeviceStatus {
  final String deviceId;
  final String state;
  final String ip;
  final int rssi;
  final int uptime;
  final int freeHeap;
  final double fps;
  final int lastSeen;

  DeviceStatus({
    required this.deviceId,
    required this.state,
    required this.ip,
    required this.rssi,
    required this.uptime,
    required this.freeHeap,
    required this.fps,
    required this.lastSeen,
  });

  factory DeviceStatus.fromJson(Map<String, dynamic> j) => DeviceStatus(
        deviceId: j['deviceId'] as String? ?? '',
        state: j['state'] as String? ?? 'unknown',
        ip: j['ip'] as String? ?? '',
        rssi: (j['rssi'] as num?)?.toInt() ?? 0,
        uptime: (j['uptime'] as num?)?.toInt() ?? 0,
        freeHeap: (j['freeHeap'] as num?)?.toInt() ?? 0,
        fps: (j['fps'] as num?)?.toDouble() ?? 0,
        lastSeen: (j['lastSeen'] as num?)?.toInt() ??
            (j['ts'] as num?)?.toInt() ??
            0,
      );
}

class EnvHistoryPoint {
  final double temperature;
  final double humidity;
  final double heatIndex;
  final int ts;

  EnvHistoryPoint({
    required this.temperature,
    required this.humidity,
    required this.heatIndex,
    required this.ts,
  });

  factory EnvHistoryPoint.fromJson(Map<String, dynamic> j) =>
      EnvHistoryPoint(
        temperature: (j['temperature'] as num).toDouble(),
        humidity: (j['humidity'] as num).toDouble(),
        heatIndex: (j['heatIndex'] as num?)?.toDouble() ?? 0,
        ts: (j['ts'] as num).toInt(),
      );
}

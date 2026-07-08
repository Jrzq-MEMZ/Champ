import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:mqtt_client/mqtt_client.dart' show MqttConnectionState;
import '../config.dart' show AppConfig;
import '../models/models.dart';
import '../services/mqtt_service.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum _ConnLabel { disconnected, connecting, connected, reconnecting }

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final MqttService _mqtt = MqttService();
  final ApiService _api = ApiService();
  final NotificationService _notif = NotificationService();

  Uint8List? _latestFrame;
  EnvData? _latestEnv;
  DeviceStatus? _status;
  _ConnLabel _conn = _ConnLabel.disconnected;
  List<EnvHistoryPoint> _history = [];
  int _historyHours = 24;
  bool _notifEnabled = true;
  Timer? _historyTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initAll();
  }

  Future<void> _initAll() async {
    _notifEnabled = await _notif.isOngoingEnabled();
    _mqtt.frameStream.listen((f) {
      if (mounted) setState(() => _latestFrame = f);
    });
    _mqtt.envStream.listen((e) {
      if (mounted) setState(() => _latestEnv = e);
    });
    _mqtt.statusStream.listen((s) {
      if (mounted) setState(() => _status = s);
    });
    _mqtt.connectionStateStream.listen((s) {
      if (!mounted) return;
      setState(() {
        switch (s) {
          case MqttConnectionState.connected:
            _conn = _ConnLabel.connected;
            break;
          case MqttConnectionState.connecting:
            // autoReconnect 也走 connecting 状态，用上一次状态区分显示
            _conn = _conn == _ConnLabel.connected
                ? _ConnLabel.reconnecting
                : _ConnLabel.connecting;
            break;
          default:
            _conn = _ConnLabel.disconnected;
        }
      });
    });

    await _mqtt.connect();
    if (_notifEnabled) _notif.bindEnvStream(_mqtt.envStream);

    await _refreshHistory();
    _historyTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _refreshHistory(),
    );
  }

  Future<void> _refreshHistory() async {
    try {
      final list = await _api.getEnvHistory(hours: _historyHours);
      if (mounted) setState(() => _history = list);
    } catch (e) {
      print('[API] history fail: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshHistory();
    }
  }

  @override
  void dispose() {
    _historyTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _mqtt.dispose();
    super.dispose();
  }

  String get _connText {
    switch (_conn) {
      case _ConnLabel.connected:
        return '已连接';
      case _ConnLabel.connecting:
        return '连接中...';
      case _ConnLabel.reconnecting:
        return '重连中...';
      case _ConnLabel.disconnected:
        return '未连接';
    }
  }

  Color get _connColor {
    switch (_conn) {
      case _ConnLabel.connected:
        return Colors.green;
      case _ConnLabel.connecting:
      case _ConnLabel.reconnecting:
        return Colors.orange;
      case _ConnLabel.disconnected:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Champ 监测'),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _connColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _connColor.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 8, color: _connColor),
                    const SizedBox(width: 6),
                    Text(_connText,
                        style: TextStyle(color: _connColor, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
              final enabled = await _notif.isOngoingEnabled();
              if (mounted) {
                setState(() => _notifEnabled = enabled);
                if (enabled) {
                  _notif.bindEnvStream(_mqtt.envStream);
                } else {
                  _notif.cancel();
                }
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshHistory,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _buildVideoCard(),
            const SizedBox(height: 12),
            _buildEnvCard(),
            const SizedBox(height: 12),
            _buildDeviceCard(),
            const SizedBox(height: 12),
            _buildHistoryCard(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.videocam, size: 18),
                const SizedBox(width: 6),
                const Text('实时视频',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const Spacer(),
                if (_status != null)
                  Text('${_status!.fps.toStringAsFixed(1)} fps',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 8),
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Container(
                color: Colors.black,
                child: _latestFrame == null
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: Colors.white54),
                      )
                    : Image.memory(
                        _latestFrame!,
                        gaplessPlayback: true,
                        fit: BoxFit.contain,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnvCard() {
    final env = _latestEnv;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.thermostat, size: 18),
                const SizedBox(width: 6),
                const Text('当前环境',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const Spacer(),
                if (env != null)
                  Text(
                    _fmtTime(env.time),
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _buildEnvMetric(
                    icon: Icons.device_thermostat,
                    label: '温度',
                    value: env == null ? '--' : env.temperature.toStringAsFixed(1),
                    unit: '°C',
                    color: Colors.deepOrange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildEnvMetric(
                    icon: Icons.water_drop,
                    label: '湿度',
                    value: env == null ? '--' : env.humidity.toStringAsFixed(0),
                    unit: '%',
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildEnvMetric(
                    icon: Icons.ac_unit,
                    label: '体感',
                    value: env == null ? '--' : env.heatIndex.toStringAsFixed(1),
                    unit: '°C',
                    color: Colors.purple,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnvMetric({
    required IconData icon,
    required String label,
    required String value,
    required String unit,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(width: 2),
            Text(unit, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ],
    );
  }

  Widget _buildDeviceCard() {
    final s = _status;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.router, size: 18),
                const SizedBox(width: 6),
                const Text('设备状态',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const Spacer(),
                if (s != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: s.state == 'online'
                          ? Colors.green.withOpacity(0.15)
                          : Colors.grey.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      s.state == 'online' ? '在线' : '离线',
                      style: TextStyle(
                        fontSize: 11,
                        color: s.state == 'online' ? Colors.green : Colors.grey,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            _buildInfoRow('设备 ID', s?.deviceId ?? AppConfig.defaultDeviceId),
            _buildInfoRow('IP 地址', s?.ip ?? '--'),
            _buildInfoRow('信号强度', s == null ? '--' : '${s.rssi} dBm'),
            _buildInfoRow('运行时长', s == null ? '--' : _fmtUptime(s.uptime)),
            _buildInfoRow('剩余内存', s == null ? '--' : '${(s.freeHeap / 1024).toStringAsFixed(1)} KB'),
            _buildInfoRow('帧率', s == null ? '--' : '${s.fps.toStringAsFixed(1)} fps'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.show_chart, size: 18),
                const SizedBox(width: 6),
                const Text('历史曲线',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const Spacer(),
                _buildHoursSelector(),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: _history.isEmpty
                  ? const Center(
                      child: Text('暂无历史数据',
                          style: TextStyle(color: Colors.grey)),
                    )
                  : _buildChart(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHoursSelector() {
    return DropdownButton<int>(
      value: _historyHours,
      underline: const SizedBox(),
      isDense: true,
      style: const TextStyle(fontSize: 12, color: Colors.black87),
      items: const [
        DropdownMenuItem(value: 1, child: Text('1小时')),
        DropdownMenuItem(value: 6, child: Text('6小时')),
        DropdownMenuItem(value: 24, child: Text('24小时')),
        DropdownMenuItem(value: 168, child: Text('7天')),
      ],
      onChanged: (v) {
        if (v == null) return;
        setState(() => _historyHours = v);
        _refreshHistory();
      },
    );
  }

  Widget _buildChart() {
    final tempPoints = <FlSpot>[];
    final humPoints = <FlSpot>[];
    double minX = double.infinity, maxX = -double.infinity;
    double minTemp = double.infinity, maxTemp = -double.infinity;
    double minHum = double.infinity, maxHum = -double.infinity;

    for (final p in _history) {
      final x = p.ts.toDouble();
      tempPoints.add(FlSpot(x, p.temperature));
      humPoints.add(FlSpot(x, p.humidity));
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (p.temperature < minTemp) minTemp = p.temperature;
      if (p.temperature > maxTemp) maxTemp = p.temperature;
      if (p.humidity < minHum) minHum = p.humidity;
      if (p.humidity > maxHum) maxHum = p.humidity;
    }
    if (tempPoints.isEmpty) {
      return const Center(child: Text('暂无数据'));
    }

    final tempPad = ((maxTemp - minTemp).clamp(1.0, 10.0)) * 0.2;
    final humPad = ((maxHum - minHum).clamp(1.0, 10.0)) * 0.2;
    final tempMinY = (minTemp - tempPad).clamp(0.0, 100.0);
    final tempMaxY = maxTemp + tempPad;
    // humMinY/humMaxY 当前图表只画温度曲线，保留以备扩展
    // final humMinY = (minHum - humPad).clamp(0.0, 100.0);
    // final humMaxY = (maxHum + humPad).clamp(0.0, 100.0);

    return LineChart(
      LineChartData(
        gridData: const FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: null,
        ),
        titlesData: const FlTitlesData(
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              interval: null,
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: minX,
        maxX: maxX,
        minY: tempMinY,
        maxY: tempMaxY,
        lineBarsData: [
          LineChartBarData(
            spots: tempPoints,
            isCurved: true,
            color: Colors.deepOrange,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.deepOrange.withOpacity(0.1),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) {
              return spots.map((s) {
                return LineTooltipItem(
                  '${s.y.toStringAsFixed(1)}°C\n${_fmtTime(DateTime.fromMillisecondsSinceEpoch(s.x.toInt() * 1000))}',
                  const TextStyle(color: Colors.white, fontSize: 11),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  String _fmtTime(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
  }

  String _fmtUptime(int sec) {
    if (sec < 60) return '${sec}s';
    if (sec < 3600) return '${sec ~/ 60}m ${sec % 60}s';
    if (sec < 86400) return '${sec ~/ 3600}h ${(sec % 3600) ~/ 60}m';
    return '${sec ~/ 86400}d ${(sec % 86400) ~/ 3600}h';
  }
}

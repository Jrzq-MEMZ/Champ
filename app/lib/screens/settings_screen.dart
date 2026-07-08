import 'package:flutter/material.dart';
import '../services/mqtt_service.dart';
import '../services/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final NotificationService _notif = NotificationService();
  bool _notifEnabled = true;

  // 视频参数
  int _framesize = 5; // 5=VGA
  int _fps = 5;
  int _quality = 12;

  final Map<int, String> _framesizeNames = {
    0: 'QVGA 320x240',
    4: 'CIF 400x296',
    5: 'VGA 640x480',
    6: 'SVGA 800x600',
    7: 'HD 1024x768',
  };

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final enabled = await _notif.isOngoingEnabled();
    if (mounted) setState(() => _notifEnabled = enabled);
  }

  void _sendCmd() {
    final mqtt = MqttService();
    mqtt.connect().then((ok) {
      if (ok) {
        mqtt.publishCmd(
          framesize: _framesize,
          fps: _fps,
          quality: _quality,
        );
        Future.delayed(const Duration(milliseconds: 300), () {
          mqtt.disconnect();
          mqtt.dispose();
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('参数已下发')),
          );
        }
      } else {
        mqtt.dispose();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('下发失败：MQTT 未连接')),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection('通知', [
            SwitchListTile(
              title: const Text('通知栏常驻温湿度'),
              subtitle: const Text('在手机通知栏实时显示当前温湿度'),
              value: _notifEnabled,
              onChanged: (v) async {
                await _notif.setOngoingEnabled(v);
                setState(() => _notifEnabled = v);
                if (!v) await _notif.cancel();
              },
            ),
          ]),
          const SizedBox(height: 16),
          _buildSection('摄像头参数', [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Text('分辨率'),
                  const Spacer(),
                  DropdownButton<int>(
                    value: _framesize,
                    items: _framesizeNames.entries
                        .map((e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value, style: const TextStyle(fontSize: 13)),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _framesize = v);
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  const Text('帧率'),
                  Expanded(
                    child: Slider(
                      value: _fps.toDouble(),
                      min: 1,
                      max: 15,
                      divisions: 14,
                      label: '$_fps fps',
                      onChanged: (v) => setState(() => _fps = v.round()),
                    ),
                  ),
                  SizedBox(
                    width: 50,
                    child: Text('$_fps fps',
                        style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  const Text('画质'),
                  Expanded(
                    child: Slider(
                      value: _quality.toDouble(),
                      min: 4,
                      max: 31,
                      divisions: 27,
                      label: 'Q$_quality',
                      onChanged: (v) => setState(() => _quality = v.round()),
                    ),
                  ),
                  SizedBox(
                    width: 50,
                    child: Text('Q$_quality',
                        style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                '提示：OV3660 无散热片时建议 VGA+5fps+Q12，避免过热死机。\n画质数值越小越清晰越烫，越大越模糊越凉。',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: FilledButton.icon(
                onPressed: _sendCmd,
                icon: const Icon(Icons.send),
                label: const Text('下发参数到设备'),
              ),
            ),
          ]),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(title,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey)),
          ),
          ...children,
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

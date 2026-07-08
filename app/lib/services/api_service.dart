import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/models.dart';

/// REST API 客户端：查历史温湿度、设备列表、快照
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  Map<String, String> get _headers => {
        'Authorization': 'Bearer ${AppConfig.apiToken}',
        'Content-Type': 'application/json',
      };

  Future<List<EnvHistoryPoint>> getEnvHistory({
    String? deviceId,
    int hours = 24,
  }) async {
    final id = deviceId ?? AppConfig.defaultDeviceId;
    final url = Uri.parse(
      '${AppConfig.apiBase}/env/history?deviceId=$id&hours=$hours',
    );
    final resp = await http.get(url, headers: _headers).timeout(
          const Duration(seconds: 10),
        );
    if (resp.statusCode != 200) {
      throw Exception('history ${resp.statusCode}: ${resp.body}');
    }
    final j = jsonDecode(resp.body) as Map<String, dynamic>;
    final list = j['points'] as List;
    return list
        .map((e) => EnvHistoryPoint.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<EnvData?> getLatestEnv({String? deviceId}) async {
    final id = deviceId ?? AppConfig.defaultDeviceId;
    final url = Uri.parse('${AppConfig.apiBase}/env/latest?deviceId=$id');
    final resp = await http.get(url, headers: _headers).timeout(
          const Duration(seconds: 10),
        );
    if (resp.statusCode != 200) return null;
    return EnvData.fromJson(jsonDecode(resp.body));
  }

  Future<List<DeviceStatus>> getDevices() async {
    final url = Uri.parse('${AppConfig.apiBase}/devices');
    final resp = await http.get(url, headers: _headers).timeout(
          const Duration(seconds: 10),
        );
    if (resp.statusCode != 200) {
      throw Exception('devices ${resp.statusCode}');
    }
    final j = jsonDecode(resp.body) as Map<String, dynamic>;
    final list = j['devices'] as List;
    return list
        .map((e) => DeviceStatus.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Uint8List?> getSnapshot(String deviceId) async {
    final url = Uri.parse('${AppConfig.apiBase}/snapshot/$deviceId');
    final resp = await http.get(url, headers: _headers).timeout(
          const Duration(seconds: 10),
        );
    if (resp.statusCode != 200) return null;
    return resp.bodyBytes;
  }
}

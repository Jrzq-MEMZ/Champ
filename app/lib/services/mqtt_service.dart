import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../config.dart';
import '../models/models.dart';

/// MQTT 订阅服务：连接 VPS 的 WSS，订阅 cam/{id}/frame 和 cam/{id}/env
class MqttService {
  late final MqttServerClient _client;
  final String deviceId;

  // 视频帧流
  final _frameController = StreamController<Uint8List>.broadcast();
  Stream<Uint8List> get frameStream => _frameController.stream;

  // 温湿度流
  final _envController = StreamController<EnvData>.broadcast();
  Stream<EnvData> get envStream => _envController.stream;

  // 状态流
  final _statusController = StreamController<DeviceStatus>.broadcast();
  Stream<DeviceStatus> get statusStream => _statusController.stream;

  // 连接状态
  final _connController = StreamController<MqttConnectionState>.broadcast();
  Stream<MqttConnectionState> get connectionStateStream =>
      _connController.stream;

  MqttService({String? deviceId})
      : deviceId = deviceId ?? AppConfig.defaultDeviceId {
    final uri = AppConfig.mqttSecure ? 'wss' : 'ws';
    _client = MqttServerClient.withPort(
      '$uri://${AppConfig.mqttHost}:${AppConfig.mqttPort}',
      'champ-app-${DateTime.now().millisecondsSinceEpoch}',
      AppConfig.mqttPort,
    );
    _client.useWebSocket = true;
    _client.websocketProtocols = ['mqttv3.1'];
    if (AppConfig.mqttPath.isNotEmpty) {
      _client.websocketUriString = AppConfig.mqttPath;
    }
    _client.port = AppConfig.mqttPort;
    _client.logging(on: false);
    _client.keepAlivePeriod = 30;
    _client.connectTimeoutPeriod = 8000;
    _client.autoReconnect = true;
    _client.retryAutoReconnectDelay = const Duration(seconds: 3);
    _client.onConnected = _onConnected;
    _client.onDisconnected = _onDisconnected;
    _client.onSubscribed = _onSubscribed;
    _client.onAutoReconnect = () {
      _connController.add(MqttConnectionState.reconnecting);
    };
    _client.onAutoReconnected = _onConnected;
  }

  Future<bool> connect() async {
    try {
      _connController.add(MqttConnectionState.connecting);
      final status = await _client.connect(
        AppConfig.mqttUser,
        AppConfig.mqttPass,
      );
      if (status?.state == MqttConnectionState.connected) {
        _subscribeAll();
        return true;
      }
      return false;
    } catch (e) {
      print('[MQTT] connect error: $e');
      _client.doAutoReconnect();
      return false;
    }
  }

  void _onConnected() {
    _connController.add(MqttConnectionState.connected);
    _subscribeAll();
  }

  void _onDisconnected() {
    _connController.add(MqttConnectionState.disconnected);
  }

  void _onSubscribed(String topic) {
    print('[MQTT] subscribed: $topic');
  }

  void _subscribeAll() {
    final subFrames = _client.subscribe('cam/$deviceId/frame', MqttQos.atMostOnce);
    final subEnv = _client.subscribe('cam/$deviceId/env', MqttQos.atLeastOnce);
    final subStatus =
        _client.subscribe('cam/$deviceId/status', MqttQos.atLeastOnce);
    print('[MQTT] sub frames=${subFrames?.rawRelStateType} '
        'env=${subEnv?.rawRelStateType} status=${subStatus?.rawRelStateType}');

    _client.updates?.listen((List<MqttReceivedMessage<MqttMessage>> msgs) {
      for (final m in msgs) {
        final topic = m.topic;
        final payload = m.payload as MqttPublishMessage;
        final bytes = payload.payload.message;
        if (topic.endsWith('/frame')) {
          _frameController.add(Uint8List.fromList(bytes));
        } else if (topic.endsWith('/env')) {
          try {
            final str = utf8.decode(bytes);
            final json = jsonDecode(str) as Map<String, dynamic>;
            _envController.add(EnvData.fromJson(json));
          } catch (e) {
            print('[MQTT] env parse fail: $e');
          }
        } else if (topic.endsWith('/status')) {
          try {
            final str = utf8.decode(bytes);
            final json = jsonDecode(str) as Map<String, dynamic>;
            _statusController.add(DeviceStatus.fromJson(json));
          } catch (e) {
            print('[MQTT] status parse fail: $e');
          }
        }
      }
    });
  }

  /// 下发参数调整指令
  void publishCmd({int? framesize, int? fps, int? quality}) {
    final builder = MqttClientPayloadBuilder();
    final map = <String, dynamic>{
      'ts': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    };
    if (framesize != null) map['framesize'] = framesize;
    if (fps != null) map['fps'] = fps;
    if (quality != null) map['quality'] = quality;
    builder.addString(jsonEncode(map));
    _client.publishMessage(
      'cam/$deviceId/cmd',
      MqttQos.atLeastOnce,
      builder.payload!,
    );
  }

  Future<void> disconnect() async {
    await _client.disconnect();
    _connController.add(MqttConnectionState.disconnected);
  }

  void dispose() {
    _frameController.close();
    _envController.close();
    _statusController.close();
    _connController.close();
  }
}

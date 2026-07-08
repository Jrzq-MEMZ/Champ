# Flutter App 构建指南

## 1. 环境准备

- Flutter 3.19+ (`flutter --version`)
- Android Studio 或 VS Code + Flutter 插件
- Android SDK 34
- JDK 17

```bash
flutter doctor
```

## 2. 修改配置

编辑 `app/lib/config.dart`：

```dart
class AppConfig {
  static const String domain = 'your.domain.com';   // 改成你的域名
  static const String mqttUser = 'app';
  static const String mqttPass = 'your_app_mqtt_password';
  static const String apiToken = 'your_api_token';
  static const String defaultDeviceId = 'esp32cam-01';
}
```

> 这些值来自 VPS 部署脚本输出的密码清单。

## 3. 安装依赖

```bash
cd app
flutter pub get
```

## 4. 运行（调试）

```bash
# 连接手机（打开 USB 调试）或启动模拟器
flutter devices
flutter run
```

## 5. 构建 APK

```bash
# Debug APK（快速测试）
flutter build apk --debug

# Release APK（正式，体积小）
flutter build apk --release
# 产物: build/app/outputs/flutter-apk/app-release.apk
```

## 6. 安装到手机

```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```
或者把 APK 文件拷到手机，文件管理器点击安装（需开启"未知来源应用"权限）。

## 7. Android 通知权限（Android 13+）

App 首次启动时如通知栏不显示：
- 设置 → 应用 → Champ → 通知 → 开启
- 或在 App 内 → 设置 → 开启"通知栏常驻温湿度"

代码已声明 `POST_NOTIFICATIONS` 权限，但 Android 13+ 还需运行时请求。
如遇权限问题，在 `main.dart` 加运行时请求逻辑（`permission_handler` 包）。

## 8. 功能说明

- **首页**：实时视频 + 温湿度卡片 + 设备状态 + 历史曲线（下拉刷新）
- **历史曲线**：可选 1h / 6h / 24h / 7d，每 5 分钟自动刷新
- **设置**：
  - 通知栏常驻开关
  - 摄像头参数调节（分辨率 / 帧率 / 画质）
  - 下发参数到设备（通过 MQTT cmd topic）

## 9. 常见问题

| 现象 | 解决 |
|---|---|
| 黑屏无视频 | 检查 MQTT 是否连接（右上角状态点）|
| 视频卡顿 | 网络/MQTT QoS 0 会丢帧正常；或在设置降帧率 |
| 历史曲线空 | VPS 数据库还没数据；等 DHT11 发几条 |
| WSS 连接失败 | config.dart 域名错；nginx `/mqtt` 没配；证书过期 |
| 通知栏不显示 | Android 13+ 检查 POST_NOTIFICATIONS 权限 |

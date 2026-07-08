# VPS 部署指南

## 前置条件

- Ubuntu 20.04/22.04/24.04 VPS，2GB+ 内存
- 域名已解析到 VPS 公网 IP（A 记录）
- root 或 sudo 权限
- 开放端口：80、443、8883

## 一键部署

```bash
# 1. 把项目传到 VPS
git clone <你的仓库> /opt/champ-src
# 或 scp 上传整个 Champ 目录

# 2. 执行部署脚本
cd /opt/champ-src
sudo DOMAIN=your.domain.com \
     API_TOKEN=随机长字符串 \
     ESP_MQTT_PASS=随机字符串 \
     APP_MQTT_PASS=随机字符串 \
     API_MQTT_PASS=随机字符串 \
     bash vps/deploy.sh
```

脚本会自动完成：
1. 装 mosquitto、nginx、certbot、node 20
2. 申请 Let's Encrypt 证书
3. 配置 mosquitto（TLS 8883 + WSS 9400 + ACL）
4. 配置 nginx 反代（HTTPS + WSS）
5. 部署 Node.js API（systemd 管理）
6. 设置防火墙
7. 配置证书自动续期

部署完成后脚本会打印所有密码和连接信息，**妥善保存**。

## 手动验证

### 1. Mosquitto

```bash
systemctl status mosquitto
ss -tlnp | grep -E '1883|8883|9400'

# 测试订阅（本机）
mosquitto_sub -h 127.0.0.1 -p 1883 -u api -P YOUR_API_PASS -t 'cam/#' -v

# 另一终端测试发布
mosquitto_pub -h 127.0.0.1 -p 1883 -u api -P YOUR_API_PASS -t 'cam/test/env' -m '{"temperature":25,"humidity":60}'
```

### 2. Nginx

```bash
systemctl status nginx
curl -I https://your.domain.com/api/health
# 期望: HTTP/2 401（未带 token 正常）
curl -H "Authorization: Bearer YOUR_TOKEN" https://your.domain.com/api/health
# 期望: {"ok":true,...}
```

### 3. Node.js API

```bash
systemctl status champ-api
journalctl -u champ-api -f   # 看日志

curl -H "Authorization: Bearer YOUR_TOKEN" \
     https://your.domain.com/api/devices
```

### 4. MQTT over WebSocket（App 用的）

用 [HiveMQ Web Client](https://www.hivemq.com/demos/websocket-client/)：
- Host: `your.domain.com`
- Port: `443`
- SSL: on
- Path: `/mqtt`
- Username: `app` / Password: `YOUR_APP_PASS`
- 订阅 `cam/esp32cam-01/#`

## 常用运维命令

```bash
# 重启服务
sudo systemctl restart mosquitto nginx champ-api

# 查日志
sudo journalctl -u champ-api -f --since "10 min ago"
sudo tail -f /var/log/mosquitto/mosquitto.log
sudo tail -f /var/log/nginx/champ-access.log

# 备份数据库
cp /opt/champ/data/champ.db /backup/champ-$(date +%F).db

# 清理 30 天前数据
curl -X POST -H "Authorization: Bearer YOUR_TOKEN" \
     "https://your.domain.com/api/maintenance/prune?days=30"

# 加 crontab 自动清理（每天凌晨 4 点）
(crontab -l 2>/dev/null; \
 echo "0 4 * * * curl -X POST -H 'Authorization: Bearer YOUR_TOKEN' 'https://your.domain.com/api/maintenance/prune?days=30'") \
 | crontab -
```

## 修改密码

```bash
# 改 ESP32 的 MQTT 密码
sudo mosquitto_passwd -b /etc/mosquitto/passwd esp32cam NEW_PASS
sudo systemctl restart mosquitto
# 同步改 firmware/config.h 重新烧录
```

## 故障排查

| 现象 | 排查 |
|---|---|
| 证书申请失败 | 域名 DNS 未指向 VPS / 80 端口没开 |
| ESP32 连不上 8883 | 检查 ufw allow 8883；mosquitto.conf 证书路径 |
| App 连不上 WSS | 浏览器 console 看 `wss://` 握手；nginx `/mqtt` 配置 |
| API 502 | `systemctl status champ-api` 看是否在跑 |
| 数据库锁死 | `rm /opt/champ/data/champ.db-*`（WAL 文件）后重启 |

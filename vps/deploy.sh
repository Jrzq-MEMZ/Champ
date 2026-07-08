#!/usr/bin/env bash
# Champ VPS 一键部署脚本（Ubuntu 20.04/22.04/24.04）
# 用法: sudo DOMAIN=your.domain.com API_TOKEN=your_secret bash deploy.sh
set -euo pipefail

DOMAIN="${DOMAIN:-}"
API_TOKEN="${API_TOKEN:-champ_default_token_change_me}"
ESP_MQTT_PASS="${ESP_MQTT_PASS:-esp32cam_pass_change_me}"
APP_MQTT_PASS="${APP_MQTT_PASS:-app_pass_change_me}"
API_MQTT_PASS="${API_MQTT_PASS:-api_pass_change_me}"

if [ -z "$DOMAIN" ]; then
  echo "ERROR: 请设置 DOMAIN 环境变量"
  echo "  sudo DOMAIN=your.domain.com bash deploy.sh"
  exit 1
fi

echo "==> [1/9] 安装系统依赖"
apt-get update -y
apt-get install -y mosquitto mosquitto-clients nginx certbot python3-certbot-nginx curl gnupg ufw

echo "==> [2/9] 安装 Node.js 20"
if ! command -v node >/dev/null || ! node -v | grep -q '^v20'; then
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
  apt-get install -y nodejs
fi
echo "    Node: $(node -v)  npm: $(npm -v)"

echo "==> [3/9] 防火墙"
ufw allow 22/tcp || true
ufw allow 80/tcp || true
ufw allow 443/tcp || true
ufw allow 8883/tcp || true   # MQTT/TLS 给 ESP32
ufw --force enable || true

echo "==> [4/9] 申请 Let's Encrypt 证书"
mkdir -p /var/www/letsencrypt
if [ ! -f /etc/letsencrypt/live/$DOMAIN/fullchain.pem ]; then
  # 先放临时 nginx 配置好过 ACME
  cat > /etc/nginx/sites-available/$DOMAIN.tmp <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    location /.well-known/acme-challenge/ { root /var/www/letsencrypt; }
}
EOF
  ln -sf /etc/nginx/sites-available/$DOMAIN.tmp /etc/nginx/sites-enabled/$DOMAIN.tmp
  nginx -t && systemctl reload nginx
  certbot certonly --webroot -w /var/www/letsencrypt -d $DOMAIN --non-interactive --agree-tos -m admin@$DOMAIN || true
  rm -f /etc/nginx/sites-enabled/$DOMAIN.tmp /etc/nginx/sites-available/$DOMAIN.tmp
  systemctl reload nginx
fi
if [ ! -f /etc/letsencrypt/live/$DOMAIN/fullchain.pem ]; then
  echo "ERROR: 证书申请失败，检查域名 DNS 是否指向本机"
  exit 1
fi
echo "    证书 OK: /etc/letsencrypt/live/$DOMAIN/"

echo "==> [5/9] 配置 Mosquitto"
mkdir -p /var/lib/mosquitto /var/log/mosquitto
chown -R mosquitto:mosquitto /var/lib/mosquitto /var/log/mosquitto

# 用域名替换模板
sed "s/DOMAIN/$DOMAIN/g" /vps/mosquitto/mosquitto.conf > /etc/mosquitto/mosquitto.conf
cp /vps/mosquitto/mosquitto.acl /etc/mosquitto/mosquitto.acl
echo "acl_file /etc/mosquitto/mosquitto.acl" >> /etc/mosquitto/mosquitto.conf

# 生成密码文件
rm -f /etc/mosquitto/passwd
mosquitto_passwd -c -b /etc/mosquitto/passwd esp32cam "$ESP_MQTT_PASS"
mosquitto_passwd -b /etc/mosquitto/passwd app       "$APP_MQTT_PASS"
mosquitto_passwd -b /etc/mosquitto/passwd api       "$API_MQTT_PASS"
chown mosquitto:mosquitto /etc/mosquitto/passwd /etc/mosquitto/mosquitto.acl
chmod 640 /etc/mosquitto/passwd /etc/mosquitto/mosquitto.acl
systemctl enable mosquitto
systemctl restart mosquitto

echo "==> [6/9] 配置 Nginx"
sed "s/DOMAIN/$DOMAIN/g" /vps/nginx/champ.conf > /etc/nginx/sites-available/champ
ln -sf /etc/nginx/sites-available/champ /etc/nginx/sites-enabled/champ
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl reload nginx

echo "==> [7/9] 部署 Node.js API"
mkdir -p /opt/champ
cp -r /vps/api/* /opt/champ/
cd /opt/champ
npm install --omit=dev
mkdir -p /opt/champ/data
cat > /opt/champ/.env <<EOF
DOMAIN=$DOMAIN
API_TOKEN=$API_TOKEN
MQTT_HOST=127.0.0.1
MQTT_PORT=1883
MQTT_USER=api
MQTT_PASS=$API_MQTT_PASS
DB_PATH=/opt/champ/data/champ.db
HTTP_PORT=3000
EOF

echo "==> [8/9] 注册 systemd 服务"
cat > /etc/systemd/system/champ-api.service <<EOF
[Unit]
Description=Champ Node.js API
After=network.target mosquitto.service
Requires=mosquitto.service

[Service]
Type=simple
WorkingDirectory=/opt/champ
ExecStart=/usr/bin/node src/index.js
EnvironmentFile=/opt/champ/.env
Restart=always
RestartSec=5
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable champ-api
systemctl restart champ-api

echo "==> [9/9] 证书自动续期"
(crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet --post-hook 'systemctl reload nginx mosquitto'") | sort -u | crontab -

echo ""
echo "==== 部署完成 ===="
echo "  域名:       https://$DOMAIN"
echo "  MQTT/TLS:   $DOMAIN:8883 (ESP32 连)"
echo "  MQTT/WSS:   wss://$DOMAIN/mqtt (App 连)"
echo "  API Token:  $API_TOKEN"
echo "  ESP32 账号: esp32cam / $ESP_MQTT_PASS"
echo "  App 账号:   app / $APP_MQTT_PASS"
echo ""
echo "请把这些密码填入 firmware/config.h 和 app/lib/config.dart"

#!/bin/bash
echo "===== Champ VPS 端到端验证 ====="

echo "--- 1. Nginx ---"
systemctl is-active nginx
ss -tlnp | grep -E ':(80|443) ' | wc -l

echo "--- 2. Mosquitto ---"
systemctl is-active mosquitto
ss -tlnp | grep -E ':(1883|8883|9400) ' | wc -l

echo "--- 3. Node.js API ---"
systemctl is-active champ-api

echo "--- 4. API health ---"
curl -s https://cheeoo.lol/api/health

echo "--- 5. API devices (auth) ---"
curl -s -H 'Authorization: Bearer 3cGxkyPLLH7xnm9hYSm4igxArHCnhJiS' https://cheeoo.lol/api/devices

echo ""
echo "--- 6. MQTT pub via 1883 (internal) ---"
mosquitto_pub -h 127.0.0.1 -p 1883 -u esp32cam -P 'wrwFH3LkGTLs3fX5qGBA' -t 'cam/esp32cam-01/env' -m '{"deviceId":"esp32cam-01","temperature":28.5,"humidity":65.0,"heatIndex":30.2,"ts":1783509999}'
echo "pub ok"

echo "--- 7. MQTT pub status ---"
mosquitto_pub -h 127.0.0.1 -p 1883 -u esp32cam -P 'wrwFH3LkGTLs3fX5qGBA' -t 'cam/esp32cam-01/status' -m '{"deviceId":"esp32cam-01","state":"online","ip":"192.168.1.100","rssi":-55,"uptime":3600,"freeHeap":150000,"fps":5.0,"ts":1783509999}'
echo "status pub ok"

sleep 1

echo "--- 8. API history ---"
curl -s -H 'Authorization: Bearer 3cGxkyPLLH7xnm9hYSm4igxArHCnhJiS' 'https://cheeoo.lol/api/env/history?hours=1'

echo ""
echo "--- 9. API devices after status ---"
curl -s -H 'Authorization: Bearer 3cGxkyPLLH7xnm9hYSm4igxArHCnhJiS' https://cheeoo.lol/api/devices

echo ""
echo "--- 10. MQTT TLS 8883 with ISRG Root X1 ---"
curl -sL 'https://letsencrypt.org/certs/isrgrootx1.pem' > /tmp/isrg.pem
mosquitto_pub -h cheeoo.lol -p 8883 --cafile /tmp/isrg.pem -u esp32cam -P 'wrwFH3LkGTLs3fX5qGBA' -t 'cam/esp32cam-01/env' -m '{"deviceId":"esp32cam-01","temperature":29.0,"humidity":63.0,"heatIndex":30.5,"ts":1783510000}' && echo "TLS 8883 OK"

echo ""
echo "===== 验证完成 ====="

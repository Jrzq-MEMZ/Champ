#!/bin/bash
mosquitto_pub -h 127.0.0.1 -p 1883 -u esp32cam -P 'wrwFH3LkGTLs3fX5qGBA' -t 'cam/esp32cam-01/env' -m '{"deviceId":"esp32cam-01","temperature":26.5,"humidity":55.0,"heatIndex":27.0,"ts":1783509218}'
sleep 1
curl -s -H 'Authorization: Bearer 3cGxkyPLLH7xnm9hYSm4igxArHCnhJiS' 'https://cheeoo.lol/api/env/history?hours=1'
echo
curl -s -H 'Authorization: Bearer 3cGxkyPLLH7xnm9hYSm4igxArHCnhJiS' 'https://cheeoo.lol/api/devices'
echo

#!/bin/bash
# 证书自动续期
(crontab -l 2>/dev/null | grep -v certbot; echo '0 3 * * * certbot renew --quiet --post-hook "systemctl reload nginx mosquitto"') | crontab -
crontab -l | grep certbot
# 确保 mosquitto 能读证书
chmod -R o+rx /etc/letsencrypt/live /etc/letsencrypt/archive
chmod o+r /etc/letsencrypt/archive/cheeoo.lol/privkey1.pem
echo "done"

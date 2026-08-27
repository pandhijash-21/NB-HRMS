#!/bin/bash
set -euo pipefail

sed -i 's/\r$//' /tmp/remote_full_update.sh
chmod +x /tmp/remote_full_update.sh

rm -rf /tmp/nb_backend_unpack
mkdir -p /tmp/nb_backend_unpack
tar xf /tmp/backend-src.tar -C /tmp/nb_backend_unpack
rsync -a --delete --exclude '.env' --exclude '.env.production' --exclude 'node_modules' --exclude 'dist' \
  /tmp/nb_backend_unpack/backend/ /opt/nb-crm/backend/

install -m 755 /tmp/remote_full_update.sh /opt/nb-crm/deploy/remote_full_update.sh
sed -i 's/\r$//' /opt/nb-crm/deploy/remote_full_update.sh

if [ -f /tmp/frontend.conf ]; then
  mkdir -p /opt/nb-crm/deploy/nginx
  install -m 644 /tmp/frontend.conf /opt/nb-crm/deploy/nginx/frontend.conf
  sed -i 's/\r$//' /opt/nb-crm/deploy/nginx/frontend.conf
fi
if [ -f /tmp/vpn-blocked.html ]; then
  install -m 644 /tmp/vpn-blocked.html /opt/nb-crm/deploy/nginx/vpn-blocked.html
  sed -i 's/\r$//' /opt/nb-crm/deploy/nginx/vpn-blocked.html
fi

bash /opt/nb-crm/deploy/remote_full_update.sh

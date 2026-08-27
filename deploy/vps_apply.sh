#!/bin/bash
set -euo pipefail

cd /tmp
echo "==> Extract deploy bundle"
tar xf vps-deploy.tar

echo "==> Sync backend source"
tar xf backend-src.tar
rsync -a --delete backend/ /opt/nb-crm/backend/

cp nbcrm-web.tar /tmp/nbcrm-web.tar
install -m 755 remote_full_update.sh /opt/nb-crm/deploy/remote_full_update.sh
sed -i 's/\r$//' /opt/nb-crm/deploy/remote_full_update.sh

bash /opt/nb-crm/deploy/remote_full_update.sh

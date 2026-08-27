#!/bin/bash
# Run ON VPS after: scp D:\NB_CRM\nbcrm-web.tar root@200.234.36.120:/tmp/
set -euo pipefail

REPO=https://github.com/pandhijash-21/NB-HRMS.git
WORKDIR=/opt/nb-crm
STAGE=/tmp/nb-deploy

echo "==> Fetch latest from GitHub"
rm -rf "$STAGE"
git clone --depth 1 --branch main "$REPO" "$STAGE"

echo "==> Sync backend + deploy scripts"
rsync -a --delete "$STAGE/backend/" "$WORKDIR/backend/"
rsync -a "$STAGE/deploy/remote_full_update.sh" "$WORKDIR/deploy/"
rsync -a "$STAGE/docker-compose.prod.yml" "$WORKDIR/"

sed -i 's/\r$//' "$WORKDIR/deploy/remote_full_update.sh"
chmod +x "$WORKDIR/deploy/remote_full_update.sh"

if [ -f /tmp/nbcrm-web.tar ]; then
  echo "==> Frontend tarball found"
else
  echo "ERROR: Upload web build first from your PC:"
  echo "  scp D:\\NB_CRM\\nbcrm-web.tar root@200.234.36.120:/tmp/"
  exit 1
fi

bash "$WORKDIR/deploy/remote_full_update.sh"

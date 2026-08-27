# Upload and deploy NB CRM to VPS (run from D:\NB_CRM in PowerShell)
# Requires: SSH access to root@200.234.36.120

$ErrorActionPreference = "Stop"
$Vps = "root@200.234.36.120"
$Remote = "/tmp"

Write-Host "==> Uploading vps-deploy.tar (~76MB)..."
scp vps-deploy.tar "${Vps}:${Remote}/"

Write-Host "==> Running deploy on VPS..."
ssh $Vps @"
set -e
cd /opt/nb-crm
tar xf /tmp/vps-deploy.tar -C /tmp
tar xf /tmp/backend-src.tar
rsync -a --delete backend/ /opt/nb-crm/backend/
cp /tmp/nbcrm-web.tar /tmp/nbcrm-web.tar 2>/dev/null || cp nbcrm-web.tar /tmp/nbcrm-web.tar
cp /tmp/deploy/remote_full_update.sh /opt/nb-crm/deploy/remote_full_update.sh 2>/dev/null || cp remote_full_update.sh /opt/nb-crm/deploy/
chmod +x /opt/nb-crm/deploy/remote_full_update.sh
sed -i 's/\r$//' /opt/nb-crm/deploy/remote_full_update.sh
bash /opt/nb-crm/deploy/remote_full_update.sh
"@

Write-Host "DONE. Open https://crm.nbdeveloper.co.in and hard-refresh (Ctrl+Shift+R)."

set -e
export DEBIAN_FRONTEND=noninteractive
if ! command -v tailscale >/dev/null 2>&1; then
  curl -fsSL https://tailscale.com/install.sh | sh
fi
systemctl enable --now tailscaled
sysctl -w net.ipv4.ip_forward=1
grep -q 'net.ipv4.ip_forward=1' /etc/sysctl.d/99-tailscale-forward.conf 2>/dev/null || echo 'net.ipv4.ip_forward=1' > /etc/sysctl.d/99-tailscale-forward.conf
# Let Docker containers reach Tailscale / subnet routes
iptables -t nat -C POSTROUTING -s 172.16.0.0/12 -o tailscale0 -j MASQUERADE 2>/dev/null || \
  iptables -t nat -A POSTROUTING -s 172.16.0.0/12 -o tailscale0 -j MASQUERADE
tailscale up --accept-routes --hostname=nb-crm-vps --timeout=8s || true
echo '---STATUS---'
tailscale status || true
echo '---IP---'
tailscale ip -4 || true

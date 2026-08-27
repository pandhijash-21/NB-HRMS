"""One-shot VPS deploy. Password from env VPS_PASS only — do not commit secrets."""
from __future__ import annotations

import os
import stat
import sys
import time

import paramiko

HOST = os.environ.get("VPS_HOST", "200.234.36.120")
USER = os.environ.get("VPS_USER", "root")
PASSWORD = os.environ.get("VPS_PASS", "")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WEB_TAR = os.path.join(ROOT, "nbcrm-web.tar")
BACKEND_TAR = os.path.join(ROOT, "backend-src.tar")
UPDATE_SH = os.path.join(ROOT, "deploy", "remote_full_update.sh")
APPLY_SH = os.path.join(ROOT, "deploy", "vps_apply_remote.sh")
FRONTEND_CONF = os.path.join(ROOT, "deploy", "nginx", "frontend.conf")
VPN_BLOCKED_HTML = os.path.join(ROOT, "deploy", "nginx", "vpn-blocked.html")


def die(msg: str) -> None:
    print(msg, file=sys.stderr)
    sys.exit(1)


def put(sftp: paramiko.SFTPClient, local: str, remote: str, force: bool = False) -> None:
    size = os.path.getsize(local)
    try:
        remote_size = sftp.stat(remote).st_size
        if not force and remote_size == size:
            print(f"Skip {os.path.basename(local)} (already on VPS, {size} bytes)")
            return
    except OSError:
        pass
    print(f"Uploading {os.path.basename(local)} ({size} bytes) -> {remote}")
    last = [0]

    def cb(sent: int, total: int) -> None:
        pct = int(sent * 100 / total) if total else 0
        if pct >= last[0] + 10:
            last[0] = pct
            print(f"  {pct}%")

    sftp.put(local, remote, callback=cb)
    print("  100%")


def run(ssh: paramiko.SSHClient, cmd: str, timeout: int = 1800) -> int:
    print(f"\n$ {cmd}")
    stdin, stdout, stderr = ssh.exec_command(cmd, timeout=timeout)
    stdin.close()
    while True:
        line = stdout.readline()
        if not line:
            break
        try:
            print(line, end="")
        except UnicodeEncodeError:
            print(line.encode("ascii", "replace").decode("ascii"), end="")
    err = stderr.read().decode("utf-8", errors="replace")
    code = stdout.channel.recv_exit_status()
    if err.strip():
        print(err.encode("ascii", "replace").decode("ascii"), file=sys.stderr)
    print(f"[exit {code}]")
    return code


def main() -> None:
    if not PASSWORD:
        die("VPS_PASS is not set")
    required = [BACKEND_TAR, UPDATE_SH, APPLY_SH, FRONTEND_CONF, VPN_BLOCKED_HTML]
    for path in required:
        if not os.path.isfile(path):
            die(f"Missing {path}")
    if not os.path.isfile(WEB_TAR):
        print("WARN: nbcrm-web.tar missing — frontend files will not be replaced")

    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    print(f"Connecting {USER}@{HOST} ...")
    client.connect(HOST, username=USER, password=PASSWORD, timeout=30, allow_agent=False, look_for_keys=False)
    sftp = client.open_sftp()
    try:
        if os.path.isfile(WEB_TAR):
            put(sftp, WEB_TAR, "/tmp/nbcrm-web.tar")
        put(sftp, BACKEND_TAR, "/tmp/backend-src.tar")
        put(sftp, UPDATE_SH, "/tmp/remote_full_update.sh", force=True)
        put(sftp, APPLY_SH, "/tmp/vps_apply_remote.sh", force=True)
        put(sftp, FRONTEND_CONF, "/tmp/frontend.conf", force=True)
        put(sftp, VPN_BLOCKED_HTML, "/tmp/vpn-blocked.html", force=True)
    finally:
        sftp.close()

    code = run(client, "sed -i 's/\\r$//' /tmp/vps_apply_remote.sh && chmod +x /tmp/vps_apply_remote.sh && bash /tmp/vps_apply_remote.sh")
    client.close()
    if code != 0:
        die(f"Remote deploy failed with {code}")
    print("DEPLOY OK")


if __name__ == "__main__":
    main()

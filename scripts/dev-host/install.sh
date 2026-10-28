#!/usr/bin/env bash
# Run as root from this directory on the dev host.
set -euo pipefail
cd -- "$(dirname -- "$0")"
install -d /usr/local/lib/supplyz-dev /etc/systemd/journald.conf.d
install -m 0755 disk-check.sh maintain.sh /usr/local/lib/supplyz-dev/
cat > /etc/systemd/journald.conf.d/supplyz-retention.conf <<'CONFIG'
[Journal]
SystemMaxUse=200M
SystemKeepFree=2G
MaxRetentionSec=7day
CONFIG
# Reload applies journal limits without restarting application containers.
systemctl restart systemd-journald
cat > /etc/systemd/system/supplyz-dev-disk-maintenance.service <<'CONFIG'
[Unit]
Description=Reclaim disposable Supplyz dev build cache and check disk reserve
After=docker.service
[Service]
Type=oneshot
ExecStart=/usr/local/lib/supplyz-dev/maintain.sh
TimeoutStartSec=1h
Nice=10
IOSchedulingClass=idle
CONFIG
cat > /etc/systemd/system/supplyz-dev-disk-maintenance.timer <<'CONFIG'
[Unit]
Description=Hourly Supplyz dev disk maintenance
[Timer]
OnBootSec=5m
OnUnitActiveSec=1h
Persistent=true
RandomizedDelaySec=2m
[Install]
WantedBy=timers.target
CONFIG
systemctl daemon-reload
systemctl enable --now supplyz-dev-disk-maintenance.timer

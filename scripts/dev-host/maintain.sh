#!/usr/bin/env bash
# No volume, database, running-container or workspace deletion.
set -euo pipefail
exec 9>/run/lock/supplyz-dev-disk.lock
flock -n 9 || exit 0
journalctl --vacuum-size=200M
# Docker skips cache records in use by builds. Bound disposable build cache.
timeout 900 docker builder prune -af --filter until=24h --keep-storage 8GB
# Retain all container-referenced images (including rollback containers).
timeout 900 docker image prune -af --filter until=168h
available=$(df -Pk / | awk 'NR==2 {print $4}')
if (( available < 25 * 1024 * 1024 )); then
  timeout 900 docker builder prune -af --keep-storage 8GB
  timeout 900 docker image prune -af --filter until=48h
fi
/usr/local/lib/supplyz-dev/disk-check.sh

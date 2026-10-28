#!/usr/bin/env bash
# Works on the host and inside a runner (its overlay uses the host filesystem).
set -euo pipefail
read -r available used < <(df -Pk / | awk 'NR==2 {gsub(/%/, "", $5); print $4, $5}')
minimum_kib=$((20 * 1024 * 1024))
echo "Dev disk: ${used}% used, $((available / 1024 / 1024)) GiB available"
if (( available < minimum_kib || used >= 85 )); then
  echo '::error::Dev disk reserve breached (need 20 GiB free and usage below 85%). Run supplyz-dev-disk-maintenance and inspect storage before retrying.' >&2
  exit 1
fi

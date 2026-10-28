#!/usr/bin/env bash
# Only isolated CI scratch data; never application databases or Docker volumes.
set -euo pipefail
if pgrep -x mongod >/dev/null; then
  echo 'MongoDB test process remains active; leaving its scratch databases for inspection.'
  exit 1
fi
find /tmp -mindepth 1 -maxdepth 1 -type d \( -name 'mongo-mem-*' -o -name 'jest_*' \) -mmin +60 -exec rm -rf -- {} +
find /home/runner/_diag -type f -mtime +7 -delete

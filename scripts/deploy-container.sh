#!/usr/bin/env bash
# Runs on the deployment host (piped over SSH by deploy-container.yml).
# Replaces one container with a new image and keeps the old one until the new one is healthy.
# If the new container never becomes healthy, it is removed and the old one is started again.
#
# Usage:   deploy-container.sh <image:tag> <container-name> <[bind-ip:]host-port> [container-port]
# Options (environment): NETWORK, ENV_FILE, DOCKER_ARGS (extra docker run flags), HEALTH_TIMEOUT (seconds, default 120), DOCKER_CONFIG
set -euo pipefail

IMAGE="${1:?Image reference is required}"
NAME="${2:?Container name is required}"
PUBLISH="${3:?Published port is required}"
CPORT="${4:-80}"
NETWORK="${NETWORK:-}"
ENV_FILE="${ENV_FILE:-}"
HEALTH_TIMEOUT="${HEALTH_TIMEOUT:-120}"
DOCKER_ARGS="${DOCKER_ARGS:-}"

[[ "$IMAGE" =~ ^[a-zA-Z0-9_./:@-]+$ ]] || { echo 'Invalid image reference' >&2; exit 1; }
[[ "$NAME" =~ ^[a-zA-Z0-9_.-]+$ ]] || { echo 'Invalid container name' >&2; exit 1; }
[[ "$PUBLISH" =~ ^([0-9.]+:)?[0-9]{2,5}$ ]] || { echo 'Invalid published port' >&2; exit 1; }
[[ "$CPORT" =~ ^[0-9]{2,5}$ ]] || { echo 'Invalid container port' >&2; exit 1; }
[[ -z "$NETWORK" || "$NETWORK" =~ ^[a-zA-Z0-9_.-]+$ ]] || { echo 'Invalid network' >&2; exit 1; }
[[ -z "$DOCKER_ARGS" || "$DOCKER_ARGS" =~ ^[a-zA-Z0-9_./=:@\ -]+$ ]] || { echo 'Invalid docker args' >&2; exit 1; }

PREVIOUS="${NAME}-previous"

# Pull first: a registry failure leaves the running container untouched.
docker pull "$IMAGE" >/dev/null

had_previous=false
if docker inspect "$NAME" >/dev/null 2>&1; then
  had_previous=true
  docker rm -f "$PREVIOUS" >/dev/null 2>&1 || true
  docker rename "$NAME" "$PREVIOUS"
  docker stop "$PREVIOUS" >/dev/null   # frees the published port; kept for rollback
fi

args=(-d --log-driver local --log-opt max-size=10m --log-opt max-file=3 --name "$NAME" -p "$PUBLISH:$CPORT" --restart unless-stopped)
[ -z "$NETWORK" ] || args+=(--network "$NETWORK")
[ -z "$ENV_FILE" ] || args+=(--env-file "$ENV_FILE")
# shellcheck disable=SC2206
extra=($DOCKER_ARGS)
docker run "${args[@]}" "${extra[@]}" "$IMAGE" >/dev/null

healthy=false
deadline=$((SECONDS + HEALTH_TIMEOUT))
while [ "$SECONDS" -lt "$deadline" ]; do
  state="$(docker inspect -f '{{.State.Status}}|{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$NAME" 2>/dev/null || echo 'missing|none')"
  status="${state%%|*}"; health="${state##*|}"
  if [ "$status" != running ]; then break; fi
  if [ "$health" = healthy ]; then healthy=true; break; fi
  if [ "$health" = unhealthy ]; then break; fi
  # Image without a HEALTHCHECK: accept it once it has stayed up for 15 seconds.
  if [ "$health" = none ] && [ "$(( $(date +%s) - $(date -d "$(docker inspect -f '{{.State.StartedAt}}' "$NAME")" +%s) ))" -ge 15 ]; then healthy=true; break; fi
  sleep 2
done

if [ "$healthy" = true ]; then
  docker rm -f "$PREVIOUS" >/dev/null 2>&1 || true
  echo "$NAME is healthy ($IMAGE on $PUBLISH)."
  exit 0
fi

echo "$NAME did not become healthy. Recent logs:" >&2
docker logs --tail 50 "$NAME" >&2 || true
docker rm -f "$NAME" >/dev/null 2>&1 || true
if [ "$had_previous" = true ]; then
  docker rename "$PREVIOUS" "$NAME"
  docker start "$NAME" >/dev/null
  echo "Rolled back: the previous container is running again." >&2
fi
exit 1

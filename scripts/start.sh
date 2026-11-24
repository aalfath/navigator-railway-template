#!/bin/sh
# Start script for Navigator on Railway.
# - waits for Postgres, creates the admin account on first boot, then closes sign-up
# - runs the scheduled-task cron fallback (no Inngest needed)
# - exits non-zero whenever the app stops unexpectedly, so Railway restarts it
set -u
log() { echo "[navigator] $*"; }
cd /app

export PORT="${PORT:-3000}"
export HOSTNAME=0.0.0.0
export DISABLE_SIGN_UP="${DISABLE_SIGN_UP:-1}"
DB_URL="${POSTGRES_URL:-${DATABASE_URL:-}}"

# A reference such as https://${{RAILWAY_PUBLIC_DOMAIN}} renders as plain "https://"
# when the service has no domain yet: drop such values instead of failing.
for name in BETTER_AUTH_URL NEXT_PUBLIC_BASE_URL; do
  eval "value=\${$name:-}"
  case "$value" in
    http://?*.?*|https://?*.?*) ;;
    "") unset "$name" ;;
    *) log "ignoring $name='$value' (not a full URL)"; unset "$name" ;;
  esac
done

# Size the V8 heap to the container's memory limit (Railway Free plan: 512 MB).
if [ -z "${NODE_OPTIONS:-}" ]; then
  limit=$(cat /sys/fs/cgroup/memory.max 2>/dev/null || echo max)
  case "$limit" in
    ''|max|*[!0-9]*) ;;
    *)
      heap=$((limit / 1048576 * 60 / 100))
      [ "$heap" -lt 192 ] && heap=192
      [ "$heap" -gt 4096 ] && heap=4096
      export NODE_OPTIONS="--max-old-space-size=$heap"
      ;;
  esac
fi

if [ -z "$DB_URL" ]; then
  log "POSTGRES_URL is not set"; exit 1
fi

H=/app/apps/web/railway
# Wait for the database (its private DNS name can take a minute on a first deploy).
node $H/db.mjs wait || exit 1

# First boot: create the admin account on a loopback-only server, before the public
# server starts with sign-up closed. Failure stops the service (exit 1).
users=$(node $H/db.mjs users) || exit 1
if [ "$users" = 0 ]; then
  if [ -z "${ADMIN_EMAIL:-}" ] || [ -z "${ADMIN_PASSWORD:-}" ]; then
    log "no accounts yet and ADMIN_EMAIL/ADMIN_PASSWORD are not set"; exit 1
  fi
  log "first boot: running migrations and creating the admin account"
  BOOTSTRAP_PORT=3999
  DISABLE_SIGN_UP=0 HOSTNAME=127.0.0.1 PORT=$BOOTSTRAP_PORT node apps/web/server.js &
  tmp=$!
  BOOTSTRAP_PORT=$BOOTSTRAP_PORT node $H/bootstrap-admin.mjs
  rc=$?
  kill -TERM "$tmp" 2>/dev/null
  wait "$tmp" 2>/dev/null
  if [ "$rc" -ne 0 ]; then exit 1; fi
  role=$(node $H/db.mjs role "$ADMIN_EMAIL")
  if [ "$role" != admin ]; then log "admin account has role '$role', expected admin"; exit 1; fi
fi

stopping=0
trap 'stopping=1; kill -TERM "$app" 2>/dev/null' TERM INT
node apps/web/server.js &
app=$!

# Scheduled tasks: drive the app's secret-protected cron endpoint every minute.
cron=""
if [ -n "${SCHEDULED_TASK_SECRET:-}" ]; then
  (
    sleep 90
    while :; do
      wget -q -O /dev/null -T 280 --header "X-Scheduled-Task-Auth: $SCHEDULED_TASK_SECRET" \
        --post-data '' "http://127.0.0.1:$PORT/api/scheduled-tasks/cron" 2>/dev/null || true
      sleep 60
    done
  ) &
  cron=$!
fi

# BusyBox `wait` returns early on a trapped signal, so poll the app process.
while kill -0 "$app" 2>/dev/null; do sleep 2; done
wait "$app"; code=$?
[ -n "$cron" ] && kill "$cron" 2>/dev/null
if [ "$stopping" = 1 ]; then exit 0; fi
[ "$code" -eq 0 ] && code=1
log "Navigator stopped unexpectedly (exit $code)"
exit "$code"

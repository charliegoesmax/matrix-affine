#!/bin/sh
# affine-idle-watcher
# Starts AFFiNE on first request, stops it after 15 minutes of inactivity.
# Runs as a tiny sidecar next to the main stack.

set -e

IDLE_SECONDS="${IDLE_SECONDS:-900}"          # 15 minutes
CHECK_INTERVAL="${CHECK_INTERVAL:-30}"       # how often to check
AFFINE_COMPOSE_SERVICES="affine affine_postgres affine_redis"
COMPOSE_PROJECT_DIR="${COMPOSE_PROJECT_DIR:-/workspace}"
COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.yml}"
PROXY_PORT="${PROXY_PORT:-3010}"
AFFINE_INTERNAL="affine:3010"

LAST_ACTIVITY=$(date +%s)
STARTED=0

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

is_running() {
  docker compose -f "$COMPOSE_PROJECT_DIR/$COMPOSE_FILE" ps --status running --services 2>/dev/null | grep -qx affine
}

start_affine() {
  if [ "$STARTED" -eq 0 ] || ! is_running; then
    log "Starting AFFiNE stack..."
    docker compose -f "$COMPOSE_PROJECT_DIR/$COMPOSE_FILE" up -d $AFFINE_COMPOSE_SERVICES
    # wait until healthy-ish
    for i in $(seq 1 30); do
      if wget -q -O /dev/null --timeout=2 "http://$AFFINE_INTERNAL" 2>/dev/null; then
        log "AFFiNE is ready"
        STARTED=1
        return 0
      fi
      sleep 2
    done
    log "AFFiNE started but health check timed out (may still be booting)"
    STARTED=1
  fi
}

stop_affine() {
  if is_running; then
    log "Stopping AFFiNE stack (idle for ${IDLE_SECONDS}s)..."
    docker compose -f "$COMPOSE_PROJECT_DIR/$COMPOSE_FILE" stop $AFFINE_COMPOSE_SERVICES
    STARTED=0
  fi
}

touch_activity() {
  LAST_ACTIVITY=$(date +%s)
}

# Simple TCP proxy that records activity and ensures AFFiNE is up
# We use socat for the actual proxying.
proxy_loop() {
  log "Listening on :$PROXY_PORT (proxying to $AFFINE_INTERNAL)"
  # For every incoming connection, mark activity and ensure AFFiNE is started
  while true; do
    # Accept one connection, start AFFiNE if needed, then hand off with socat
    socat TCP-LISTEN:$PROXY_PORT,reuseaddr,fork SYSTEM:"
      echo 'connection' >&2
      # signal activity by touching a file the main loop watches
      touch /tmp/affine-activity
      # ensure it's up (the main process also watches the file)
      exec socat STDIO TCP:$AFFINE_INTERNAL
    " 2>&1 | while read -r line; do
      log "proxy: $line"
    done
  done
}

# Main idle watcher
idle_watcher() {
  while true; do
    now=$(date +%s)

    # If the proxy saw activity, update timestamp
    if [ -f /tmp/affine-activity ]; then
      LAST_ACTIVITY=$now
      rm -f /tmp/affine-activity
      start_affine
    fi

    idle=$((now - LAST_ACTIVITY))

    if is_running && [ "$idle" -ge "$IDLE_SECONDS" ]; then
      stop_affine
    fi

    sleep "$CHECK_INTERVAL"
  done
}

log "AFFiNE idle watcher starting (idle timeout = ${IDLE_SECONDS}s)"

# Run proxy in background, watcher in foreground
proxy_loop &
idle_watcher

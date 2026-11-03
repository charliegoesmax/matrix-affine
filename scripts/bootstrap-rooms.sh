#!/usr/bin/env bash
# bootstrap-rooms.sh
# One-shot script that creates a Super Collab Space + tool rooms with widgets
# after Continuwuity is up. Run once on first start (or whenever you want to re-seed).
#
# Usage (from host, after stack is healthy):
#   bash scripts/bootstrap-rooms.sh
#
# Or add as a one-shot service in docker-compose (see comments at bottom).

set -euo pipefail

# ---------------------------------------------------------------------------
# Config (override via environment)
# ---------------------------------------------------------------------------
HS_URL="${HS_URL:-http://localhost:6167}"
SERVER_NAME="${SERVER_NAME:-localhost}"
REG_TOKEN="${CONTINUWUITY_REGISTRATION_TOKEN:-}"
ADMIN_USER="${ADMIN_USER:-bootstrap}"
ADMIN_PASS="${ADMIN_PASS:-bootstrap-change-me}"

BOOKSTACK_URL="${BOOKSTACK_URL:-http://localhost:6875}"
LOGSEQ_URL="${LOGSEQ_URL:-http://localhost:3001}"
AFFINE_URL="${AFFINE_URL:-http://localhost:3010}"

SPACE_NAME="${SPACE_NAME:-Super Collab}"
SPACE_ALIAS="${SPACE_ALIAS:-super-collab}"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log() { echo "[bootstrap] $*"; }

wait_for_hs() {
  log "Waiting for Continuwuity at $HS_URL ..."
  for i in $(seq 1 60); do
    if curl -sf "$HS_URL/_matrix/client/versions" >/dev/null; then
      log "Homeserver is ready"
      return 0
    fi
    sleep 2
  done
  log "ERROR: Homeserver did not become ready"
  exit 1
}

# Register (idempotent-ish) and login
ensure_admin() {
  # Try login first
  LOGIN=$(curl -sf -X POST "$HS_URL/_matrix/client/v3/login" \
    -H 'Content-Type: application/json' \
    -d "{\"type\":\"m.login.password\",\"identifier\":{\"type\":\"m.id.user\",\"user\":\"$ADMIN_USER\"},\"password\":\"$ADMIN_PASS\"}" || true)

  if echo "$LOGIN" | grep -q access_token; then
    ACCESS_TOKEN=$(echo "$LOGIN" | jq -r .access_token)
    log "Logged in as @$ADMIN_USER:$SERVER_NAME"
    return 0
  fi

  # Register
  if [[ -z "$REG_TOKEN" ]]; then
    log "ERROR: CONTINUWUITY_REGISTRATION_TOKEN is required for first-time registration"
    exit 1
  fi

  log "Registering bootstrap user @$ADMIN_USER:$SERVER_NAME"
  REG=$(curl -sf -X POST "$HS_URL/_matrix/client/v3/register" \
    -H 'Content-Type: application/json' \
    -d "{\"username\":\"$ADMIN_USER\",\"password\":\"$ADMIN_PASS\",\"auth\":{\"type\":\"m.login.registration_token\",\"token\":\"$REG_TOKEN\"}}" || true)

  ACCESS_TOKEN=$(echo "$REG" | jq -r .access_token)
  if [[ "$ACCESS_TOKEN" == "null" || -z "$ACCESS_TOKEN" ]]; then
    log "ERROR: Registration failed: $REG"
    exit 1
  fi
  log "Registered and logged in"
}

api() {
  local method=$1 path=$2
  shift 2
  curl -sf -X "$method" "$HS_URL$path" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H 'Content-Type: application/json' \
    "$@"
}

create_room() {
  local name=$1 alias=$2 topic=$3
  local payload
  payload=$(jq -n \
    --arg name "$name" \
    --arg alias "$alias" \
    --arg topic "$topic" \
    '{
      name: $name,
      room_alias_name: $alias,
      topic: $topic,
      preset: "public_chat",
      visibility: "public",
      initial_state: [
        {type: "m.room.history_visibility", state_key: "", content: {history_visibility: "world_readable"}}
      ]
    }')

  local resp
  resp=$(api POST /_matrix/client/v3/createRoom -d "$payload")
  echo "$resp" | jq -r .room_id
}

add_widget() {
  local room_id=$1 widget_id=$2 name=$3 url=$4
  local content
  content=$(jq -n \
    --arg id "$widget_id" \
    --arg name "$name" \
    --arg url "$url" \
    '{
      type: "m.custom",
      url: $url,
      name: $name,
      data: {},
      id: $id
    }')

  # Element still honours im.vector.modular.widgets for simple URL widgets
  api PUT "/_matrix/client/v3/rooms/$room_id/state/im.vector.modular.widgets/$widget_id" -d "$content" >/dev/null
  log "Added widget '$name' → $url in $room_id"
}

add_to_space() {
  local space_id=$1 child_id=$2
  local content
  content=$(jq -n --arg via "$SERVER_NAME" '{via: [$via], suggested: true}')
  api PUT "/_matrix/client/v3/rooms/$space_id/state/m.space.child/$child_id" -d "$content" >/dev/null
  log "Added child $child_id to space"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
wait_for_hs
ensure_admin

log "Creating Space: $SPACE_NAME"
SPACE_ID=$(create_room "$SPACE_NAME" "$SPACE_ALIAS" "Super Collab hub — chat, wiki, graph, canvas")

log "Creating tool rooms"
BOOK_ID=$(create_room "BookStack Wiki" "bookstack" "Structured documentation")
LOGSEQ_ID=$(create_room "Logseq Graph" "logseq" "Networked notes and block graph")
AFFINE_ID=$(create_room "AFFiNE Canvas" "affine" "Infinite canvas boards")

log "Adding widgets"
add_widget "$BOOK_ID"   "bookstack" "BookStack" "$BOOKSTACK_URL"
add_widget "$LOGSEQ_ID" "logseq"    "Logseq"    "$LOGSEQ_URL"
add_widget "$AFFINE_ID" "affine"    "AFFiNE"    "$AFFINE_URL"

log "Linking rooms into Space"
add_to_space "$SPACE_ID" "$BOOK_ID"
add_to_space "$SPACE_ID" "$LOGSEQ_ID"
add_to_space "$SPACE_ID" "$AFFINE_ID"

log "Done."
log "Space ID: $SPACE_ID"
log "Join the Space in Element and you will see the tool rooms in the sidebar."
log "Bootstrap user: @$ADMIN_USER:$SERVER_NAME / $ADMIN_PASS  (change the password!)"

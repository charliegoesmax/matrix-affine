# Super Collab

A self-hosted Discord-style collaboration hub:

- **Chat / Spaces / Rooms / Threads** → Continuwuity + Element
- **Rich posts / canvas / wiki** → AFFiNE
- **Optional powerful search** → Meilisearch

Designed for local-first testing so it works on the first try.

## Quick Start (Local Testing)

### 1. Prerequisites

- Docker + Docker Compose v2
- Ports free: `6167`, `8080`, `3010` (and `7700` if using search)

### 2. Configure

```bash
cp .env.example .env
```

Edit `.env`:

- Set a strong `CONTINUWUITY_REGISTRATION_TOKEN` (required to create accounts)
- Set a strong `POSTGRES_PASSWORD`
- Leave `CONTINUWUITY_SERVER_NAME=localhost` for local testing

**Important**: `CONTINUWUITY_SERVER_NAME` becomes part of every user and room ID. It cannot be changed later without wiping the database. Keep it as `localhost` while testing.

### 3. Start the stack

```bash
docker compose up -d
```

Watch logs until healthy:

```bash
docker compose logs -f
```

First startup of AFFiNE can take 1–2 minutes while Postgres initializes and migrations run.

### 4. Create your accounts

**Matrix / Element**

1. Open http://localhost:8080
2. Create an account on the homeserver `localhost`
3. Use the registration token from your `.env` when prompted

**AFFiNE**

1. Open http://localhost:3010
2. Create the first user (this becomes the admin)

### 5. Recommended structure (Discord-like)

| Discord concept     | How to do it here                          |
|---------------------|--------------------------------------------|
| Server              | Matrix Space                               |
| Category / topic    | Nested Space or room category              |
| Channel             | Matrix room                                |
| Post                | Thread in a room                           |
| Rich content dump   | AFFiNE page (link or widget)               |
| Chat for the post   | The thread itself                          |

**Typical workflow for a “post”:**

1. Create a Space (your server).
2. Create a room under it (your channel).
3. Start a thread in that room (this is the post’s dedicated chat).
4. Create an AFFiNE page for the rich content (text, images, embeds, links, videos).
5. Paste the AFFiNE page URL into the thread root message.
6. Optionally pin the AFFiNE page as a widget with `/addwidget <url>` so it appears inside the room.

General chat stays in the main room. Focused discussion happens in the thread.

## Optional: Meilisearch

```bash
docker compose --profile search up -d
```

Meilisearch will be available at http://localhost:7700. You can later index Matrix messages and AFFiNE content into it for unified, fast search (and AI/MCP use).

## Stopping and restarting

```bash
docker compose down          # stop
docker compose up -d         # start again
docker compose down -v       # stop and delete all data (destructive)
```

## Production notes (later)

When you move to a real domain:

1. Set `CONTINUWUITY_SERVER_NAME` to your domain **before the first start** (cannot be changed later).
2. Put a reverse proxy (Caddy or Traefik) in front for TLS.
3. Update Element’s `config/element-config.json` `base_url` and `server_name`.
4. Update AFFiNE’s `config/affine-config.json` `externalUrl` to the public HTTPS URL.
5. Enable federation if desired (`CONTINUWUITY_ALLOW_FEDERATION=true`).
6. Open ports 443 and 8448 (or handle them via the reverse proxy).

## Troubleshooting (rare on first local run)

- **Cannot create Matrix account**: Double-check the registration token in `.env` matches what you type.
- **Element cannot reach homeserver**: Confirm Continuwuity is healthy (`docker compose ps`) and that `config/element-config.json` points to `http://localhost:6167`.
- **AFFiNE won’t start**: Check logs with `docker compose logs affine affine_migration postgres`. First run needs the migration job to finish.
- **Widget / iframe blank**: AFFiNE self-hosted is usually embeddable. If the browser blocks it, open the AFFiNE page in a new tab as a fallback.

## Next steps after it works

- Create your first Space + rooms.
- Make a couple of real posts using threads + AFFiNE pages.
- Enable the Meilisearch profile when you want better search.
- Add AI later via AFFiNE’s built-in MCP + BYOK or by pointing agents at Meilisearch.

Enjoy your self-hosted collaboration hub.

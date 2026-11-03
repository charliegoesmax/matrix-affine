# GoMax Ultimate Research Platform

Lightweight self-hosted collaboration hub:

- **Chat / Spaces / Rooms / Threads** → Continuwuity + Element
- **Networked notes / block graph / bidirectional links** → Logseq
- **Structured wiki (shelves → books → chapters → pages)** → BookStack
- **Infinite canvas (notes, arrows, connections, photos, documents on a board)** → AFFiNE

AFFiNE is the heavier optional piece. You can still use the rest of the stack if you stop it.

On first start a bootstrap script can create a Space containing three tool rooms (BookStack, Logseq, AFFiNE), each with a pre-loaded widget/iframe. New users who join the Space see the rooms in the left sidebar.

## Quick Start (Local Testing)

### 1. Prerequisites

- Docker + Docker Compose v2
- Ports free: `6167`, `8080`, `6875`, `3001`, `3010`
- Recommended free RAM: 4 GB+ if you plan to keep AFFiNE running

### 2. Configure

```bash
cp .env.example .env
```

Edit `.env`:

1. Set a strong `CONTINUWUITY_REGISTRATION_TOKEN`.
2. Generate a BookStack `APP_KEY`:
```bash
docker run -it --rm --entrypoint /bin/bash lscr.io/linuxserver/bookstack:latest appkey
```
Paste the output into `BOOKSTACK_APP_KEY`.
3. Set strong values for all database passwords (`BOOKSTACK_DB_*` and `AFFINE_DB_PASSWORD`).
4. Optional Logseq port (defaults to 3001):
```env
LOGSEQ_PORT=3001
```

**Important**: `CONTINUWUITY_SERVER_NAME` becomes part of every user and room ID. It cannot be changed later without wiping the database. Keep it as `localhost` while testing.

### 3. Start the stack

```bash
docker compose up -d
```

Watch logs until healthy:

```bash
docker compose logs -f
```

First startup of the databases can take a minute.

### 4. Bootstrap the Space and tool rooms (optional but recommended)

After Continuwuity is up, run the one-shot script to create the Space + widget rooms:

```bash
# From the repo root (requires curl + jq on the host)
CONTINUWUITY_REGISTRATION_TOKEN=your-token-here \
  bash scripts/bootstrap-rooms.sh
```

The script creates:
- A public Space named “Super Collab”
- Child rooms for BookStack, Logseq and AFFiNE, each with a pre-loaded widget pointing at the local service
- A bootstrap user `@bootstrap:localhost` (password `bootstrap-change-me` — change it immediately)

Join the Space in Element and the three tool rooms appear in the left sidebar.

### 5. Create your accounts / open the tools

**Element (chat)**  
http://localhost:8080  
Create an account on the homeserver `localhost` using the registration token from `.env`, then join the Super Collab Space.

**BookStack (wiki)**  
http://localhost:6875  
Default login (change immediately):
- Email: `admin@admin.com`
- Password: `password`

**Logseq (networked notes)**  
http://localhost:3001  
First visit lets you choose / confirm the graph folder (the host volume `./data/logseq/graph`).

**AFFiNE (infinite canvas)**  
http://localhost:3010  
The first request starts AFFiNE (can take 10–20 seconds). After 15 minutes with no traffic it automatically stops and frees RAM. The next visit wakes it again.

### 6. Recommended structure

| Need                              | Where to put it                                      |
| --------------------------------- | ---------------------------------------------------- |
| Server / categories / channels    | Element Spaces + rooms                               |
| Focused discussion on a topic     | Thread in a room                                     |
| Long-form structured writing      | BookStack page                                       |
| Bidirectional links / graph view  | Logseq (enrich the imported BookStack pages)         |
| Freeform board / mind map         | AFFiNE Edgeless canvas                               |
| Link everything together          | Widgets in the tool rooms, or paste URLs in threads  |

**Typical workflow:**

1. Join the Super Collab Space (or create your own).
2. Use the pre-built tool rooms (or `/addwidget` in any room) to open BookStack, Logseq or AFFiNE inside Element.
3. Write structured documentation in BookStack.
4. A one-way export can drop those pages into the Logseq graph so you can add block references, backlinks and queries on top.
5. Build freeform boards in AFFiNE when you need notes, arrows, photos and connections on a canvas.
6. Paste links or rely on the widgets so people can jump between chat and the tools.

### Stopping pieces you don’t need

AFFiNE is controlled by the idle watcher. It starts on first request to port 3010 and stops itself after 15 minutes of no traffic. You can also force-stop it:

```bash
docker compose stop affine affine_postgres affine_redis
```

To change the idle timeout, set `AFFINE_IDLE_SECONDS` in `.env` (default 900).

Or stop everything:

```bash
docker compose down
```

## Resource expectations

| Service                      | Approx. idle RAM |
| ---------------------------- | ---------------- |
| Continuwuity + Element       | 100–300 MB       |
| BookStack + MariaDB          | 250–500 MB       |
| Logseq                       | ~50–150 MB       |
| AFFiNE (when running)        | 700 MB–1.5 GB+   |
| AFFiNE idle watcher          | ~20 MB           |
| **Total with AFFiNE up**     | **1.3–2.7 GB**   |
| **Total with AFFiNE asleep** | **~450–950 MB**  |

AFFiNE only consumes its large footprint while someone is actively using the boards. After 15 minutes of no traffic it sleeps and the stack drops back to the light baseline.

## Production notes (later)

When you move to a real domain:

1. Set `CONTINUWUITY_SERVER_NAME` to your domain **before the first start**.
2. Put a reverse proxy (Caddy or Traefik) in front for TLS.
3. Update Element’s `config/element-config.json` `base_url` and `server_name`.
4. Update BookStack’s `APP_URL`, Logseq URLs, and AFFiNE’s `AFFINE_SERVER_EXTERNAL_URL` to the public HTTPS URLs and restart.
5. Re-run or adjust the bootstrap script so the widget URLs use the public addresses.

Enjoy the hybrid hub.

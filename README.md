# Super Collab

Lightweight self-hosted collaboration hub:

- **Chat / Spaces / Rooms / Threads** → Continuwuity + Element
- **Structured wiki (shelves → books → chapters → pages)** → BookStack
- **Infinite canvas (notes, arrows, connections, photos, documents on a board)** → AFFiNE

AFFiNE is the heavier optional piece. You can still use the rest of the stack if you stop it.

## Quick Start (Local Testing)

### 1. Prerequisites

- Docker + Docker Compose v2
- Ports free: `6167`, `8080`, `6875`, `3010`
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

### 4. Create your accounts

**Element (chat)**  
http://localhost:8080  
Create an account on the homeserver `localhost` using the registration token from `.env`.

**BookStack (wiki)**  
http://localhost:6875  
Default login (change immediately):  
- Email: `admin@admin.com`  
- Password: `password`

**AFFiNE (infinite canvas)**  
http://localhost:3010  
The first request starts AFFiNE (can take 10–20 seconds). After 15 minutes with no traffic it automatically stops and frees RAM. The next visit wakes it again.

### 5. Recommended structure

| Need                          | Where to put it                          |
|-------------------------------|------------------------------------------|
| Server / categories / channels| Element Spaces + rooms                   |
| Focused discussion on a topic | Thread in a room                         |
| Long-form structured writing  | BookStack page                           |
| Freeform board / mind map     | AFFiNE Edgeless canvas                   |
| Link everything together      | Paste the BookStack or AFFiNE URL into the thread (or use `/addwidget`) |

**Typical workflow:**

1. Create a Space and rooms in Element.
2. For a topic, start a thread.
3. Write the structured version in BookStack.
4. Make a freeform board in AFFiNE when you need notes, arrows, photos, and connections on a canvas.
5. Paste the AFFiNE (or BookStack) link into the thread so people can jump to the board while chatting.

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

| Service                  | Approx. idle RAM |
|--------------------------|------------------|
| Continuwuity + Element   | 100–300 MB       |
| BookStack + MariaDB      | 250–500 MB       |
| AFFiNE (when running)    | 700 MB–1.5 GB+   |
| AFFiNE idle watcher      | ~20 MB           |
| **Total with AFFiNE up** | **1.2–2.5 GB**   |
| **Total with AFFiNE asleep** | **~400–800 MB** |

AFFiNE only consumes its large footprint while someone is actively using the boards. After 15 minutes of no traffic it sleeps and the stack drops back to the light baseline.

## Production notes (later)

When you move to a real domain:

1. Set `CONTINUWUITY_SERVER_NAME` to your domain **before the first start**.
2. Put a reverse proxy (Caddy or Traefik) in front for TLS.
3. Update Element’s `config/element-config.json` `base_url` and `server_name`.
4. Update BookStack’s `APP_URL` and AFFiNE’s `AFFINE_SERVER_EXTERNAL_URL` to the public HTTPS URLs and restart.

Enjoy the hybrid hub.

# Server handoff: Leo Relay (`leo-relay`)

**Audience:** agent or operator on the Linux VPS that already hosts other apps (Nginx + Docker + subdomains).  
**Goal:** expose a public WebSocket relay so the Android demo and the Raspberry Pi can talk over the internet.  
**Scope:** only the relay service. Do **not** deploy Flutter, ROS, or Firebase on this server.

---

## 1. What this service is

`leo-relay` is a small FastAPI app that:

- Accepts WebSocket clients at `/ws`
- First message must be JSON `hello` with `role` (`phone` | `robot`), `robotId`, and `token`
- Relays `set_armed` from phones → robot
- Relays `status` and `map` (PNG base64) from robot → phones
- Serves `GET /health` for probes

**Clients (not on this server):**

| Client | Connects as | Needs |
|--------|-------------|--------|
| Flutter `leo-demo` | `role: phone` | `wss://leo.<domain>/ws` + shared token |
| Pi `leo_cloud_bridge` | `role: robot` | same URL + token (outbound only; no inbound ports on the Pi) |

Repo path (this monorepo):

```text
leo-application/leo-relay/
  Dockerfile
  docker-compose.yml
  .env.example
  app/
  nginx/leo.YOUR_DOMAIN.conf
```

---

## 2. Prerequisites on the server

Confirm already available (this host pattern):

- [ ] Docker + Docker Compose plugin
- [ ] Nginx (or equivalent reverse proxy used by other apps)
- [ ] Ability to create a **DNS A/CNAME** for a new subdomain
- [ ] Certbot (or existing ACME flow) for TLS
- [ ] Outbound HTTPS from the host (image pulls)

Port **8080** on localhost must be free (or change compose mapping and Nginx upstream together).

---

## 3. Fill these values before deploy

| Variable | Example | Notes |
|----------|---------|--------|
| `BASE_DOMAIN` | `example.com` | Parent domain already in use |
| `LEO_SUBDOMAIN` | `leo.example.com` | New subdomain for this app |
| `LEO_RELAY_TOKEN` | long random string | Shared secret; phone + Pi must match |
| `DEPLOY_DIR` | e.g. `/opt/leo-relay` or clone path | Where compose runs |
| `HOST_PORT` | `8080` | Bound to `127.0.0.1` preferred if possible |

Generate a strong token (do not leave the example default in production):

```bash
openssl rand -hex 32
```

**Deliverable back to app/robot team:** final `wss://leo.<domain>/ws` and the token (via secure channel).

---

## 4. Deploy steps (execute in order)

### 4.1 DNS

Create:

```text
leo.<BASE_DOMAIN>  →  A (or CNAME) pointing at this server
```

Wait until it resolves:

```bash
dig +short leo.<BASE_DOMAIN>
```

### 4.2 Place the app

Either clone the repo and use `leo-application/leo-relay`, or copy that directory to `DEPLOY_DIR`.

```bash
cd <path-to>/leo-application/leo-relay
cp .env.example .env
# Edit .env:
#   LEO_RELAY_TOKEN=<strong-secret>
#   MOCK_MAP=false
```

`MOCK_MAP=true` only for UI testing without a robot; leave **false** for real demos.

### 4.3 Harden port binding (recommended)

Prefer binding only to localhost so the app is not reachable except via Nginx:

In `docker-compose.yml`, change:

```yaml
ports:
  - "8080:8080"
```

to:

```yaml
ports:
  - "127.0.0.1:8080:8080"
```

### 4.4 Start the container

```bash
cd <leo-relay-dir>
docker compose up -d --build
docker compose ps
curl -sS http://127.0.0.1:8080/health
# expect: {"ok":true,"service":"leo-relay"}
```

### 4.5 Nginx site

Use `nginx/leo.YOUR_DOMAIN.conf` as a template:

1. Replace every `leo.YOUR_DOMAIN` with `leo.<BASE_DOMAIN>`
2. Install under the same pattern as other apps (`sites-available` / `conf.d`)
3. Enable site and `nginx -t`
4. Reload Nginx

**Critical for WebSockets** (already in the template):

- `Upgrade` / `Connection` headers on `/ws`
- Long `proxy_read_timeout` / `proxy_send_timeout` (3600s)

If this host uses a different proxy layout (Traefik, Caddy, etc.), apply the same WebSocket upgrade rules to path `/ws` → `http://127.0.0.1:8080`.

### 4.6 TLS

Issue a certificate for `leo.<BASE_DOMAIN>` with the same method as other subdomains, e.g.:

```bash
certbot --nginx -d leo.<BASE_DOMAIN>
```

Uncomment / confirm `ssl_certificate` paths in the server block if not managed automatically by certbot.

Public URL must be:

```text
wss://leo.<BASE_DOMAIN>/ws
```

HTTP→HTTPS redirect is fine; clients should use **WSS**, not WS, on the public internet.

### 4.7 Firewall

- Allow **80/443** from the internet (as for other apps)
- Do **not** expose host port **8080** publicly if bound to `127.0.0.1`
- No special inbound ports needed for the Raspberry Pi (it dials out)

---

## 5. Verification checklist

Run from the server:

```bash
# Container healthy
curl -sS http://127.0.0.1:8080/health

# Public HTTPS health (after DNS + TLS)
curl -sS https://leo.<BASE_DOMAIN>/health
```

WebSocket smoke test (install `websockets` or use any WS client):

```bash
# Example with Python on the server (optional)
python3 - <<'PY'
import asyncio, json, websockets

URL = "wss://leo.YOUR_DOMAIN/ws"
TOKEN = "YOUR_TOKEN"

async def main():
    async with websockets.connect(URL) as ws:
        await ws.send(json.dumps({
            "type": "hello",
            "role": "phone",
            "robotId": "LEO_001",
            "token": TOKEN,
        }))
        print(await ws.recv())

asyncio.run(main())
PY
```

Expect a JSON `welcome` message. Wrong token → connection closes / `error` unauthorized.

---

## 6. Protocol notes (for debugging only)

First frame after connect:

```json
{
  "type": "hello",
  "role": "phone",
  "robotId": "LEO_001",
  "token": "<LEO_RELAY_TOKEN>"
}
```

Common message types: `set_armed`, `status`, `map`, `ping`/`pong`, `error`.

Auth is a single shared token (demo-grade). Do not put the token in public git issues/chats.

---

## 7. Ops

| Task | Command |
|------|---------|
| Logs | `docker compose -f <dir>/docker-compose.yml logs -f leo-relay` |
| Restart | `docker compose restart leo-relay` |
| Rebuild after pull | `docker compose up -d --build` |
| Update token | edit `.env` → `docker compose up -d` |

Resource use is low (stateless hub; map frames are transient). Disk: image + logs only.

---

## 8. Out of scope (do not do on this server)

- Do not install ROS, LiDAR drivers, or Flutter
- Do not open inbound ports for the robot
- Do not put live OccupancyGrid data in Firebase
- Do not change other apps’ Nginx sites except adding this subdomain

Pi and phone config are handled by the robot/app team using the URL + token you return.

---

## 9. Handoff return (fill and send back)

```text
Subdomain:        leo.____________________
WSS URL:          wss://leo.____________________/ws
Health URL:       https://leo.____________________/health
Token set:        yes / no  (send token out-of-band)
Host bind:        127.0.0.1:8080 / 0.0.0.0:8080
MOCK_MAP:         false
DNS OK:           yes / no
TLS OK:           yes / no
curl /health OK:  yes / no
WS hello OK:      yes / no
Compose path:     ____________________
Notes:            ____________________
```

---

## 10. Quick reference — env

From `.env.example`:

```env
LEO_RELAY_TOKEN=change-me-demo-token
MOCK_MAP=false
```

Compose injects these into the container. App reads `LEO_RELAY_TOKEN` and `MOCK_MAP` via settings.

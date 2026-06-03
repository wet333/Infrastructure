# Deploying new services

Use this when a new app (or client project) should be reachable on the internet via **HTTPS** on the shared VPS.

**Read first:** [How the proxy works](./How-the-proxy-works.md) — architecture in plain language.

---

## Before you start

- Traefik is running (`docker compose up -d` in `traefik-proxy/`).
- Network exists (once): `docker network create traefik-net`
- You know the **domain** and the **port the app listens on inside the container** (e.g. 3000, 8080).

---

## Three steps

### 1. DNS

Create an **A record** for your hostname → VPS IP (same IP as every other app).

Example: `app.client.com` → `203.0.113.10`

### 2. Join `traefik-net`

In the **app’s** `docker-compose.yml` (or `docker-compose.deploy.yml`):

```yaml
services:
  myapp:
    image: myapp:latest
    networks:
      - traefik-net

networks:
  traefik-net:
    external: true
```

Do **not** publish the app port on the host (no `ports: "3000:3000"` for public apps). Traefik reaches the container on the internal network.

### 3. Add Traefik labels

Copy this block and change the three placeholders: **router name**, **domain**, **port**.

```yaml
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.MYAPP.rule=Host(`app.client.com`)"
      - "traefik.http.routers.MYAPP.entrypoints=websecure"
      - "traefik.http.routers.MYAPP.tls.certresolver=le-resolver"
      - "traefik.http.services.MYAPP.loadbalancer.server.port=3000"
```

| Placeholder | Meaning |
|-------------|---------|
| `MYAPP` | Unique name per service (e.g. `clientb-api`). Must not clash with another container on the VPS. |
| `app.client.com` | Exact hostname from DNS. |
| `3000` | Port **inside** the container where the process listens. |
| `le-resolver` | Fixed — matches Traefik’s certificate setup. Do not rename. |

Deploy from the project folder:

```bash
docker compose -f docker-compose.deploy.yml up -d
# or your usual compose file
```

Traefik picks up the new container automatically. **No need to restart Traefik.**

---

## Full minimal example

App on port 3000, domain `client-b.example.com`:

```yaml
services:
  web:
    image: node:20-alpine
    networks:
      - traefik-net
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.clientb.rule=Host(`client-b.example.com`)"
      - "traefik.http.routers.clientb.entrypoints=websecure"
      - "traefik.http.routers.clientb.tls.certresolver=le-resolver"
      - "traefik.http.services.clientb.loadbalancer.server.port=3000"

networks:
  traefik-net:
    external: true
```

**Two public services in one compose?** Repeat the label block on each service with a different router name, domain, and port.

---

## Checklist

- [ ] DNS A record → VPS IP
- [ ] Service on `traefik-net` (`external: true`)
- [ ] Labels: `enable`, `Host(...)`, `websecure`, `le-resolver`, `loadbalancer.server.port`
- [ ] No host `ports:` on the public service
- [ ] `docker compose up -d` in the app project
- [ ] Open `https://your-domain` in the browser

---

## When something breaks

| Symptom | What to check |
|---------|----------------|
| **502 Bad Gateway** | App on `traefik-net`? Port in labels matches the app? App listening on `0.0.0.0`, not only `127.0.0.1`? |
| **No certificate** | DNS points to VPS? Ports 80/443 open? `ACME_EMAIL` set? Logs: `docker logs traefik` |
| **Wrong site / 404** | `Host(\`...\`)` matches the URL exactly? `traefik.enable=true`? Router name unique? |

---

## Production file convention

On the VPS, each app project should have its own **`docker-compose.deploy.yml`**:

- Internal network for DB/workers
- `traefik-net` external for anything public
- Traefik labels per public hostname
- No published app ports on the host

To generate deploy files with an agent: **`@vps-generate-deploy`** — see [`../generate-deploy-skill/INSTALL.md`](../generate-deploy-skill/INSTALL.md).

---

## More detail

Proxy setup and `.env`: [How the proxy works](./How-the-proxy-works.md).

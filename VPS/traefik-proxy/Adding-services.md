# Adding Services Behind the Traefik Proxy

This guide explains how to connect new Docker / docker-compose projects to the existing Traefik reverse proxy so they are reachable via HTTPS with automatic Let’s Encrypt certificates.

---

## Prerequisites

1. **Traefik is running** with the configuration in `docker-compose.yml` (see [Traefik-proxy.md](./Traefik-proxy.md)).
2. **The shared network exists** – create it once if needed:
   ```bash
   docker network create traefik-net
   ```

Every service you want behind Traefik must:
- Be on the **`traefik-net`** network.
- Have **Traefik labels** that enable it and define router(s) and service(s).

---

## Steps to Connect a New Project

### 1. Add the `traefik-net` network to your project

In the **client project’s** `docker-compose.yml`:

- Add `traefik-net` as an **external** network (same as in the Traefik stack).
- Attach each service that should be reachable through Traefik to `traefik-net`.

Example:

```yaml
services:
  myapp:
    image: myapp:latest
    # ... your app config ...
    networks:
      - default
      - traefik-net

networks:
  default:
    # your existing network if any
  traefik-net:
    external: true
```

### 2. Add Traefik labels to the service

Labels tell Traefik:
- To expose this container (`traefik.enable=true`).
- Which **router** to create (host, TLS, entrypoint).
- Which **service** to use (which container/port to forward to).

**Minimal example – one HTTPS host, one backend port:**

```yaml
services:
  myapp:
    image: myapp:latest
    networks:
      - traefik-net
    labels:
      - "traefik.enable=true"
      # Router: handle requests for this host on HTTPS
      - "traefik.http.routers.myapp.rule=Host(`app.client-a.com`)"
      - "traefik.http.routers.myapp.entrypoints=websecure"
      - "traefik.http.routers.myapp.tls.certresolver=le-resolver"
      # Service: send traffic to this container on port 8080
      - "traefik.http.services.myapp.loadbalancer.server.port=8080"
```

- Replace `myapp` with a **unique** router/service name per service (e.g. `client-a-frontend`).
- Replace `app.client-a.com` with the real **domain** that will point to your VPS (DNS A/AAAA record).
- Replace `8080` with the **port** your app listens on **inside** the container.

After deploying, Traefik will:
- Obtain a Let’s Encrypt certificate for `app.client-a.com` (using the resolver from the Traefik config).
- Redirect HTTP → HTTPS.
- Forward HTTPS requests for `app.client-a.com` to this container on port 8080.

---

## Label Reference

Use these as a checklist when adding a new service.

| Label | Purpose | Example |
|-------|--------|--------|
| `traefik.enable=true` | Expose this container to Traefik | Required |
| `traefik.http.routers.<name>.rule` | Routing rule (Host, Path, etc.) | `Host(\`app.example.com\`)` |
| `traefik.http.routers.<name>.entrypoints` | Entrypoint(s) | `websecure` for HTTPS |
| `traefik.http.routers.<name>.tls.certresolver` | Use Let’s Encrypt | `le-resolver` (must match Traefik config) |
| `traefik.http.services.<name>.loadbalancer.server.port` | Backend port inside container | `8080`, `3000`, `80`, etc. |

- **Router name** and **service name** can be the same (e.g. `myapp`) or different; they are linked by the router’s default service (same name) or by `traefik.http.routers.<name>.service=<service-name>`.

---

## Complete Examples

### Example 1: Single app, one domain (HTTPS)

App listens on port 3000 inside the container; domain `client-b.example.com`.

```yaml
services:
  web:
    image: node:20-alpine
    working_dir: /app
    volumes:
      - .:/app
    command: npm start
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

### Example 2: Multiple services in one compose (e.g. API + frontend)

- `api` → `api.client-c.com` → port 8000  
- `frontend` → `app.client-c.com` → port 80  

```yaml
services:
  api:
    image: myapi:latest
    networks:
      - traefik-net
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.clientc-api.rule=Host(`api.client-c.com`)"
      - "traefik.http.routers.clientc-api.entrypoints=websecure"
      - "traefik.http.routers.clientc-api.tls.certresolver=le-resolver"
      - "traefik.http.services.clientc-api.loadbalancer.server.port=8000"

  frontend:
    image: myfrontend:latest
    networks:
      - traefik-net
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.clientc-web.rule=Host(`app.client-c.com`)"
      - "traefik.http.routers.clientc-web.entrypoints=websecure"
      - "traefik.http.routers.clientc-web.tls.certresolver=le-resolver"
      - "traefik.http.services.clientc-web.loadbalancer.server.port=80"

networks:
  traefik-net:
    external: true
```

### Example 3: Path prefix (e.g. `/app` on one domain)

Serve one app at `myserver.com/app`:

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.myapp.rule=Host(`myserver.com`) && PathPrefix(`/app`)"
  - "traefik.http.routers.myapp.entrypoints=websecure"
  - "traefik.http.routers.myapp.tls.certresolver=le-resolver"
  - "traefik.http.services.myapp.loadbalancer.server.port=8080"
  # Strip /app before forwarding (many apps expect to be at /)
  - "traefik.http.middlewares.myapp-stripprefix.stripprefix.prefixes=/app"
  - "traefik.http.routers.myapp.middlewares=myapp-stripprefix"
```

(Adjust middleware name and router name as needed; keep them unique across projects.)

---

## Checklist for Each New Client/Service

1. **DNS**: Create A/AAAA records for the hostname(s) pointing to the VPS IP.
2. **Network**: In the project’s `docker-compose.yml`, add `traefik-net` as external and attach the service to it.
3. **Labels**: Add `traefik.enable=true`, router rule (e.g. `Host(\`...\`)`), `entrypoints=websecure`, `tls.certresolver=le-resolver`, and `loadbalancer.server.port=<port>`.
4. **Deploy**: From the project directory run `docker compose up -d` (or `docker-compose up -d`). Traefik will pick up the new container automatically; no need to restart Traefik.
5. **Firewall**: Ensure the VPS allows inbound 80 and 443; no need to open each app’s port to the internet.

---

## Troubleshooting

- **502 Bad Gateway** – Traefik can’t reach the container. Check: (1) service is on `traefik-net`, (2) `loadbalancer.server.port` matches the port the app listens on inside the container, (3) app is listening on `0.0.0.0` (or all interfaces), not only `127.0.0.1`.
- **Certificate not issued** – Ensure the domain resolves to the VPS, ports 80/443 are reachable, and the ACME email in the Traefik config is set. Check Traefik logs: `docker logs traefik`.
- **Route not found** – Confirm `traefik.enable=true` and the router `rule` (e.g. `Host(\`...\`)`) matches the URL you use. Router/service names must be unique across all containers Traefik sees.

For more detail on Traefik’s configuration and entrypoints, see [Traefik-proxy.md](./Traefik-proxy.md).

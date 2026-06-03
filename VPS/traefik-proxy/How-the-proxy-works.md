# How the proxy works

One VPS runs **Traefik** as the front door. Every app stays in its own Docker Compose project, but all public traffic goes through Traefik on ports **80** and **443**.

## The big picture

```
Internet
    │
    ▼
┌─────────────┐
│   Traefik   │  :80  → redirects to HTTPS
│  (one box)  │  :443 → HTTPS + picks the right app
└──────┬──────┘
       │  traefik-net (shared Docker network)
   ┌───┴───┬─────────┐
   ▼       ▼         ▼
 App A   App B    App C
(each in its own docker-compose folder)
```

**What Traefik does for you**

- Listens on the VPS for web traffic (you do not open random ports per app).
- Sends each request to the right container based on the **domain name** in the URL.
- Gets and renews **HTTPS certificates** (Let’s Encrypt) automatically.
- Redirects **HTTP → HTTPS**.

**What you do when adding an app**

- Point DNS at the VPS.
- Join the app to `traefik-net`.
- Add a few **labels** on the service (see [Deploying new services](./Deploying-new-services.md)).

You usually **do not** edit Traefik’s config when you add another client or service.

---

## Main pieces

| Piece | Role |
|-------|------|
| **Traefik container** | Reverse proxy; only service that needs ports 80/443 on the host. |
| **`traefik-net`** | Shared network. Traefik and every public app must be on it. Create once: `docker network create traefik-net`. |
| **Labels** | Small instructions on each app container: “for `app.example.com`, send traffic to port 3000”. |
| **`letsencrypt/`** | Stores certificates so they survive restarts. |
| **`.env`** | Secrets and hostnames for Traefik itself (not for client apps). Copy from `example.env`. |

Traefik watches Docker. Only containers with `traefik.enable=true` and proper labels are exposed (`exposedbydefault=false` keeps everything else private).

---

## Traefik stack (`docker-compose.yml`)

**Startup**

- `traefik-init-acme` creates `letsencrypt/acme.json` with safe permissions.
- `traefik` starts after that.

**Ports**

- `80` — HTTP (redirects to HTTPS).
- `443` — HTTPS (where apps are served).

**Certificates**

- Resolver name: `le-resolver` (use this exact name in app labels).
- Email comes from `ACME_EMAIL` in `.env`.
- Certs are stored in `./letsencrypt`.

**Dashboard**

- Not on a public port like 8080.
- URL: `https://<DASHBOARD_HOST>/dashboard/`
- Protected with basic auth (`DASHBOARD_AUTH_USERS` in `.env`).
- Needs a DNS A record for `DASHBOARD_HOST` like any other site.

**Volumes**

- Docker socket (read-only) — so Traefik can see containers and labels.
- `./letsencrypt` — certificate storage.

---

## Environment file (`.env`)

```bash
cp example.env .env
```

| Variable | What it’s for |
|----------|----------------|
| `ACME_EMAIL` | Let’s Encrypt contact email. Required. |
| `DASHBOARD_HOST` | Domain for the Traefik dashboard (e.g. `traefik.yourdomain.com`). |
| `DASHBOARD_AUTH_USERS` | `user:hashedpassword` from `htpasswd -nbB`. In `.env`, write `$$` for each `$` in the hash. |

Do not commit `.env`. Keep `example.env` in git as the template.

---

## DNS (short version)

1. Get the VPS public IP (`curl -4 -s ifconfig.me` or your provider panel).
2. For each hostname (e.g. `app.example.com`), add an **A record** pointing to that IP. Same IP for every app — Traefik uses the hostname to choose the backend.
3. Wait a few minutes, then check: `dig app.example.com`.
4. Open ports **80** and **443** on the VPS firewall.

Optional: a wildcard `*.example.com` A record works if you use many subdomains under one domain.

---

## Start Traefik (reminder)

```bash
docker network create traefik-net   # once
cp example.env .env                 # edit values
docker compose up -d                # from traefik-proxy/
```

**Next:** [Deploying new services](./Deploying-new-services.md) — connect an app step by step.

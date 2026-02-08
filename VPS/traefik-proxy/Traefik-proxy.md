# Traefik Reverse Proxy – Architecture & Configuration

This document describes how the Traefik reverse proxy is set up on your VPS and what each part of the configuration does. The goal is to run **one Traefik instance** that fronts **multiple client projects** (each with their own docker-compose), so you can add new services easily.

---

## Architecture Overview

```
                    Internet
                        │
                        ▼
              ┌─────────────────┐
              │     VPS         │
              │                 │
              │  ┌───────────┐  │
              │  │  Traefik  │  │  :80 (HTTP) → redirect to HTTPS
              │  │  (proxy)  │  │  :443 (HTTPS) → TLS + routing
              │  └─────┬─────┘  │
              │        │        │
              │   traefik-net   │
              │        │        │
              │  ┌─────┴──────────────────────────────┐
              │  │                                    │
              │  ▼              ▼                     ▼
              │  Client A    Client B    Client C   ...
              │  (compose)   (compose)   (compose)
              │  app:8080    app:3000    app:80
              └──────────────────────────────────────┘
```

- **Single entry point**: All HTTP/HTTPS traffic hits Traefik on ports 80 and 443.
- **One shared network**: All backend apps attach to the same Docker network (`traefik-net`) so Traefik can reach them by container/service name.
- **Per-service routing**: Each project uses Traefik **labels** to define hostnames (or paths) and TLS. No need to edit Traefik’s config when adding a new service.

---

## What Each Part of the Configuration Does

### 1. Image and restart

- **`image: traefik:v3.0`** – Uses Traefik v3.
- **`restart: always`** – Traefik is restarted by Docker if it exits (e.g. after a crash or reboot).

### 2. Ports

| Port mapping | Purpose |
|--------------|--------|
| `80:80`      | HTTP. Used for redirect to HTTPS and for ACME HTTP-01 if needed. |
| `443:443`    | HTTPS. Main entry point for secured traffic. |

The **Traefik dashboard** is not exposed on port 8080. It is served over HTTPS at `https://<DASHBOARD_HOST>/dashboard/` and protected with basic auth (see [Dashboard](#10-dashboard) and [Environment variables](#9-environment-variables-env)).

### 3. Docker as provider

```yaml
- "--providers.docker=true"
- "--providers.docker.endpoint=unix:///var/run/docker.sock"
- "--providers.docker.exposedbydefault=false"
- "--providers.docker.network=traefik-net"
```

- **`providers.docker=true`** – Traefik discovers routes from Docker containers and their labels.
- **`endpoint=unix:///var/run/docker.sock`** – Traefik talks to the Docker daemon (needs the socket mounted as a volume).
- **`exposedbydefault=false`** – Only containers that have **`traefik.enable=true`** (and proper labels) are exposed. Safer for multi-tenant/client setups.
- **`network=traefik-net`** – Traefik uses this network to reach backend containers. All services you want behind the proxy must be on `traefik-net`.

### 4. EntryPoints

```yaml
- "--entrypoints.web.address=:80"
- "--entrypoints.websecure.address=:443"
```

- **`web`** – Listens on port 80 (HTTP).
- **`websecure`** – Listens on port 443 (HTTPS).

All routing and TLS are defined per-router; entrypoints just define where Traefik listens.

### 5. HTTP → HTTPS redirect

```yaml
- "--entrypoints.web.http.redirections.entryPoint.to=websecure"
- "--entrypoints.web.http.redirections.entryPoint.scheme=https"
```

- Every request that arrives on **port 80** is redirected to **port 443** with the same host and path.
- Users always use HTTPS once this is in place.

### 6. SSL certificates (Let’s Encrypt / ACME)

```yaml
- "--certificatesresolvers.le-resolver.acme.tlschallenge=true"
- "--certificatesresolvers.le-resolver.acme.email=${ACME_EMAIL}"
- "--certificatesresolvers.le-resolver.acme.storage=/letsencrypt/acme.json"
```

- **`le-resolver`** – Name of the certificate resolver. You reference it in labels with `traefik.http.routers.<name>.tls.certresolver=le-resolver`.
- **`tlschallenge=true`** – Uses the TLS-ALPN-01 challenge. No need to open port 80 for HTTP-01 (handy when 80 only redirects to 443).
- **`email=${ACME_EMAIL}`** – The Let’s Encrypt contact email is read from the **`.env`** file (variable `ACME_EMAIL`). Used for expiry and account notifications.
- **`storage=/letsencrypt/acme.json`** – Persists certificates and account data. The `./letsencrypt` volume maps here so certs survive container restarts.

**Important:** Set `ACME_EMAIL` in `.env` to your real address before production, and ensure the `letsencrypt` directory exists with correct permissions (e.g. `600` for `acme.json` if you use it).

### 7. Volumes

| Host path                          | Container path           | Purpose |
|------------------------------------|--------------------------|--------|
| `/var/run/docker.sock` (read-only) | `/var/run/docker.sock`   | So Traefik can list containers and read labels. |
| `./letsencrypt`                    | `/letsencrypt`           | Persist ACME certificates and state. |

### 8. Network

```yaml
networks:
  - traefik-net

# at the bottom:
networks:
  traefik-net:
    external: true
```

- **`traefik-net`** is **external**: you create it once (e.g. `docker network create traefik-net`) and reuse it for Traefik and every backend stack.
- All client projects that should be behind this proxy must attach their services to **`traefik-net`** and add the appropriate Traefik labels.

### 9. Environment variables (.env)

The stack uses a **`.env`** file so you can keep secrets and hostnames out of the compose file. Docker Compose loads it via `env_file: .env` and substitutes variables in `command` and `labels`.

Copy **`example.env`** to **`.env`** and set the values:

```bash
cp example.env .env
```

| Variable | Purpose |
|----------|--------|
| **`ACME_EMAIL`** | Email for Let’s Encrypt (certificate expiry and account notifications). Used by the ACME certificate resolver. **Required.** |
| **`DASHBOARD_HOST`** | Hostname for the Traefik dashboard (e.g. `traefik.example.com`). Requests to this host on HTTPS are routed to the dashboard. You must create a DNS A record for this host pointing to your VPS. |
| **`DASHBOARD_AUTH_USERS`** | Basic auth credentials for the dashboard, in the form `user:hashedpassword`. Generate the hash with: `htpasswd -nbB username password` (requires `apache2-utils`). In `.env`, use **`$$`** for each literal `$` in the hash so Docker Compose does not treat it as a variable. |

Without a valid `.env`, Traefik may fail to start or the dashboard will be unreachable. Do not commit `.env` to version control; keep `example.env` as a template.

### 10. Dashboard

The Traefik **dashboard** shows routers, services, and middlewares. It is exposed over **HTTPS only** (no port 8080) and protected with **HTTP basic auth**.

**How it’s configured (labels on the Traefik container):**

- **Router** `dashboard`: matches `Host(\`<DASHBOARD_HOST>\`)`, uses entrypoint `websecure` and TLS with `le-resolver`, and forwards to the internal API service (`api@internal`) that serves the dashboard.
- **Middleware** `dashboard-auth`: applies basic auth using the users defined in `DASHBOARD_AUTH_USERS` (format `user:hashedpassword`).
- The dashboard is served at **`/dashboard/`** (and the API at **`/api/`**) on that host.

**To use it:**

1. Set **`DASHBOARD_HOST`** and **`DASHBOARD_AUTH_USERS`** in `.env` (see [Environment variables](#9-environment-variables-env)).
2. Create a **DNS A record** for `DASHBOARD_HOST` pointing to your VPS IP (see [Configuring DNS](#configuring-dns-for-traefik)).
3. Start Traefik and open **`https://<DASHBOARD_HOST>/dashboard/`** in a browser.
4. Log in with the username and password you used when generating the `htpasswd` hash.

Because the dashboard is just another router with a host rule, it gets a Let’s Encrypt certificate like any other service and is only reachable on the hostname you set—not on every domain that hits the VPS.

---

## How routing works (summary)

1. Traefik reads Docker (containers and labels) on `traefik-net`.
2. Only containers with **`traefik.enable=true`** and valid router/service labels are exposed.
3. Each **router** ties a **Host** (and optionally path, headers) to an **entrypoint** (e.g. `websecure`) and optionally **TLS** with `certresolver=le-resolver`.
4. Each **service** points to a **Docker service/container** and port. Traefik uses the container name (or service name) on `traefik-net` to forward traffic.

Details and examples for adding new services are in **[Adding-services.md](./Adding-services.md)**.

---

## Configuring DNS for Traefik

For Traefik to route traffic to your services, the hostnames you use in router rules (e.g. `Host(\`app.client.com\`)`) must resolve to your **VPS public IP**. This section is a short tutorial on how to set that up.

### What you need

- Your **VPS public IPv4** (and optionally IPv6).
- Access to the **DNS settings** of your domain(s) at your registrar or DNS provider (Cloudflare, Route53, Namecheap, etc.).

### Basic idea

- **One VPS IP** receives all HTTP/HTTPS traffic on ports 80 and 443.
- You create **DNS records** so that each hostname (domain or subdomain) points to that same IP.
- Traefik then uses the **Host** in the request to decide which backend to use—no need for a different IP per service.

### Step 1: Get your VPS IP

On the VPS:

```bash
curl -4 -s ifconfig.me
```

Or use your provider’s control panel. For IPv6 (optional): `curl -6 -s ifconfig.me`.

### Step 2: Create A (and optionally AAAA) records

For each hostname you want to use in Traefik (e.g. `app.example.com`, `api.example.com`), create a record at your DNS provider:

| Type | Name / Host | Value / Target        | TTL (optional) |
|------|-------------|------------------------|----------------|
| A    | `app`       | `YOUR_VPS_IPv4`       | 300 or 3600    |
| A    | `api`       | `YOUR_VPS_IPv4`       | 300 or 3600    |
| AAAA | `app`       | `YOUR_VPS_IPv6`       | 300 or 3600    |

- **Name**: subdomain only. For `app.example.com` use `app`; for the root `example.com` use `@` or leave “Name” blank (depends on the provider).
- **Value**: your VPS IP. Same IP for every hostname—Traefik distinguishes by `Host` header.

Result: `app.example.com` and `api.example.com` (and any others you add) all point to your VPS.

### Step 3: Subdomains

To add a new subdomain (e.g. `client-b.example.com`):

1. Create an **A** record with name `client-b` (or the full FQDN if your provider requires it), value = VPS IP.
2. In your docker-compose labels, use `Host(\`client-b.example.com\`)`.
3. Deploy the service. No change to Traefik’s own config.

You can create as many subdomains as you need; each is just another A (and optionally AAAA) record with the same IP.

### Optional: Wildcard subdomain

If you want to use **any** subdomain of a domain without adding a record each time (e.g. `anything.example.com`):

- Create a **single** record:
  - Type: **A** (and AAAA if you use IPv6)
  - Name: **`*`** (wildcard)
  - Value: **VPS IP**

Then in Traefik you can use rules like `Host(\`client-a.example.com\`)`, `Host(\`client-b.example.com\`)`, etc. They will all resolve as long as they match `*.example.com`. Let’s Encrypt will issue certificates for each distinct hostname when Traefik first sees a request for it.

### Checklist

1. **A (and AAAA) records** for every hostname (or `*`) → VPS IP.
2. **Wait for propagation** (a few minutes to 48 hours; often under 5–10 minutes). Check with: `dig app.example.com` or `nslookup app.example.com`.
3. **Firewall**: ports **80** and **443** must be open on the VPS (Traefik listens there).
4. In your **Traefik labels**, use the **exact** hostname you configured in DNS (e.g. `Host(\`app.example.com\`)`).

Once DNS points to the VPS and the service is running with the right labels, Traefik will route and issue HTTPS certificates automatically. For adding the labels and connecting services, see **[Adding-services.md](./Adding-services.md)**.

# Traefik VPS deploy reference

Stack constants (must match [traefik-proxy](../../traefik-proxy/docker-compose.yml)):

| Constant | Value |
|----------|--------|
| Docker network | `traefik-net` (external) |
| HTTPS entrypoint | `websecure` |
| Certificate resolver | `le-resolver` |
| Traefik exposure | `traefik.enable=true` required (`exposedbydefault=false`) |

## Routing (default)

- One **public** service → one **FQDN** (subdomain) already in DNS.
- Router rule: `Host(\`<fqdn>\`)` only. No `PathPrefix` unless the user explicitly requests an exception.
- DNS: A/AAAA record → VPS IP before deploy. The compose file does not create DNS records.
- Label `Host()` must match the DNS FQDN exactly.

## Required Traefik labels (per public service)

| Label | Value |
|-------|--------|
| `traefik.enable` | `true` |
| `traefik.http.routers.<router>.rule` | `Host(\`${HOST_VAR}\`)` |
| `traefik.http.routers.<router>.entrypoints` | `websecure` |
| `traefik.http.routers.<router>.tls.certresolver` | `le-resolver` |
| `traefik.http.services.<router>.loadbalancer.server.port` | Internal container port |

- `<router>` = `{project_slug}-{service}` (unique across the whole VPS).
- Service name in labels can match router name unless you set `traefik.http.routers.<router>.service=<other>`.

## Networks

```yaml
networks:
  <project>-internal:
  traefik-net:
    external: true
```

- Public app services: `<project>-internal` + `traefik-net`.
- DB, Redis, workers: `<project>-internal` only (no Traefik labels, no `ports:` to host).

## Environment variables

- One `*_HOST` per public FQDN (e.g. `FRONTEND_HOST=app.example.com`).
- Use in labels as `Host(\`${FRONTEND_HOST}\`)`; load via `env_file: .env` on the service or project-level `.env` for compose substitution.

## Anti-patterns

- Publishing app `ports:` on the host (Traefik owns 80/443).
- App listening only on `127.0.0.1`.
- `loadbalancer.server.port` ≠ port the process listens on inside the container.
- Duplicate router names across projects on the same VPS.
- Inventing subdomains not confirmed by the user.

## Pre-deploy checklist

1. `docker network create traefik-net` (once per VPS).
2. Each FQDN has A/AAAA → VPS; `dig <host>` resolves correctly.
3. Firewall allows 80 and 443.
4. Traefik proxy stack is running.
5. `docker compose -f docker-compose.deploy.yml config` succeeds locally.

## Troubleshooting

- **502**: Wrong network, wrong internal port, or app not on `0.0.0.0`.
- **No certificate**: DNS not pointing to VPS, or wrong hostname in `Host()`.
- **Route not found**: Missing `traefik.enable`, wrong FQDN, or router name collision.

Further reading in this repo: [Deploying-new-services.md](../../traefik-proxy/Deploying-new-services.md), [How-the-proxy-works.md](../../traefik-proxy/How-the-proxy-works.md).

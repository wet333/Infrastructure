# Examples — subdomain routing

Replace FQDNs, slugs, images, and ports with values from the target project and user-confirmed DNS.

## Monolith — one service, one subdomain

`project_slug`: `acme`
FQDN: `app.acme.com` → `APP_HOST`

```yaml
version: "3.8"

services:
  web:
    image: acme/web:1.0.0
    container_name: acme-web
    restart: always
    env_file:
      - .env
    networks:
      - acme-internal
      - traefik-net
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.acme-web.rule=Host(`${APP_HOST}`)"
      - "traefik.http.routers.acme-web.entrypoints=websecure"
      - "traefik.http.routers.acme-web.tls.certresolver=le-resolver"
      - "traefik.http.services.acme-web.loadbalancer.server.port=3000"

networks:
  acme-internal:
  traefik-net:
    external: true
```

`.env.deploy.example`:

```env
APP_HOST=app.acme.com
```

## API + frontend — two subdomains

| Service | FQDN | Env var | Router | Port |
|---------|------|---------|--------|------|
| frontend | `app.acme.com` | `FRONTEND_HOST` | `acme-frontend` | 80 |
| api | `api.acme.com` | `API_HOST` | `acme-api` | 8000 |

```yaml
version: "3.8"

services:
  api:
    image: acme/api:1.0.0
    container_name: acme-api
    restart: always
    env_file:
      - .env
    networks:
      - acme-internal
      - traefik-net
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.acme-api.rule=Host(`${API_HOST}`)"
      - "traefik.http.routers.acme-api.entrypoints=websecure"
      - "traefik.http.routers.acme-api.tls.certresolver=le-resolver"
      - "traefik.http.services.acme-api.loadbalancer.server.port=8000"

  frontend:
    image: acme/frontend:1.0.0
    container_name: acme-frontend
    restart: always
    env_file:
      - .env
    networks:
      - acme-internal
      - traefik-net
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.acme-frontend.rule=Host(`${FRONTEND_HOST}`)"
      - "traefik.http.routers.acme-frontend.entrypoints=websecure"
      - "traefik.http.routers.acme-frontend.tls.certresolver=le-resolver"
      - "traefik.http.services.acme-frontend.loadbalancer.server.port=80"

  postgres:
    image: postgres:16-alpine
    container_name: acme-postgres
    restart: always
    env_file:
      - .env
    volumes:
      - acme-pg-data:/var/lib/postgresql/data
    networks:
      - acme-internal

volumes:
  acme-pg-data:

networks:
  acme-internal:
  traefik-net:
    external: true
```

Fix the duplicate networks block in real output — standalone file should declare `networks` once at the bottom. When generating, merge into a single `networks:` section.

`.env.deploy.example`:

```env
FRONTEND_HOST=app.acme.com
API_HOST=api.acme.com
POSTGRES_USER=app
POSTGRES_PASSWORD=change_me
POSTGRES_DB=app
```

## Stack with internal database only

- `postgres`, `redis`: `acme-internal` only, no labels, no host ports.
- Only `api` and `frontend` attach to `traefik-net` as in the table above.

## Path prefix (exception only)

Use only when the user explicitly rejects subdomain-per-service. Document the exception in `DEPLOY-PLAN.md`. See [test-services](../../traefik-proxy/test-services/docker-compose.yml) for lab setups — not the default production pattern.

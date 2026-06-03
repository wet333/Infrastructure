# Infrastructure

Traefik-based Docker Compose setup for multiple HTTPS apps on one VPS (`traefik-net`).

## Contents

```
VPS/
├── traefik-proxy/           # proxy + docs + test-services/
├── passwordless-ssh-setup/  # SSH key scripts + SSH-connection-setup.md
└── generate-deploy-skill/   # @vps-generate-deploy skill + dist zip
```

**Docs:** [How the proxy works](VPS/traefik-proxy/How-the-proxy-works.md) · [Deploy a service](VPS/traefik-proxy/Deploying-new-services.md) · [SSH setup](VPS/passwordless-ssh-setup/SSH-connection-setup.md) · [Deploy skill](VPS/generate-deploy-skill/README.md)

**Traefik:** `docker network create traefik-net` (once) → `example.env` → `.env` in `VPS/traefik-proxy/` → `docker compose up -d`

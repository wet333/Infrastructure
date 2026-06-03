# Generate deploy skill

Cursor / Claude Code skill **`vps-generate-deploy`** that analyzes a project and produces a standalone **`docker-compose.deploy.yml`** for deployment on a VPS behind [Traefik](../traefik-proxy/).

## Features

- Four-phase workflow: discovery → plan → user validation → generation
- Subdomain routing (`Host(\`fqdn\`)`) with DNS confirmed by the user
- Compatible with `traefik-net`, `websecure`, `le-resolver`
- Portable install via zip

## Quick start

**Use the skill**: `@vps-generate-deploy` in Cursor or Claude Code after installation.

**Install**: see [INSTALL.md](./INSTALL.md).

**Rebuild zip**:

```bash
./package.sh
```

Artifact: [`dist/vps-generate-deploy.zip`](./dist/vps-generate-deploy.zip)

## Layout

```
generate-deploy-skill/
├── README.md
├── INSTALL.md
├── package.sh
├── dist/
│   └── vps-generate-deploy.zip
└── vps-generate-deploy/
    ├── SKILL.md
    ├── reference.md
    ├── examples.md
    ├── INSTALL.txt
    └── templates/
```

## Output in target projects

The skill generates (in the user's application repo):

| File | Purpose |
|------|---------|
| `DEPLOY-PLAN.md` | Plan after phases 1–3 |
| `docker-compose.deploy.yml` | Standalone production stack |
| `.env.deploy.example` | Hostnames and config template |
| `DEPLOY.md` | Optional runbook |

## Prerequisites on the VPS

- Traefik proxy running ([traefik-proxy](../traefik-proxy/))
- `docker network create traefik-net`
- DNS A/AAAA records for each subdomain → VPS IP

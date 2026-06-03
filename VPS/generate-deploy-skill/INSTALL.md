# Install `vps-generate-deploy`

Agent skill to generate `docker-compose.deploy.yml` for Traefik VPS deploys (subdomain routing, `traefik-net`).

## Option A — Zip (other machines)

1. Get `dist/vps-generate-deploy.zip` from this repo (or run `./package.sh`).

2. Install for Cursor:

```bash
mkdir -p ~/.cursor/skills
unzip -o /path/to/vps-generate-deploy.zip -d ~/.cursor/skills/
```

3. Install for Claude Code:

```bash
mkdir -p ~/.claude/skills
unzip -o /path/to/vps-generate-deploy.zip -d ~/.claude/skills/
```

4. Verify:

```bash
test -f ~/.cursor/skills/vps-generate-deploy/SKILL.md && echo OK
test -f ~/.claude/skills/vps-generate-deploy/SKILL.md && echo OK
```

5. Restart the editor or open a new agent chat. Invoke: `@vps-generate-deploy`

## Option B — Symlink from git clone (development)

```bash
REPO="/path/to/Infrastructure/VPS/generate-deploy-skill/vps-generate-deploy"
mkdir -p ~/.cursor/skills ~/.claude/skills
ln -sf "$REPO" ~/.cursor/skills/vps-generate-deploy
ln -sf "$REPO" ~/.claude/skills/vps-generate-deploy
```

## Option C — Rebuild the zip

From this directory:

```bash
cd VPS/generate-deploy-skill
chmod +x package.sh
./package.sh
```

Output: `dist/vps-generate-deploy.zip`

## Zip layout

The archive root must be the folder `vps-generate-deploy/`:

```
vps-generate-deploy/
├── SKILL.md
├── reference.md
├── examples.md
├── INSTALL.txt
└── templates/
    └── docker-compose.deploy.yml.template
```

## Uninstall

```bash
rm -rf ~/.cursor/skills/vps-generate-deploy
rm -rf ~/.claude/skills/vps-generate-deploy
```

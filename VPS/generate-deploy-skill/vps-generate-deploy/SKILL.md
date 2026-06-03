---
name: vps-generate-deploy
description: >
  Analiza un proyecto y genera docker-compose.deploy.yml standalone para desplegar
  en un VPS con Traefik (traefik-net, le-resolver), ruteo por subdominios DNS.
  Usar cuando el usuario pida deploy VPS, compose de producción, Traefik, subdominios,
  o docker-compose.deploy.yml.
disable-model-invocation: true
---

# VPS Generate Deploy

Genera `docker-compose.deploy.yml` standalone para proyectos que se despliegan detrás del Traefik proxy de este repositorio ([traefik-proxy](../../traefik-proxy/)).

**Invocación**: `@vps-generate-deploy` o pedir deploy VPS / Traefik / `docker-compose.deploy.yml`.

**Regla de parada**: No pasar a la siguiente fase sin completar la anterior. No generar YAML hasta terminar Fase 3 con acuerdo del usuario.

## Contrato Traefik (resumen)

| Item | Valor |
|------|--------|
| Red | `traefik-net` external |
| Entrypoint | `websecure` |
| Cert resolver | `le-resolver` |
| Ruteo default | `Host(\`<fqdn>\`)` — un subdominio por servicio público |

Detalle: [reference.md](reference.md). Ejemplos: [examples.md](examples.md). Plantilla: [templates/docker-compose.deploy.yml.template](templates/docker-compose.deploy.yml.template).

---

## Fase 1 — Descubrimiento (solo lectura)

Trabajar en el **proyecto objetivo** (el repo del usuario, no solo Infrastructure).

### Escanear

- `docker-compose*.yml`, `compose*.yml`, `Dockerfile*`
- `.env.example`, `.env.sample`, `README`
- Manifiestos relevantes (`package.json`, `pyproject.toml`, etc.)

### Por cada servicio documentar

| Campo | Notas |
|-------|--------|
| Nombre | Nombre del servicio en compose |
| Imagen / build | Preferir `image:` con tag en producción |
| Puerto interno | Puerto donde escucha el proceso **dentro** del contenedor |
| `ports:` publicados | En deploy producción normalmente se eliminan |
| `depends_on`, volúmenes | Incluir en standalone |
| Rol | `public` (Traefik) o `internal` (solo red privada) |

### Clasificación

- **Public**: HTTP/API, frontend, websockets expuestos al usuario final.
- **Internal**: DB, Redis, colas, workers, migraciones one-off.

### Conflictos a reportar

- Bind `127.0.0.1` only
- Puertos host innecesarios en producción
- Posible colisión de nombres de router en el VPS (mismo slug que otro proyecto)

### Salida obligatoria: `DEPLOY-PLAN.md`

Crear en la raíz del proyecto objetivo (o solo en chat si el usuario no quiere archivo):

```markdown
# Deploy plan — <project_name>

## Services

| Service | Role | Internal port | Public | Networks |
|---------|------|---------------|--------|----------|

## Subdomain routing (DNS must exist before deploy)

| Service | FQDN (TBD until Phase 3) | Env var | Router name |
|---------|--------------------------|---------|-------------|

## Networks
- `<project_slug>-internal`
- `traefik-net` (external)

## Images / build strategy

## Volumes

## Deploy command
docker compose -f docker-compose.deploy.yml --env-file .env up -d
```

No inventar FQDN en Fase 1; dejar TBD hasta Fase 3.

---

## Fase 2 — Plan inicial

Redactar o actualizar `DEPLOY-PLAN.md` **sin escribir** `docker-compose.deploy.yml` aún.

Incluir:

1. Lista completa de servicios en el compose standalone (apps + dependencias).
2. Mapa 1:1 **servicio público ↔ subdominio FQDN** (placeholders hasta confirmación).
3. `project_slug` propuesto (kebab-case, único en el VPS, prefijo de routers).
4. Por cada router: `{project_slug}-{service}` y regla `Host(\`...\`)`.
5. Variables `*_HOST` en `.env.deploy.example`.
6. Estrategia `image:` vs `build:` en el VPS.
7. Middlewares solo si el usuario los pidió (p. ej. security-headers); **no** path/stripprefix por defecto.
8. Checklist DNS: A/AAAA → VPS, propagación, puertos 80/443.

Presentar el plan al usuario y anunciar que la Fase 3 validará subdominios y DNS.

---

## Fase 3 — Validación con el usuario

**Detener aquí.** Usar `AskQuestion` (o preguntas claras en chat) antes de generar archivos.

Preguntas mínimas:

1. **`project_slug`**: prefijo único de routers (ej. `myshop`).
2. **Subdominios**: lista de FQDN **ya creados** en el proveedor DNS.
3. **Mapeo**: qué servicio responde en cada FQDN.
4. **DNS listo**: ¿cada FQDN tiene A/AAAA al VPS y propagó? (por host).
5. **Servicios internos**: confirmar qué no lleva Traefik.
6. **Imágenes**: registry/tags o build en VPS.
7. **Secretos**: variables requeridas; confirmar que `.env` no se commitea.

Si el usuario pide ruteo por `PathPrefix`, documentar como **excepción** en `DEPLOY-PLAN.md` y seguir [examples.md](examples.md) anexo.

Si hay cambios, volver a Fase 2, actualizar `DEPLOY-PLAN.md`, y reconfirmar.

---

## Fase 4 — Generación y validación

Generar en el **proyecto objetivo**:

### 1. `docker-compose.deploy.yml`

- `version: "3.8"`
- `restart: always` en servicios de larga duración
- Red `<project_slug>-internal` + `traefik-net: external: true`
- Servicios públicos: ambas redes + labels Traefik
- Servicios internos: solo red interna; sin `ports:` al host
- Labels por servicio público:

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.<router>.rule=Host(`${<HOST_VAR>}`)"
  - "traefik.http.routers.<router>.entrypoints=websecure"
  - "traefik.http.routers.<router>.tls.certresolver=le-resolver"
  - "traefik.http.services.<router>.loadbalancer.server.port=<internal_port>"
```

- `<router>` = `{project_slug}-{service}`
- Sin `ports:` en apps (Traefik usa 80/443 en el host)
- Orden de campos según convención del repo: image, container_name, restart, env_file, volumes, networks, labels
- 2 espacios de indentación

### 2. `.env.deploy.example`

- Una variable por FQDN: `FRONTEND_HOST=app.example.com`
- Credenciales DB y demás vars sin valores reales

### 3. `DEPLOY.md` (opcional, breve)

- `docker network create traefik-net` si falta
- `cp .env.deploy.example .env` y editar
- `docker compose -f docker-compose.deploy.yml --env-file .env up -d`
- Enlace a troubleshooting 502 / certificados en [reference.md](reference.md)

### Validación obligatoria

```bash
docker compose -f docker-compose.deploy.yml config
```

Si falla, corregir y repetir hasta éxito.

### Checklist final

- [ ] Cada FQDN confirmado por el usuario = registro DNS al VPS
- [ ] `Host()` en labels coincide exactamente con FQDN
- [ ] Servicios públicos en `traefik-net`
- [ ] App escucha en `0.0.0.0`
- [ ] `loadbalancer.server.port` = puerto interno correcto
- [ ] Nombres de router únicos en el VPS
- [ ] `docker compose config` OK

---

## Alcance excluido

- No ejecutar deploy en el VPS
- No modificar el stack Traefik del servidor
- No commitear `.env` con secretos
- No middlewares avanzados salvo petición explícita en Fase 3

---

## Recursos

- [reference.md](reference.md) — constantes, labels, anti-patrones
- [examples.md](examples.md) — monolito, API+frontend
- [INSTALL.txt](INSTALL.txt) — instalación del skill en otra máquina

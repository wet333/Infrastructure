# Cómo probar los servicios de test

## 1. Configurar el ENV

Copia la plantilla y define el host que usarás para estos servicios (debe tener DNS apuntando al VPS):

```bash
cp example.env .env
```

Edita `.env` y asigna tu dominio o subdominio:

```
TEST_HOST=test.tudominio.com
```

## 2. Requisitos

- Traefik debe estar levantado (desde la carpeta `traefik-proxy`).
- La red `traefik-net` debe existir. Si no:
  ```bash
  docker network create traefik-net
  ```

## 3. Levantar los servicios

En esta carpeta (`test-services`):

```bash
docker-compose up -d
```

## 4. Cómo ingresar

| Servicio | URL |
|----------|-----|
| Nginx (HTML de prueba) | `https://<TEST_HOST>/` |
| Whoami | `https://<TEST_HOST>/whoami/` |

Abre esas URLs en el navegador. La primera vez Let's Encrypt puede tardar unos segundos en emitir el certificado.

Para bajar los servicios:

```bash
docker-compose down
```

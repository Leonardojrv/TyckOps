# Cifrado de datos en TyckOps

Todo lo que viaja entre la app, el backend y la base de datos va cifrado con TLS (el mismo cifrado de HTTPS). Este documento explica qué está cifrado, qué tienes que hacer tú después del `git pull` y qué hacer si algo no conecta.

```
App Flutter ──(1) HTTPS──► Backend Node ──(2) SSL/TLS──► PostgreSQL
```

| Tramo | En tu computador | En producción |
|---|---|---|
| (2) Backend → PostgreSQL | **Cifrado y obligatorio** (certificado autofirmado que genera Docker) | **Cifrado y obligatorio** (certificado del proveedor) |
| (1) App → Backend | HTTP (el tráfico no sale de tu computador o tu wifi) | **HTTPS obligatorio** |

---

## Para colaboradores: qué hacer después del `git pull`

Solo una vez:

```bash
cd database
docker compose up -d
```

Docker crea un contenedor corto llamado `postgres_certificados`, que genera el certificado y luego termina. Después recrea `postgres_db` con SSL activado.

- **Tus datos no se pierden**: siguen en el volumen `pgdata`.
- **No tienes que editar ningún `.env`**: el backend agrega `sslmode=require` solo, y Prisma (migraciones, seed, Studio) usa SSL automáticamente cuando el servidor lo ofrece.
- **No necesitas instalar `openssl`** ni nada más.
- La primera vez necesita internet: el contenedor de certificados descarga `openssl` dentro de Docker.

### Comprobar que quedó cifrado

```bash
docker exec postgres_db sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atc "SHOW ssl"'
```

Tiene que responder `on`. Luego levanta el backend (`pnpm dev` en `backend/`) y abre `http://localhost:3000/salud`: debe decir `"database":"connected"`.

Para ver que tus conexiones van cifradas, con el backend corriendo:

```bash
docker exec postgres_db sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atc "SELECT ssl, version FROM pg_stat_ssl JOIN pg_stat_activity USING (pid) WHERE client_addr IS NOT NULL"'
```

Cada fila debe decir `t|TLSv1.3` (o `TLSv1.2`).

---

## Problemas frecuentes

**El log del backend dice `db_conexion_fallida` con la pista "La base de datos no aceptó la conexión cifrada"**
Tu contenedor sigue con la configuración antigua. Ejecuta `docker compose up -d` en `database/`.

**`/salud` dice `"database":"disconnected"` y el backend usa usuarios de demostración**
Es lo mismo de arriba: en desarrollo, si no conecta a PostgreSQL, el backend sigue con datos en memoria. Revisa el log en la consola o en `backend/logs/`.

**Error `DATABASE_URL usa sslmode=disable` (o `prefer`) al iniciar el backend**
Tu `backend/.env` trae un `sslmode` que permite conectarse sin cifrar. Bórralo de la URL (el backend pone `require` solo) o cámbialo a `sslmode=require`.

**pgAdmin, DBeaver u otro cliente no conecta**
En la configuración de la conexión, pestaña SSL, elige `require`. El certificado es autofirmado, así que no actives "verificar certificado".

**`docker compose up -d` falla en `postgres_certificados`**
Mira el detalle con `docker logs postgres_certificados`. Casi siempre es falta de internet en la primera ejecución. Vuelve a intentarlo con conexión.

**Quiero regenerar el certificado**
Borra solo el volumen de certificados (los datos no se tocan):

```bash
docker compose down
docker volume rm database_pgcerts
docker compose up -d
```

---

## Para quien despliegue a producción

1. **Base de datos**: usa un PostgreSQL con SSL (Supabase, Neon, Render, Railway y similares ya lo traen activado). En la `DATABASE_URL` de producción pon `sslmode=require` o déjalo sin `sslmode` y el backend lo agrega. Con `disable` o `prefer` el backend no arranca.
   - Más estricto (opcional): para verificar también que el servidor es quien dice ser, agrega `&sslaccept=strict&sslcert=<ruta al certificado CA del proveedor>`.
   - Las migraciones (`npx prisma migrate deploy` en `database/BaseDatos`) contra producción también deben llevar `sslmode=require` en su `.env`.
2. **Backend**: debe quedar detrás del HTTPS del hosting o de un proxy (Nginx con Let's Encrypt, por ejemplo). Con `NODE_ENV=production` el backend:
   - rechaza con `403 HTTPS_REQUERIDO` toda solicitud que no llegue por https (salvo `/salud`);
   - confía en **un** proxy delante para leer `X-Forwarded-Proto` y la IP real;
   - envía HSTS (lo hace `helmet`).
3. **App**: compila con una URL https:
   ```bash
   flutter build apk --dart-define=API_BASE_URL=https://tu-dominio/api
   ```
   Una versión release con una URL `http://` se detiene al abrir, a propósito. Android en release además bloquea HTTP por su cuenta.

---

## Cómo funciona por dentro

- `database/docker-compose.yml`:
  - el servicio `certificados` genera `server.crt` y `server.key` (válidos 10 años) en el volumen `pgcerts`;
  - escribe un `pg_hba.conf` que solo permite conexiones de red con SSL (`hostssl`) y rechaza las demás (`hostnossl ... reject`);
  - `postgres_db` arranca con `ssl=on` y esos archivos.
- `backend/src/config/env.js` → `conSslObligatorio()`: agrega `sslmode=require` a la `DATABASE_URL` si falta y rechaza cualquier otro valor.
- `backend/src/middlewares/exigirHttps.js`: rechaza http en producción.
- `mobile/lib/core/network/api_config.dart` → `validarCifrado()`: la release exige https.

Los certificados viven solo en el volumen de Docker de cada uno. Nunca se suben a git (además, `*.key` y `*.pem` ya están en `.gitignore`).

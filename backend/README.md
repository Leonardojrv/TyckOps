# TyckOps backend

API REST para la app móvil TyckOps. Requiere Node.js 20 o superior y pnpm.

## Desarrollo

```sh
cp .env.example .env
pnpm install
pnpm dev
```

`GET /salud` responde aunque PostgreSQL todavía no esté disponible e indica el estado de conexión. En desarrollo, si PostgreSQL no está disponible, el login usa dos cuentas de demostración en memoria.

## Prisma y login

El schema de Prisma pertenece al equipo de base de datos y aún no está en este repositorio. Cuando esté disponible en `prisma/schema.prisma`, configura `DATABASE_URL` y ejecuta `pnpm prisma:generate`.

El adaptador de login espera provisionalmente el modelo `User`, con `id`, `name`, `email`, `passwordHash`, `role`, `area`, `termsAccepted` e `isFirstLogin`; `email` debe ser único. Confirma los nombres y los valores del enum `role` con Leonardo antes de conectar la BD. Los roles de la API son `COLABORADOR` y `ADMINISTRADOR`.

`POST /api/auth/login` recibe `{ "email": "...@gamaitaly.cl", "password": "..." }` y devuelve `{ "success": true, "data": { "token": "...", "user": { ... } } }`. Envía el token en `Authorization: Bearer <token>` para rutas protegidas. La clave JWT debe ser aleatoria y privada; nunca subas `.env`.

`GET /api/auth/me` requiere `Authorization: Bearer <token>` y devuelve `{ "success": true, "data": { "user": { "id": "...", "name": "...", "email": "...", "role": "COLABORADOR|ADMINISTRADOR", "area": null, "termsAccepted": true, "isFirstLogin": false } } }`. Responde `401` si falta el token, está vencido/no es válido o el usuario ya no existe. La app móvil debe llamar a esta ruta al iniciar, usando el token guardado, y restaurar su sesión con `data.user`.

`POST /api/auth/primer-acceso` (RF-02) requiere `Authorization: Bearer <token>`. Con `{ "currentPassword": "...", "newPassword": "..." }` cambia la contraseña temporal (mínimo 8 caracteres con letras y números); con `{}` mantiene la actual. En ambos casos responde `{ "success": true, "data": { "user": { ..., "isFirstLogin": false } } }`. Errores: `400 CONTRASENA_ACTUAL_INCORRECTA`, `400 CONTRASENA_REPETIDA`, `409 PRIMER_ACCESO_COMPLETADO` y `429 DEMASIADOS_INTENTOS` (5 intentos cada 15 minutos). En desarrollo, la cuenta demo del colaborador parte con `isFirstLogin: true`.

Las cuentas de demostración se configuran con `DEMO_WORKER_EMAIL`, `DEMO_WORKER_PASSWORD`, `DEMO_ADMIN_EMAIL` y `DEMO_ADMIN_PASSWORD` en `.env`. Se almacenan solo en memoria, las contraseñas se hashean con bcrypt al iniciar, y no se habilitan como fallback en producción. La auditoría escribe eventos JSON de éxito y rechazo en los logs (ver «Logs de transacciones»); no registra contraseñas.

Ejemplo Postman en desarrollo:

```http
POST http://localhost:3000/api/auth/login
Content-Type: application/json

{"email":"colaborador@gamaitaly.cl","password":"DemoWorker2026!"}
```

Para el administrador usa `admin@gamaitaly.cl` y `DemoAdmin2026!`. Cambia estas claves de demostración antes de usar el entorno fuera de desarrollo.

Para probar la restauración, inicia sesión y copia `data.token`. En Postman crea un `GET` a `http://localhost:3000/api/auth/me`, selecciona **Authorization → Bearer Token**, pega el token y envía la solicitud. El usuario debe coincidir con `data.user` del login. Si quitas el token o usas uno vencido, debe responder `401`.

### Ruta protegida de ejemplo

`GET http://localhost:3000/api/admin/ejemplo` requiere un token vigente de administrador. En Postman, inicia sesión con la cuenta deseada, copia `data.token` de la respuesta y configúralo en la solicitud como **Authorization → Bearer Token**. El colaborador debe recibir `403` con `SIN_ROL_ADMIN`; el administrador debe recibir `200`. Sin token o con un token inválido/expirado, la respuesta es `401`.

### Reportes con fotos

El móvil usa `POST /api/tickets` (o su alias `POST /api/tickets/reparaciones`) en `multipart/form-data`, con una foto opcional en el campo `foto`. La imagen puede pesar hasta 5 MB y se acepta JPG/PNG según su firma real; antes de guardarla se le quitan los metadatos (EXIF, GPS). Las categorías aceptan `electrica`, `banos`, `aire_acondicionado` y `mobiliario`/`inmobiliario` (también los códigos en mayúsculas que usa el móvil).

La foto se guarda en la columna `imagen` (BYTEA) del propio ticket, en la misma operación que lo crea: no puede quedar un ticket sin su foto ni una foto sin ticket. Los listados y el detalle no incluyen la imagen; para obtenerla usa `GET /api/tickets/:id/foto`, que la devuelve como `image/jpeg` o `image/png`. Requiere Bearer token, rol colaborador y términos aceptados, y solo el dueño del ticket puede verla (404 `TICKET_NO_ENCONTRADO` si no es suyo o no existe; 404 `FOTO_NO_ENCONTRADA` si no tiene foto).


## Cliente Groq

El backend crea una sola instancia de `ClienteGroq` al iniciar y la expone a los módulos mediante `app.locals.groqClient`. No llama al proveedor durante el arranque. Configura `GROQ_API_KEY`, `GROQ_MODEL`, `GROQ_REASONING_EFFORT` y `GROQ_TIMEOUT_MS` en `backend/.env`; nunca pongas la clave real en `.env.example` ni la subas a Git. Para `openai/gpt-oss-20b`, `GROQ_REASONING_EFFORT=low` envía `reasoning_effort: "low"`. `ClienteGroq.completar({ messages, reasoningEffort, temperature, maxTokens, responseFormat })` usa Chat Completions; devuelve el texto o lanza un `GroqApiError`. Los 429 se mapean a `GROQ_RATE_LIMITED` con `retryAfterMs` cuando Groq envía `Retry-After`; el cliente no reintenta automáticamente.

Las pruebas del cliente usan `fetch` simulado, no consumen cuota de Groq y corren con `pnpm test`.

## Logs de transacciones

El backend usa winston (`src/config/logger.js`) y escribe un JSON por línea en `backend/logs/`:

- `transacciones-AAAA-MM-DD.log`: cada solicitud HTTP, accesos (login, primer acceso, Términos), tickets y su paso por la IA.
- `errores-AAAA-MM-DD.log`: solo errores.

Los archivos se borran solos después de `LOG_RETENCION_DIAS` (30 por defecto). Contraseñas, tokens y llaves salen como `[OCULTO]`, las fotos como `[OMITIDO]` y los correos enmascarados (`ca***@gamaitaly.cl`). La carpeta está en `.gitignore`. Durante las pruebas no se escribe nada.

Para registrar una acción nueva, una línea donde ocurre, con IDs y resultado (nunca el contenido):

```js
logger.info('ticket_aprobado', { tipo: 'ticket', ticketId, adminId, estadoAnterior, estadoNuevo });
```

## Cifrado

La conexión a PostgreSQL siempre va cifrada: el backend agrega `sslmode=require` a la `DATABASE_URL` si falta y rechaza `disable` o `prefer`. En producción además exige HTTPS (detrás del proxy del hosting). Detalles, instrucciones para el equipo y despliegue en [`../database/CIFRADO.md`](../database/CIFRADO.md).


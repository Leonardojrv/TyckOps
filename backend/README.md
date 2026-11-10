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

Las cuentas de demostración se configuran con `DEMO_WORKER_EMAIL`, `DEMO_WORKER_PASSWORD`, `DEMO_ADMIN_EMAIL` y `DEMO_ADMIN_PASSWORD` en `.env`. Se almacenan solo en memoria, las contraseñas se hashean con bcrypt al iniciar, y no se habilitan como fallback en producción. La auditoría escribe eventos JSON de éxito y rechazo a la salida del servidor; no registra contraseñas.

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

## Pruebas

```sh
pnpm test
```

## Salud

`GET /salud` devuelve HTTP 200 con `success`, el estado del servicio y `database` (`connected`, `disconnected` o `not_configured`).

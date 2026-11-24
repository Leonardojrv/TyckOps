# Firebase y notificaciones push (T11)

Guía para que cada integrante del equipo tenga funcionando las notificaciones
push en su computador. **Sin estos archivos nada se rompe**: la app compila y
funciona (sin push) y el servidor arranca con el envío en modo simulado.

## 1. Lo que llega por GitHub (código y base de datos)

Después de `git pull` en `main`, con Docker abierto:

```powershell
cd database/BaseDatos; npx prisma migrate deploy   # crea DispositivoPush y Notificacion (no borra datos)
cd ../../backend; pnpm install; pnpm prisma:generate  # instala firebase-admin y actualiza Prisma
cd ../mobile; flutter pub get                         # paquetes de Firebase para la app
```

## 2. Los 3 archivos de Firebase (NO van por GitHub)

Están en `.gitignore` a propósito. Nunca los subas ni los mandes por WhatsApp,
correo, Discord o Drive.

| Archivo | Dónde va | ¿Secreto? | Quién lo necesita |
|---|---|---|---|
| `google-services.json` | `mobile/android/app/` | Bajo | Quien compile la app Android |
| `GoogleService-Info.plist` | `mobile/ios/Runner/` | Bajo | Solo quien compile en Mac |
| `firebase-service-account.json` | `backend/` | **Sí, muy secreto** | Solo quien levante el servidor |

### Cómo obtenerlos (recomendado: cada uno los descarga)

1. Pide que te agreguen al proyecto: Consola de Firebase → ⚙️ **Configuración del
   proyecto** → **Usuarios y permisos** → **Agregar miembro** (Editor para backend,
   Visualizador para el resto).
2. Entra al proyecto `tyckops` → *Configuración del proyecto* → *Tus apps* y
   descarga `google-services.json` (y `GoogleService-Info.plist` si tienes Mac).
   Paquete de la app: `cl.gamaitaly.tyckops`.
3. Si levantas el servidor, genera **tu propia** clave: *Cuentas de servicio* →
   **Generar nueva clave privada** → guárdala como `backend/firebase-service-account.json`.
   Una clave por persona: si alguien deja el equipo, se borra solo la suya.

Si de todas formas hay que compartir la clave del servidor, usar un enlace que
se autodestruya (por ejemplo **Bitwarden Send**, 1 día y 1 acceso). Si se filtra:
*Cuentas de servicio* → *Administrar claves* → borrarla y generar otra.

### ¿Cómo sé que funciona?

- Servidor: al arrancar, el log dice `push_firebase_activo` (o `push_modo_simulado`
  si falta la clave).
- App: al iniciar sesión como colaborador pide permiso de notificaciones y el
  celular aparece en la tabla `DispositivoPush`.
- El emulador debe tener **Google Play** (imagen "Google APIs/Play Store").

## 3. iOS

El código y la configuración (`UIBackgroundModes`) ya están. Para que el push
llegue a un iPhone hace falta un Mac, una cuenta de Apple Developer y subir la
clave **APNs (.p8)** en Firebase → *Configuración del proyecto* → *Cloud Messaging*.
En Xcode: *Signing & Capabilities* → agregar **Push Notifications** y
**Background Modes → Remote notifications**.

## 4. Contraseñas del `.env`

Tampoco van a GitHub. Copia `.env.example` a `.env` en `backend/` y en
`database/BaseDatos/` y pon tus valores. La variable opcional
`FIREBASE_SERVICE_ACCOUNT` permite indicar otra ruta para la clave del servidor.

## 5. Cómo probar el push (administrador)

- `PATCH /api/admin/tickets/:id/estado` con `{ "estado": "EN_REVISION" }`
  → el dueño recibe "Ticket #REP-XXXX pasó a …".
- `POST /api/admin/tickets/:id/comentarios` con `{ "texto": "…" }`
  → el dueño recibe "Nuevo comentario en tu ticket" y, al tocarlo, se abre el
  ticket con los comentarios a la vista.

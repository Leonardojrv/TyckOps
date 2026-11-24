// ¿PARA QUÉ SIRVE?
//   Son las "puertas" del servidor para las notificaciones del colaborador (T11).
//
// ¿QUÉ HACE?
//   - POST   /api/notificaciones/dispositivos  → guarda el token push de este celular.
//   - DELETE /api/notificaciones/dispositivos  → lo quita (al cerrar sesión).
//   - GET    /api/notificaciones               → tus avisos y cuántos faltan por leer.
//   - POST   /api/notificaciones/:id/leida     → marca uno como leído.
//   - POST   /api/notificaciones/leidas        → marca todos como leídos.
//   Todas exigen sesión completa y Términos aceptados; el dueño sale del token.
//
// ¿CÓMO LO CAMBIO?
//   La lógica está en notificaciones.service.js. Si agregas una ruta, deja los
//   controles de arriba (autenticar y exigirTerminos).

import { Router } from 'express';
import rateLimit from 'express-rate-limit';
import { z } from 'zod';
import { autenticar } from '../../middlewares/autenticar.js';
import { exigirTerminos } from '../../middlewares/exigirTerminos.js';
import { requerirRol } from '../../middlewares/requerirRol.js';
import { HttpError } from '../../utils/http-error.js';
import { responder } from '../../utils/respuestas.js';

// Los tokens de Firebase solo traen letras, números y : _ - (la BD lo revisa igual).
const dispositivoSchema = z.object({
  token: z.string().trim().regex(/^[A-Za-z0-9:_-]{20,512}$/, 'Token de dispositivo inválido.'),
  plataforma: z.enum(['android', 'ios'], { errorMap: () => ({ message: 'Plataforma inválida.' }) }),
});
const quitarSchema = dispositivoSchema.pick({ token: true });

function validar(schema, body) {
  const datos = schema.safeParse(body ?? {});
  if (!datos.success) throw new HttpError(400, 'DATOS_INVALIDOS', datos.error.issues[0]?.message ?? 'Revisa los datos enviados.');
  return datos.data;
}

export function crearRutasNotificaciones({ notificacionesService, authService, jwtSecret }) {
  const router = Router();
  router.use(autenticar(jwtSecret), exigirTerminos(authService), requerirRol('COLABORADOR', 'ADMINISTRADOR'));
  router.use((_req, _res, next) => next(notificacionesService
    ? undefined
    : new HttpError(503, 'NOTIFICACIONES_NO_DISPONIBLES', 'Las notificaciones aún no están disponibles.')));

  // Un celular registra su token al iniciar sesión o cuando Firebase lo renueva:
  // con 30 por hora sobra y evita que alguien llene la tabla.
  const limiterDispositivos = rateLimit({
    windowMs: 60 * 60 * 1000,
    limit: 30,
    keyGenerator: (req) => `usuario:${req.usuario.id}`,
    standardHeaders: true,
    legacyHeaders: false,
    message: { success: false, error: { code: 'DEMASIADOS_INTENTOS', message: 'Espera un momento e inténtalo de nuevo.' } },
  });

  router.post('/dispositivos', limiterDispositivos, async (req, res) => {
    const { token, plataforma } = validar(dispositivoSchema, req.body);
    await notificacionesService.registrarDispositivo(req.usuario.id, token, plataforma);
    responder(res, { registrado: true }, 201);
  });

  router.delete('/dispositivos', limiterDispositivos, async (req, res) => {
    const { token } = validar(quitarSchema, req.body);
    await notificacionesService.quitarDispositivo(req.usuario.id, token);
    responder(res, { quitado: true });
  });

  router.get('/', async (req, res) => {
    responder(res, await notificacionesService.listar(req.usuario.id));
  });

  router.post('/leidas', async (req, res) => {
    responder(res, { marcadas: await notificacionesService.marcarLeidas(req.usuario.id) });
  });

  router.post('/:id/leida', async (req, res) => {
    if (!/^\d{1,12}$/.test(req.params.id)) throw new HttpError(404, 'NOTIFICACION_NO_ENCONTRADA', 'No encontramos ese aviso.');
    responder(res, { marcadas: await notificacionesService.marcarLeidas(req.usuario.id, req.params.id) });
  });

  return router;
}

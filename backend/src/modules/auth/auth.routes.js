import { Router } from 'express';
import rateLimit from 'express-rate-limit';
import { autenticar } from '../../middlewares/autenticar.js';
import { exigirTerminos } from '../../middlewares/exigirTerminos.js';
import { validar } from '../../middlewares/validar.js';
import { HttpError } from '../../utils/http-error.js';
import { responder } from '../../utils/respuestas.js';
import { loginSchema, primerAccesoSchema } from './auth.schema.js';

// Máximo 5 intentos cada 15 minutos (frena ataques de fuerza bruta).
function limitarIntentos() {
  return rateLimit({
    windowMs: 15 * 60 * 1000,
    limit: 5,
    standardHeaders: true,
    legacyHeaders: false,
    message: {
      success: false,
      error: { code: 'DEMASIADOS_INTENTOS', message: 'Espera antes de volver a intentar.' },
    },
  });
}

export function crearRutasAuth({ authService, jwtSecret }) {
  const router = Router();
  const limiterLogin = limitarIntentos();
  const limiterPrimerAcceso = limitarIntentos();

  router.post('/login', limiterLogin, validar(loginSchema), async (req, res) => {
    if (!authService) {
      throw new HttpError(503, 'AUTENTICACION_NO_DISPONIBLE', 'La base de datos aún no está conectada.');
    }
    responder(res, await authService.login(req.body, {
      ip: req.ip,
      userAgent: req.get('user-agent')?.slice(0, 512),
    }));
  });

  router.get('/me', autenticar(jwtSecret), async (req, res) => {
    if (!authService) {
      throw new HttpError(503, 'AUTENTICACION_NO_DISPONIBLE', 'La base de datos aún no está conectada.');
    }
    responder(res, { user: await authService.getCurrentUser(req.usuario.id) });
  });

  // RF-02: cambiar la contraseña temporal o mantenerla (T3).
  router.post(
    '/primer-acceso',
    autenticar(jwtSecret),
    limiterPrimerAcceso,
    validar(primerAccesoSchema),
    async (req, res) => {
      if (!authService) {
        throw new HttpError(503, 'AUTENTICACION_NO_DISPONIBLE', 'La base de datos aún no está conectada.');
      }
      const user = await authService.completeFirstAccess(req.usuario.id, req.body, {
        ip: req.ip,
        userAgent: req.get('user-agent')?.slice(0, 512),
      });
      responder(res, { user });
    },
  );

  router.get('/sesion', autenticar(jwtSecret), exigirTerminos(authService), (req, res) => {
    responder(res, { userId: req.usuario.id, role: req.usuario.role });
  });

  return router;
}
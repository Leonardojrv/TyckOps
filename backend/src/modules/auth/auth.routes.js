import { Router } from 'express';
import rateLimit from 'express-rate-limit';
import { autenticar } from '../../middlewares/autenticar.js';
import { validar } from '../../middlewares/validar.js';
import { HttpError } from '../../utils/http-error.js';
import { responder } from '../../utils/respuestas.js';
import { loginSchema } from './auth.schema.js';

export function crearRutasAuth({ authService, jwtSecret }) {
  const router = Router();
  const limiterLogin = rateLimit({
    windowMs: 15 * 60 * 1000,
    limit: 5,
    standardHeaders: true,
    legacyHeaders: false,
    message: {
      success: false,
      error: { code: 'DEMASIADOS_INTENTOS', message: 'Espera antes de volver a intentar.' },
    },
  });

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

  router.get('/sesion', autenticar(jwtSecret), (req, res) => {
    responder(res, { userId: req.usuario.id, role: req.usuario.role });
  });

  return router;
}
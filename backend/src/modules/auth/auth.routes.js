import { Router } from 'express';
import rateLimit from 'express-rate-limit';
import { autenticar } from '../../middlewares/autenticar.js';
import { exigirTerminos } from '../../middlewares/exigirTerminos.js';
import { validar } from '../../middlewares/validar.js';
import { HttpError } from '../../utils/http-error.js';
import { responder } from '../../utils/respuestas.js';
import { loginSchema, mfaSchema, primerAccesoAdminSchema, primerAccesoSchema } from './auth.schema.js';

// Máximo 5 intentos cada 15 minutos (frena ataques de fuerza bruta).
function limitarIntentos(limite = 5) {
  return rateLimit({
    windowMs: 15 * 60 * 1000,
    limit: limite,
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

  // "¿Quién soy?": también lo puede preguntar quien está en el primer acceso.
  router.get('/me', autenticar(jwtSecret, { permitir: ['primer_acceso'] }), async (req, res) => {
    if (!authService) {
      throw new HttpError(503, 'AUTENTICACION_NO_DISPONIBLE', 'La base de datos aún no está conectada.');
    }
    responder(res, { user: await authService.getCurrentUser(req.usuario.id) });
  });

  // RF-02: cambiar la contraseña temporal o mantenerla (T3).
  router.post(
    '/primer-acceso',
    autenticar(jwtSecret, { permitir: ['primer_acceso'] }),
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

  // T12 · Primer ingreso del administrador (sin Términos): cambia o mantiene su
  // contraseña. Solo con la llave limitada obtenida DESPUÉS del código MFA; al
  // terminar responde con la sesión completa para entrar al Home.
  router.post(
    '/primer-acceso/administrador',
    autenticar(jwtSecret, { permitir: ['primer_acceso'] }),
    limiterPrimerAcceso,
    validar(primerAccesoAdminSchema),
    async (req, res) => {
      if (!authService) {
        throw new HttpError(503, 'AUTENTICACION_NO_DISPONIBLE', 'La base de datos aún no está conectada.');
      }
      responder(res, await authService.completeAdminFirstAccess(
        req.usuario.id,
        req.body,
        { mfaVerificado: req.usuario.mfaVerificado },
        { ip: req.ip, userAgent: req.get('user-agent')?.slice(0, 512) },
      ));
    },
  );

  // T8 · Verificación en dos pasos. Solo se entra con el "pase de verificación"
  // (llave tipo 'mfa') que entrega el login; no abre ninguna otra parte.
  // 20 pedidos cada 15 minutos por red: el MFA además bloquea solo a los 5
  // códigos incorrectos, así que este límite frena a quien prueba en masa.
  const limiterMfa = limitarIntentos(20);
  const conPaseMfa = autenticar(jwtSecret, { permitir: ['mfa'] });
  const soloPaseMfa = (req, _res, next) => next(req.usuario.tipo === 'mfa'
    ? undefined
    : new HttpError(403, 'ACCESO_INCOMPLETO', 'Inicia sesión para recibir un código.'));

  router.post('/mfa/verificar', limiterMfa, conPaseMfa, soloPaseMfa, validar(mfaSchema), async (req, res) => {
    if (!authService?.mfa) throw new HttpError(404, 'RUTA_NO_ENCONTRADA', 'La ruta solicitada no existe.');
    responder(res, await authService.completeMfa(req.usuario.desafio, req.body.codigo, {
      ip: req.ip,
      userAgent: req.get('user-agent')?.slice(0, 512),
    }));
  });

  router.post('/mfa/reenviar', limiterMfa, conPaseMfa, soloPaseMfa, async (req, res) => {
    if (!authService?.mfa) throw new HttpError(404, 'RUTA_NO_ENCONTRADA', 'La ruta solicitada no existe.');
    responder(res, await authService.mfa.reenviar(req.usuario.desafio));
  });

  router.get('/sesion', autenticar(jwtSecret), exigirTerminos(authService), (req, res) => {
    responder(res, { userId: req.usuario.id, role: req.usuario.role });
  });

  return router;
}
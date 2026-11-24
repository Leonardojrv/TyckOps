// ¿PARA QUÉ SIRVE?
//   Son las "puertas" del servidor para los tickets del colaborador: reportar una
//   falla, ver mis tickets, ver un detalle, ver su foto y cancelar (T9).
//
// ¿QUÉ HACE?
//   Antes de cualquier cosa revisa tres llaves: sesión válida, rol colaborador y
//   términos aceptados. El dueño del ticket SIEMPRE sale de la sesión, nunca de
//   lo que mande el teléfono.
//
// ¿CÓMO LO CAMBIO?
//   Para agregar una ruta nueva, súmala aquí y pon
//   la lógica en tickets.service.js. No quites los tres controles de arriba.

import { Router } from 'express';
import rateLimit from 'express-rate-limit';
import multer from 'multer';
import { autenticar } from '../../middlewares/autenticar.js';
import { exigirTerminos } from '../../middlewares/exigirTerminos.js';
import { requerirRol } from '../../middlewares/requerirRol.js';
import { HttpError } from '../../utils/http-error.js';
import { responder } from '../../utils/respuestas.js';
import { MAX_FOTO_BYTES, detectarTipoImagen } from './tickets.fotos.js';
import { reporteSchema } from './tickets.schema.js';

// Multer guarda la foto solo en memoria y corta antes de leer de más.
// Una foto por reporte: se guarda en la columna imagen (BYTEA) del ticket.
const recibirFoto = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: MAX_FOTO_BYTES, files: 1, fields: 5, fieldSize: 2048, parts: 6 },
}).single('foto');

// Traduce los errores de Multer a mensajes claros para la app.
function subirFoto(middleware) {
  return (req, res, next) => middleware(req, res, (error) => {
    if (!error) return next();
    if (error instanceof multer.MulterError) {
      if (error.code === 'LIMIT_FILE_SIZE') {
        return next(new HttpError(413, 'FOTO_MUY_GRANDE', 'La foto supera los 5 MB.'));
      }
      if (error.code === 'LIMIT_UNEXPECTED_FILE' || error.code === 'LIMIT_FILE_COUNT') {
        return next(new HttpError(400, 'FOTO_INVALIDA', 'Adjunta solo una fotografía.'));
      }
      return next(new HttpError(400, 'DATOS_INVALIDOS', 'Revisa los datos enviados.'));
    }
    return next(error);
  });
}

function datosInvalidos(zodError) {
  const details = zodError.issues.map((issue) => ({ field: issue.path.join('.'), message: issue.message }));
  return new HttpError(400, 'DATOS_INVALIDOS', details[0]?.message ?? 'Revisa los datos enviados.', details);
}

// Tickets del colaborador (T5 home, T6 reporte, T7 lista y detalle).
export function crearRutasTickets({ ticketService, authService, jwtSecret }) {
  const router = Router();

  // Autenticación y Términos aceptados para todas las rutas de tickets.
  router.use(autenticar(jwtSecret), exigirTerminos(authService));
  router.use((_req, _res, next) => next(ticketService
    ? undefined
    : new HttpError(503, 'TICKETS_NO_DISPONIBLES', 'Los tickets aún no están disponibles.')));

  // Máximo 10 reportes por hora por persona (evita llenar el disco o la bandeja).
  const limiterReportes = rateLimit({
    windowMs: 60 * 60 * 1000,
    limit: 10,
    keyGenerator: (req) => `usuario:${req.usuario.id}`,
    standardHeaders: true,
    legacyHeaders: false,
    message: {
      success: false,
      error: { code: 'DEMASIADOS_REPORTES', message: 'Enviaste muchos reportes seguidos. Espera un momento.' },
    },
  });

  // RF-04: reportar una falla con su foto opcional (campo `foto`, multipart/form-data).
  const crearReporte = async (req, res) => {
    const datos = reporteSchema.safeParse(req.body ?? {});
    if (!datos.success) throw datosInvalidos(datos.error);
    let foto = null;
    if (req.file) {
      // Seguridad: el tipo se decide por los primeros bytes del archivo (su "firma"),
      // no por el nombre ni por lo que dice el celular. Un .exe renombrado a .jpg no pasa.
      const tipo = detectarTipoImagen(req.file.buffer);
      if (!tipo) throw new HttpError(415, 'FOTO_TIPO_INVALIDO', 'La foto debe ser JPG o PNG.');
      foto = { buffer: req.file.buffer, tipo };
    }

    // El dueño sale del token, nunca del formulario.
    const ticket = await ticketService.crearReporte(req.usuario.id, datos.data, foto);
    responder(res, { ticket }, 201);
  };

  router.post('/', requerirRol('COLABORADOR'), limiterReportes, subirFoto(recibirFoto), crearReporte);
  router.post('/reparaciones', requerirRol('COLABORADOR'), limiterReportes, subirFoto(recibirFoto), crearReporte);

  // Lista de tickets del colaborador (compatibilidad con la app móvil y T5).
  router.get('/mis-tickets', requerirRol('COLABORADOR'), async (req, res) => {
    responder(res, await ticketService.misTickets(req.usuario.id));
  });

  // GET /tickets/mios con la lista del usuario y su estado.
  router.get('/mios', requerirRol('COLABORADOR', 'ADMINISTRADOR'), async (req, res) => {
    responder(res, await ticketService.misTickets(req.usuario.id));
  });

  // GET /tickets/resumen con el conteo de tickets activos para el home.
  router.get('/resumen', requerirRol('COLABORADOR', 'ADMINISTRADOR'), async (req, res) => {
    responder(res, await ticketService.resumen(req.usuario.id));
  });

  // GET /tickets/:id con el detalle (solo para el dueño o un administrador).
  router.get('/:id', requerirRol('COLABORADOR', 'ADMINISTRADOR'), async (req, res) => {
    responder(res, { ticket: await ticketService.detalle(req.usuario, req.params.id) });
  });

  // T9 · Cancelar: solo el colaborador dueño y solo si sigue en Recibido.
  // Máximo 20 intentos cada 15 minutos por persona (evita abusar de la ruta).
  const limiterCancelar = rateLimit({
    windowMs: 15 * 60 * 1000,
    limit: 20,
    keyGenerator: (req) => `usuario:${req.usuario.id}`,
    standardHeaders: true,
    legacyHeaders: false,
    message: {
      success: false,
      error: { code: 'DEMASIADOS_INTENTOS', message: 'Hiciste muchos intentos seguidos. Espera un momento.' },
    },
  });
  router.post('/:id/cancelar', requerirRol('COLABORADOR'), limiterCancelar, async (req, res) => {
    responder(res, { ticket: await ticketService.cancelar(req.usuario.id, req.params.id) });
  });

  // Foto del ticket (columna imagen). Solo el dueño o un administrador pueden verla.
  // Se responde como imagen (no JSON) para que la app la muestre directamente.
  router.get('/:id/foto', requerirRol('COLABORADOR', 'ADMINISTRADOR'), async (req, res) => {
    const { buffer, mime } = await ticketService.foto(req.usuario, req.params.id);
    res.set({
      'Content-Type': mime,
      'Content-Length': String(buffer.length),
      'Content-Disposition': 'inline',
      // Es una foto privada: no se guarda en cachés compartidos ni intermedios.
      'Cache-Control': 'private, no-store',
    });
    res.send(buffer);
  });

  return router;
}

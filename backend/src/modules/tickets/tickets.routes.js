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
const recibirFoto = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: MAX_FOTO_BYTES, files: 1, fields: 5, fieldSize: 1024, parts: 6 },
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
  // Toda la ruta exige: sesión válida + rol colaborador + términos aceptados.
  router.use(autenticar(jwtSecret), requerirRol('COLABORADOR'), exigirTerminos(authService));
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

  // RF-04: reportar una falla con su foto (multipart/form-data).
  router.post('/', limiterReportes, subirFoto(recibirFoto), async (req, res) => {
    const datos = reporteSchema.safeParse(req.body ?? {});
    if (!datos.success) throw datosInvalidos(datos.error);
    // La foto es opcional; si viene, se valida igual que siempre.
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
  });

  // El dueño sale del token firmado (req.usuario.id), NUNCA de la URL o del body.
  router.get('/mis-tickets', async (req, res) => {
    responder(res, await ticketService.misTickets(req.usuario.id));
  });

  router.get('/:id', async (req, res) => {
    responder(res, { ticket: await ticketService.detalle(req.usuario.id, req.params.id) });
  });

  return router;
}

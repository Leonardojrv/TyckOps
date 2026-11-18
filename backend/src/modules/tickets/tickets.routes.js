import { Router } from 'express';
import rateLimit from 'express-rate-limit';
import multer from 'multer';
import { autenticar } from '../../middlewares/autenticar.js';
import { exigirTerminos } from '../../middlewares/exigirTerminos.js';
import { requerirRol } from '../../middlewares/requerirRol.js';
import { HttpError } from '../../utils/http-error.js';
import { responder } from '../../utils/respuestas.js';
import { MAX_FOTO_BYTES, MAX_FOTOS, detectarTipoImagen } from './tickets.fotos.js';
import { reporteSchema } from './tickets.schema.js';

// Mantiene `foto` para la app actual y acepta `fotos` repetido para nuevos clientes.
const recibirFoto = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: MAX_FOTO_BYTES, files: MAX_FOTOS, fields: 5, fieldSize: 2048, parts: 8 },
}).fields([
  { name: 'foto', maxCount: 1 },
  { name: 'fotos', maxCount: MAX_FOTOS },
]);

// Traduce los errores de Multer a mensajes claros para la app.
function subirFoto(middleware) {
  return (req, res, next) => middleware(req, res, (error) => {
    if (!error) return next();
    if (error instanceof multer.MulterError) {
      if (error.code === 'LIMIT_FILE_SIZE') {
        return next(new HttpError(413, 'FOTO_MUY_GRANDE', 'La foto supera los 5 MB.'));
      }
      if (error.code === 'LIMIT_UNEXPECTED_FILE' || error.code === 'LIMIT_FILE_COUNT') {
        return next(new HttpError(400, 'FOTO_INVALIDA', `Adjunta hasta ${MAX_FOTOS} fotos.`));
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

  router.get('/:id/fotos/:nombre', autenticar(jwtSecret), exigirTerminos(authService), async (req, res) => {
    if (!ticketService) {
      throw new HttpError(503, 'TICKETS_NO_DISPONIBLES', 'Los tickets aún no están disponibles.');
    }
    const foto = await ticketService.fotoDeTicket(req.params.id, req.usuario, req.params.nombre);
    res
      .set('Content-Type', foto.mime)
      .set('Content-Disposition', `inline; filename="${req.params.nombre}"`)
      .set('Cache-Control', 'private, no-store')
      .send(foto.buffer);
  });

  router.get('/:id/fotos', autenticar(jwtSecret), exigirTerminos(authService), async (req, res) => {
    if (!ticketService) {
      throw new HttpError(503, 'TICKETS_NO_DISPONIBLES', 'Los tickets aún no están disponibles.');
    }
    const fotos = await ticketService.fotosDeTicket(req.params.id, req.usuario);
    responder(res, { fotos });
  });

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

  // RF-04: reporta con el campo móvil `foto` o con hasta tres campos `fotos`.
  const crearReporte = async (req, res) => {
    const datos = reporteSchema.safeParse(req.body ?? {});
    if (!datos.success) throw datosInvalidos(datos.error);
    const archivos = [...(req.files?.foto ?? []), ...(req.files?.fotos ?? [])];
    const fotos = archivos.map((archivo) => {
      // Seguridad: el tipo se decide por los primeros bytes del archivo (su "firma"),
      // no por el nombre ni por lo que dice el celular. Un .exe renombrado a .jpg no pasa.
      const tipo = detectarTipoImagen(archivo.buffer);
      if (!tipo) throw new HttpError(415, 'FOTO_TIPO_INVALIDO', 'Las fotos deben ser JPG o PNG.');
      return { buffer: archivo.buffer, tipo };
    });

    // El dueño sale del token, nunca del formulario.
    const ticket = await ticketService.crearReporte(req.usuario.id, datos.data, fotos);
    responder(res, { ticket }, 201);
  };

  router.post('/', limiterReportes, subirFoto(recibirFoto), crearReporte);
  router.post('/reparaciones', limiterReportes, subirFoto(recibirFoto), crearReporte);

  // El dueño sale del token firmado (req.usuario.id), NUNCA de la URL o del body.
  router.get('/mis-tickets', async (req, res) => {
    responder(res, await ticketService.misTickets(req.usuario.id));
  });

  router.get('/:id', async (req, res) => {
    responder(res, { ticket: await ticketService.detalle(req.usuario.id, req.params.id) });
  });

  return router;
}

import { Router } from 'express';
import multer from 'multer';
import { autenticar } from '../../middlewares/autenticar.js';
import { exigirTerminos } from '../../middlewares/exigirTerminos.js';
import { requerirRol } from '../../middlewares/requerirRol.js';
import { HttpError } from '../../utils/http-error.js';
import { responder } from '../../utils/respuestas.js';

const MAX_EXCEL_BYTES = 2 * 1024 * 1024; // Límite de 2 MB

const recibirArchivoExcel = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: MAX_EXCEL_BYTES, files: 1 },
}).single('archivo');

function subirArchivoExcel(middleware) {
  return (req, res, next) => middleware(req, res, (error) => {
    if (!error) return next();
    if (error instanceof multer.MulterError) {
      if (error.code === 'LIMIT_FILE_SIZE') {
        return next(new HttpError(413, 'ARCHIVO_MUY_GRANDE', 'El archivo supera el tamaño máximo permitido de 2 MB.'));
      }
      return next(new HttpError(400, 'ARCHIVO_INVALIDO', 'Adjunta solo un archivo Excel en el campo archivo.'));
    }
    return next(error);
  });
}

/**
 * Rutas de Guías de Autoayuda para administradores:
 * - GET  /guias/plantilla
 * - POST /guias/archivo
 * - POST /guias/:version/activar
 * - GET  /guias
 */
export function crearRutasGuias({ guiasService, authService, jwtSecret }) {
  const router = Router();

  // Todas las rutas requieren: Sesión válida + Rol Administrador + Términos Aceptados
  router.use(autenticar(jwtSecret), requerirRol('ADMINISTRADOR'), exigirTerminos(authService));

  router.use((_req, _res, next) => next(guiasService
    ? undefined
    : new HttpError(503, 'GUIAS_NO_DISPONIBLES', 'El servicio de guías no está configurado.')));

  // GET /plantilla -> Entrega el archivo Excel con las 5 columnas requeridas
  router.get('/plantilla', async (_req, res, next) => {
    try {
      const buffer = await guiasService.generarPlantilla();
      res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      res.setHeader('Content-Disposition', 'attachment; filename="plantilla_guias.xlsx"');
      res.setHeader('Content-Length', buffer.length);
      return res.send(buffer);
    } catch (error) {
      return next(error);
    }
  });

  // POST /archivo -> Recibe el .xlsx, valida tamaño/formato/columnas/filas, sanitiza HTML y reporta errores por fila
  router.post('/archivo', subirArchivoExcel(recibirArchivoExcel), async (req, res, next) => {
    try {
      if (!req.file || !req.file.buffer) {
        throw new HttpError(400, 'ARCHIVO_REQUERIDO', 'Debes adjuntar un archivo Excel (.xlsx) en el campo "archivo".');
      }

      // Validar extensión
      const nombre = req.file.originalname?.toLowerCase() ?? '';
      if (!nombre.endsWith('.xlsx')) {
        throw new HttpError(400, 'FORMATO_INVALIDO', 'El archivo debe tener extensión .xlsx.');
      }

      const data = await guiasService.procesarYGuardarArchivo(req.file.buffer, req.usuario.id);
      return responder(res, data, 201);
    } catch (error) {
      return next(error);
    }
  });

  // POST /:version/activar -> Publica la versión nueva y archiva la anterior
  router.post('/:version/activar', async (req, res, next) => {
    try {
      const data = await guiasService.activarVersion(req.params.version);
      return responder(res, data, 200);
    } catch (error) {
      return next(error);
    }
  });

  // GET / -> Lista las guías vigentes
  router.get('/', async (_req, res, next) => {
    try {
      const data = await guiasService.obtenerVigentes();
      return responder(res, data, 200);
    } catch (error) {
      return next(error);
    }
  });

  return router;
}

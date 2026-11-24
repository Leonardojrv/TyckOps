// ¿PARA QUÉ SIRVE?
//   Rutas de las reglas de prioridad (MM2). Solo para administradores.
//
//   POST /api/reglas/archivo            sube el .txt (campo "archivo", multipart) -> versión inactiva
//   POST /api/reglas/:version/activar   activa esa versión (desactiva la anterior)
//   GET  /api/reglas                    reglas vigentes (versión activa)
//
// ¿CÓMO LO CAMBIO?
//   La validación del archivo está en reglas.parser.js; aquí solo se recibe.

import { Router } from 'express';
import multer from 'multer';
import { autenticar } from '../../middlewares/autenticar.js';
import { exigirTerminos } from '../../middlewares/exigirTerminos.js';
import { requerirRol } from '../../middlewares/requerirRol.js';
import { HttpError } from '../../utils/http-error.js';
import { responder } from '../../utils/respuestas.js';
import { MAX_BYTES_REGLAS } from './reglas.parser.js';

const recibirArchivo = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: MAX_BYTES_REGLAS, files: 1, fields: 2, parts: 3 },
}).single('archivo');

function subirArchivo(req, res, next) {
  recibirArchivo(req, res, (error) => {
    if (!error) return next();
    if (error instanceof multer.MulterError) {
      if (error.code === 'LIMIT_FILE_SIZE') return next(new HttpError(413, 'ARCHIVO_MUY_GRANDE', 'El archivo supera los 200 KB.'));
      return next(new HttpError(400, 'ARCHIVO_INVALIDO', 'Adjunta solo un archivo .txt en el campo "archivo".'));
    }
    return next(error);
  });
}

export function crearRutasReglas({ reglasService, authService, jwtSecret }) {
  const router = Router();

  router.use(autenticar(jwtSecret), requerirRol('ADMINISTRADOR'), exigirTerminos(authService));
  router.use((_req, _res, next) => next(reglasService
    ? undefined
    : new HttpError(503, 'REGLAS_NO_DISPONIBLES', 'Las reglas de prioridad aún no están disponibles.')));

  router.post('/archivo', subirArchivo, async (req, res) => {
    if (!req.file) throw new HttpError(400, 'ARCHIVO_REQUERIDO', 'Adjunta el archivo .txt de reglas en el campo "archivo".');
    if (!/\.txt$/i.test(req.file.originalname ?? '')) {
      throw new HttpError(400, 'FORMATO_INVALIDO', 'El archivo debe tener extensión .txt.');
    }
    responder(res, await reglasService.subirArchivo(req.file.buffer, req.usuario.id), 201);
  });

  router.post('/:version/activar', async (req, res) => {
    responder(res, await reglasService.activar(req.params.version));
  });

  router.get('/', async (_req, res) => {
    responder(res, await reglasService.listarVigentes());
  });

  return router;
}

import { ZodError } from 'zod';
import { traducirErrorBaseDatos } from '../utils/erroresBaseDatos.js';
import { HttpError } from '../utils/http-error.js';
import { responderError } from '../utils/respuestas.js';

export function rutaNoEncontrada(_req, _res, next) {
  next(new HttpError(404, 'RUTA_NO_ENCONTRADA', 'La ruta solicitada no existe.'));
}

export function manejarErrores(error, _req, res, _next) {
  if (error?.type === 'entity.parse.failed') {
    return responderError(
      res,
      new HttpError(400, 'DATOS_INVALIDOS', 'El cuerpo de la solicitud debe contener JSON válido.'),
    );
  }

  if (error instanceof ZodError) {
    const details = error.issues.map((issue) => ({
      field: issue.path.join('.'),
      message: issue.message,
    }));
    return responderError(res, new HttpError(400, 'DATOS_INVALIDOS', 'Revisa los datos enviados.', details));
  }

  if (error instanceof HttpError) return responderError(res, error);

  // Errores de PostgreSQL / Prisma: conexión, llaves foráneas, únicos, CHECK...
  const deBaseDatos = traducirErrorBaseDatos(error);
  if (deBaseDatos) {
    const { httpError, registro } = deBaseDatos;
    // En el log va solo un resumen (tipo, código, tabla, restricción): nunca la
    // fila con datos de usuarios que trae el mensaje original de PostgreSQL.
    const linea = JSON.stringify({ type: 'db_error', status: httpError.status, ...registro });
    if (httpError.status >= 500) {
      console.error(linea);
      res.set('Retry-After', '30'); // la app puede reintentar en 30 segundos
    } else {
      console.warn(linea);
    }
    return responderError(res, httpError);
  }

  console.error(error);
  return responderError(
    res,
    new HttpError(500, 'ERROR_INTERNO', 'Ocurrió un error interno.'),
  );
}
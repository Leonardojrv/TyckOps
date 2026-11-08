import { ZodError } from 'zod';
import { HttpError } from '../utils/http-error.js';
import { responderError } from '../utils/respuestas.js';

export function rutaNoEncontrada(_req, _res, next) {
  next(new HttpError(404, 'RUTA_NO_ENCONTRADA', 'La ruta solicitada no existe.'));
}

export function manejarErrores(error, _req, res, _next) {
  if (error instanceof ZodError) {
    const details = error.issues.map((issue) => ({
      field: issue.path.join('.'),
      message: issue.message,
    }));
    return responderError(res, new HttpError(400, 'DATOS_INVALIDOS', 'Revisa los datos enviados.', details));
  }

  if (error instanceof HttpError) return responderError(res, error);

  console.error(error);
  return responderError(
    res,
    new HttpError(500, 'ERROR_INTERNO', 'Ocurrió un error interno.'),
  );
}
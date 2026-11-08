import { HttpError } from '../utils/http-error.js';

export function validar(schema) {
  return (req, _res, next) => {
    const result = schema.safeParse(req.body);
    if (!result.success) {
      const details = result.error.issues.map((issue) => ({
        field: issue.path.join('.'),
        message: issue.message,
      }));
      return next(new HttpError(400, 'DATOS_INVALIDOS', 'Revisa los datos enviados.', details));
    }

    req.body = result.data;
    return next();
  };
}
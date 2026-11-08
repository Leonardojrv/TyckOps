import jwt from 'jsonwebtoken';
import { HttpError } from '../utils/http-error.js';

export function autenticar(secret) {
  return (req, _res, next) => {
    const authorization = req.get('authorization');
    const [scheme, token] = authorization?.split(' ') ?? [];

    if (scheme !== 'Bearer' || !token) {
      return next(new HttpError(401, 'NO_AUTENTICADO', 'Inicia sesión para continuar.'));
    }

    try {
      const payload = jwt.verify(token, secret);
      if (typeof payload !== 'object' || !payload.sub || !payload.role) {
        throw new Error('Token sin datos de sesión.');
      }
      req.usuario = { id: payload.sub, role: payload.role };
      return next();
    } catch {
      return next(new HttpError(401, 'TOKEN_INVALIDO', 'La sesión no es válida o expiró.'));
    }
  };
}
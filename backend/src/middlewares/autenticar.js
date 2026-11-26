// ¿PARA QUÉ SIRVE?
//   Es el guardia de la puerta: revisa que cada pedido traiga una sesión válida.
//
// ¿QUÉ HACE?
//   Lee la "llave" (token) del pedido, comprueba que sea auténtica y que no haya
//   vencido, y anota quién es la persona y su rol. Además revisa QUÉ tipo de
//   llave es: las llaves limitadas (verificación en dos pasos o primer acceso)
//   no abren las rutas normales de la app.
//
// ¿CÓMO LO CAMBIO?
//   Si una ruta debe aceptar una llave limitada, se indica al usarlo, por ejemplo:
//   autenticar(secreto, { permitir: ['primer_acceso'] }). Por defecto solo pasa
//   la sesión completa.

import jwt from 'jsonwebtoken';
import { HttpError } from '../utils/http-error.js';

// Llaves que NO son una sesión completa. Una llave sin tipo es de antes del
// MFA y se trata como completa (así siguen funcionando las pruebas antiguas).
const LLAVES_LIMITADAS = new Set(['mfa', 'primer_acceso', 'creacion_ticket']);

export function autenticar(secret, { permitir = [] } = {}) {
  return (req, _res, next) => {
    const authorization = req.get('authorization');
    const [scheme, token] = authorization?.split(' ') ?? [];

    if (scheme !== 'Bearer' || !token) {
      return next(new HttpError(401, 'NO_AUTENTICADO', 'Inicia sesión para continuar.'));
    }

    let payload;
    try {
      payload = jwt.verify(token, secret);
      if (typeof payload !== 'object' || !payload.sub || !payload.role) {
        throw new Error('Token sin datos de sesión.');
      }
    } catch {
      return next(new HttpError(401, 'TOKEN_INVALIDO', 'La sesión no es válida o expiró.'));
    }

    // Una llave limitada solo entra donde se permitió explícitamente.
    if (LLAVES_LIMITADAS.has(payload.typ) && !permitir.includes(payload.typ)) {
      return next(new HttpError(403, 'ACCESO_INCOMPLETO', 'Completa la verificación antes de continuar.'));
    }

    req.usuario = { id: payload.sub, role: payload.role, tipo: payload.typ ?? 'acceso', desafio: payload.jti };
    return next();
  };
}

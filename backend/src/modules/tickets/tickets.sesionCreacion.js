// ¿PARA QUÉ SIRVE?
//   Pone un tiempo límite de 3 minutos para crear un ticket.
//
// ¿QUÉ HACE?
//   Al abrir "Reportar falla", la app pide un "permiso de creación" (un token
//   firmado que vence a los 3 minutos). Al enviar el reporte lo manda en la
//   cabecera X-Sesion-Creacion. Si ya venció, el ticket NO se guarda y se
//   responde 410 TIEMPO_CREACION_EXPIRADO (la app vuelve al inicio y avisa).
//   El permiso no se guarda en la base de datos: la firma y el vencimiento
//   viajan dentro del token, y solo sirve para la persona que lo pidió.
//
// ¿CÓMO LO CAMBIO?
//   Para cambiar el tiempo, cambia DURACION_CREACION_SEGUNDOS. La app no lleva
//   el tiempo por su cuenta: usa la duración que le entrega este archivo.

import { randomUUID } from 'node:crypto';
import jwt from 'jsonwebtoken';
import { HttpError } from '../../utils/http-error.js';

export const DURACION_CREACION_SEGUNDOS = 3 * 60;
export const CABECERA_SESION_CREACION = 'x-sesion-creacion';

// Tipo de llave propio. No lleva "role", así que autenticar() nunca lo acepta
// como sesión (además está en su lista de llaves limitadas).
const TIPO = 'creacion_ticket';

/** Entrega un permiso de creación nuevo para el usuario de la sesión. */
export function crearSesionCreacion(jwtSecret, userId, { duracionSegundos = DURACION_CREACION_SEGUNDOS } = {}) {
  const token = jwt.sign({ typ: TIPO }, jwtSecret, {
    subject: String(userId),
    expiresIn: duracionSegundos,
    jwtid: randomUUID(),
  });
  const { exp } = jwt.decode(token);
  return {
    token,
    duracionSegundos,
    expiraEn: new Date(exp * 1000).toISOString(),
  };
}

/**
 * Middleware para las rutas que crean tickets. Va ANTES de recibir la foto:
 * si el tiempo venció, no se lee ni un byte del archivo.
 */
export function exigirSesionCreacion(jwtSecret) {
  return (req, _res, next) => {
    const token = req.get(CABECERA_SESION_CREACION);
    if (!token) {
      return next(new HttpError(400, 'SESION_CREACION_REQUERIDA', 'Vuelve a abrir "Reportar falla" para crear el ticket.'));
    }
    let payload;
    try {
      payload = jwt.verify(token, jwtSecret);
    } catch (error) {
      if (error instanceof jwt.TokenExpiredError) {
        return next(new HttpError(410, 'TIEMPO_CREACION_EXPIRADO', 'Tiempo para la creación del ticket expirado.'));
      }
      return next(new HttpError(400, 'SESION_CREACION_INVALIDA', 'Vuelve a abrir "Reportar falla" para crear el ticket.'));
    }
    // El permiso es personal: no sirve el de otra persona.
    if (payload?.typ !== TIPO || payload.sub !== String(req.usuario.id)) {
      return next(new HttpError(400, 'SESION_CREACION_INVALIDA', 'Vuelve a abrir "Reportar falla" para crear el ticket.'));
    }
    return next();
  };
}

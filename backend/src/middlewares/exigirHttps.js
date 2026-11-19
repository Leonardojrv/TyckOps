// Cifrado app → backend en producción.
// En producción el HTTPS lo pone el hosting o un proxy (Render, Railway, Nginx...):
// el proxy recibe la conexión cifrada y le pasa la solicitud al backend con la
// cabecera X-Forwarded-Proto. Por eso app.js activa 'trust proxy' en producción
// y aquí basta revisar req.secure.
//
// Una solicitud por http se RECHAZA (no se redirige): si llegó por http, la
// contraseña o el token ya viajaron sin cifrar, y redirigir solo lo ocultaría.
// HSTS (obliga al navegador a usar siempre https) ya lo pone helmet.
//
// /salud queda libre: algunos hostings revisan la salud por http interno.

import { HttpError } from '../utils/http-error.js';

export function exigirHttps(req, _res, next) {
  if (req.secure || req.path === '/salud') return next();
  return next(new HttpError(403, 'HTTPS_REQUERIDO', 'La conexión debe ser segura (https).'));
}

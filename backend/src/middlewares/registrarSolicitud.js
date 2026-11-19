// Una línea de log por cada solicitud HTTP, escrita cuando termina la respuesta.
// Registra QUÉ se pidió y CÓMO terminó, nunca el contenido: sin cuerpo, sin
// query string (puede traer datos) y sin cabeceras (Authorization lleva el token).
//
// El requestId también viaja en la cabecera X-Request-Id de la respuesta: si
// alguien reporta un error, con ese ID se encuentran todas sus líneas del log.

import { randomUUID } from 'node:crypto';
import { logger } from '../config/logger.js';

export function registrarSolicitud(req, res, next) {
  const inicio = process.hrtime.bigint();
  req.requestId = randomUUID();
  res.set('X-Request-Id', req.requestId);

  res.on('finish', () => {
    const datos = {
      requestId: req.requestId,
      metodo: req.method,
      ruta: req.originalUrl.split('?')[0],
      status: res.statusCode,
      duracionMs: Math.round(Number(process.hrtime.bigint() - inicio) / 1e6),
      userId: req.usuario?.id ?? null, // lo pone autenticar(); null si no hubo sesión
      ip: req.ip,
    };
    // El chequeo de salud se llama seguido (monitoreo): solo en nivel debug.
    if (req.path === '/salud') return logger.debug('http', datos);
    // 4xx/5xx en warn; el detalle del error lo escribe manejarErrores.
    return res.statusCode >= 400 ? logger.warn('http', datos) : logger.info('http', datos);
  });

  next();
}

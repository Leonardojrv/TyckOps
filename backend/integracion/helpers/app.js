// Crea la app Express real (src/app.js) conectada a la base de pruebas.
// Se crea una app nueva por prueba: así el límite de 5 intentos de login
// (express-rate-limit) no se arrastra de una prueba a otra.

import jwt from 'jsonwebtoken';
import { crearApp } from '../../src/app.js';
import { PrismaNotificacionesRepository } from '../../src/modules/notificaciones/notificaciones.repositories.js';
import { NotificacionesService } from '../../src/modules/notificaciones/notificaciones.service.js';
import { PrismaTicketRepository } from '../../src/modules/tickets/tickets.prisma.repository.js';
import { TicketService } from '../../src/modules/tickets/tickets.service.js';

export const ENV_PRUEBAS = {
  jwtSecret: 'secreto-solo-para-pruebas-de-integracion-tyckops-2026',
  jwtExpiresIn: '1h',
  corsOrigin: '*',
};

/**
 * Devuelve la app, la lista de eventos de auditoría y los push "enviados".
 * Las notificaciones se guardan en la tabla Notificacion real; el envío push
 * es falso (no usa Firebase): solo anota a qué tokens se habría mandado.
 */
export function crearAppPruebas(prisma) {
  const auditoria = [];
  const pushEnviados = [];
  const enviadorFalso = {
    async enviar(tokens, mensaje) {
      pushEnviados.push({ tokens, mensaje });
      return { invalidos: [] };
    },
  };
  const notificaciones = new NotificacionesService(new PrismaNotificacionesRepository(prisma), enviadorFalso);
  const app = crearApp({
    env: ENV_PRUEBAS,
    prisma,
    databaseStatus: 'connected',
    auditLogger: { log: (evento) => auditoria.push(evento) },
    // Tickets con el repositorio real de PostgreSQL, igual que en server.js.
    ticketService: new TicketService(new PrismaTicketRepository(prisma), {
      auditLogger: { info: (evento) => auditoria.push(JSON.parse(evento)) },
      notificaciones,
    }),
  });
  return { app, auditoria, pushEnviados };
}

/** Firma un token igual que el backend, para casos que no pasan por el login. */
export function firmarToken({ id, role }, opciones = {}) {
  return jwt.sign({ role }, opciones.secreto ?? ENV_PRUEBAS.jwtSecret, {
    subject: String(id),
    expiresIn: opciones.expiresIn ?? '1h',
  });
}

// ¿PARA QUÉ SIRVE?
//   Prueba la cancelación de tickets del colaborador (T9 · RF-09).
//
// ¿QUÉ HACE?
//   Revisa que solo el dueño pueda cancelar, que solo se pueda mientras el
//   ticket está Recibido, que quede con fecha de cierre y que un ticket ajeno
//   responda igual que uno que no existe (404).
//
// ¿CÓMO LO CAMBIO?
//   Si cambia la regla (por ejemplo, permitir cancelar "En revisión"), ajusta
//   esta prueba y corre `pnpm test`.

import assert from 'node:assert/strict';
import { after, test } from 'node:test';
import jwt from 'jsonwebtoken';
import { crearApp } from '../src/app.js';
import { crearRepositorioEnMemoria } from '../src/modules/auth/auth.memory.repository.js';
import { AuthService } from '../src/modules/auth/auth.service.js';
import { MemoryTicketRepository } from '../src/modules/tickets/tickets.memory.repository.js';
import { TicketService } from '../src/modules/tickets/tickets.service.js';

const jwtSecret = 'test-secret-with-more-than-thirty-two-characters';
const env = { jwtSecret, jwtExpiresIn: '1h', corsOrigin: '*' };
const servers = [];

after(() => Promise.all(servers.map((server) => new Promise((resolve) => server.close(resolve)))));

async function start(app) {
  const server = app.listen(0);
  servers.push(server);
  await new Promise((resolve) => server.once('listening', resolve));
  return `http://127.0.0.1:${server.address().port}`;
}

function ticket(id, ownerId, status) {
  return { id, ownerId, code: `REP-${id}`, category: 'Baños', title: `Falla ${id}`, status, priority: null, location: 'Piso 1', createdAt: new Date('2026-11-20T10:00:00Z') };
}

test('T9: solo el dueño cancela, y solo si el ticket sigue en Recibido', async () => {
  const users = await crearRepositorioEnMemoria([
    { id: 'w-1', name: 'Ana', email: 'ana@gamaitaly.cl', password: 'Temporal2026!', role: 'COLABORADOR', termsAccepted: true },
    { id: 'w-2', name: 'Beto', email: 'beto@gamaitaly.cl', password: 'Temporal2026!', role: 'COLABORADOR', termsAccepted: true },
    { id: 'a-1', name: 'Admin', email: 'admin@gamaitaly.cl', password: 'Temporal2026!', role: 'ADMINISTRADOR', termsAccepted: true },
  ]);
  const auditoria = [];
  const repo = new MemoryTicketRepository([
    ticket('1', 'w-1', 'RECIBIDO'),
    ticket('2', 'w-1', 'EN_REVISION'),
    ticket('3', 'w-2', 'RECIBIDO'),
  ]);
  const ticketService = new TicketService(repo, { auditLogger: { info: (linea) => auditoria.push(JSON.parse(linea)) } });
  const authService = new AuthService(users, env, { log: () => {} });
  const baseUrl = await start(crearApp({ env, authService, ticketService }));
  const cancelar = (id, sub, role = 'COLABORADOR') => fetch(`${baseUrl}/api/tickets/${encodeURIComponent(id)}/cancelar`, {
    method: 'POST',
    headers: sub ? { authorization: `Bearer ${jwt.sign({ role }, jwtSecret, { subject: sub })}` } : {},
  });

  // Sin sesión o con rol de administrador: no entra.
  assert.equal((await cancelar('1')).status, 401);
  assert.equal((await cancelar('1', 'a-1', 'ADMINISTRADOR')).status, 403);

  // El ticket de otra persona responde igual que uno que no existe, y no cambia.
  const ajeno = await cancelar('3', 'w-1');
  assert.equal(ajeno.status, 404);
  assert.equal((await ajeno.json()).error.code, 'TICKET_NO_ENCONTRADO');
  assert.equal((await cancelar('no-existe', 'w-1')).status, 404);
  assert.equal((await cancelar('../1', 'w-1')).status, 404);

  // Ya en revisión: el servidor no lo deja aunque la app mostrara el botón.
  const enRevision = await cancelar('2', 'w-1');
  assert.equal(enRevision.status, 409);
  const errorCancelacion = (await enRevision.json()).error;
  assert.equal(errorCancelacion.code, 'TICKET_NO_CANCELABLE');
  assert.equal(errorCancelacion.message, 'Solo se puede cancelar un ticket en estado Recibido');

  // Recibido y propio: queda Cancelado, con fecha de cierre y registro de auditoría.
  const ok = await cancelar('1', 'w-1');
  assert.equal(ok.status, 200);
  const { ticket: cancelado } = (await ok.json()).data;
  assert.equal(cancelado.status, 'CANCELADO');
  assert.ok(cancelado.closedAt, 'guarda cuándo se canceló');
  assert.ok(!('ownerId' in cancelado));
  assert.deepEqual(repo.historialEstados[0], {
    ticketId: '1',
    estadoAnterior: 'RECIBIDO',
    estadoNuevo: 'CANCELADO',
    actorId: 'w-1',
    motivo: null,
    fecha: repo.historialEstados[0].fecha,
  });
  assert.ok(repo.historialEstados[0].fecha instanceof Date);
  assert.deepEqual(auditoria.map((a) => a.action), ['ticket_cancelado']);

  // Cancelar dos veces no se puede.
  assert.equal((await cancelar('1', 'w-1')).status, 409);

  // El ticket de Beto sigue intacto.
  const deBeto = await ticketService.misTickets('w-2');
  assert.equal(deBeto.tickets[0].status, 'RECIBIDO');
});

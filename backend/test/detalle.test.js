// ¿PARA QUÉ SIRVE?
//   Prueba el detalle del ticket (T7).
//
// ¿QUÉ HACE?
//   Revisa justo lo que pide la tarjeta: el motivo solo aparece en los
//   rechazados y cada ticket trae SOLO sus propios comentarios.
//
// ¿CÓMO LO CAMBIO?
//   Si cambias el detalle, ajusta esta prueba y corre `pnpm test`.
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

const base = { category: 'Eléctrica', priority: 'MEDIA', location: 'Piso 2', createdAt: new Date('2026-11-10T10:00:00Z') };

test('detalle: motivo solo si está rechazado y comentarios solo del ticket correcto (T7)', async () => {
  const users = await crearRepositorioEnMemoria([
    { id: 'w-1', name: 'Ana', email: 'ana@gamaitaly.cl', password: 'Temporal2026!', role: 'COLABORADOR', termsAccepted: true },
    { id: 'w-2', name: 'Beto', email: 'beto@gamaitaly.cl', password: 'Temporal2026!', role: 'COLABORADOR', termsAccepted: true },
  ]);
  const authService = new AuthService(users, env, { log: () => {} });
  const ticketService = new TicketService(new MemoryTicketRepository([
    {
      ...base, id: '1', ownerId: 'w-1', code: 'REP-0001', title: 'Enchufe quemado', status: 'EN_PROCESO',
      rejectionReason: 'texto viejo que no debe verse',
      comments: [
        { id: 2, author: 'Servicios Generales', createdAt: new Date('2026-11-10T12:00:00Z'), text: 'Técnico en camino' },
        { id: 1, author: 'Servicios Generales', createdAt: new Date('2026-11-10T11:00:00Z'), text: 'Recibido, lo revisamos' },
      ],
    },
    { ...base, id: '2', ownerId: 'w-1', code: 'REP-0002', title: 'Luz del pasillo', status: 'RECHAZADO', rejectionReason: 'Lo ve el edificio' },
    { ...base, id: '9', ownerId: 'w-2', code: 'REP-0009', title: 'Ajeno', status: 'EN_REVISION', comments: [{ id: 9, author: 'Admin', createdAt: new Date(), text: 'secreto' }] },
  ]));
  const baseUrl = await start(crearApp({ env, authService, ticketService }));
  const ver = (id, sub = 'w-1') => fetch(`${baseUrl}/api/tickets/${id}`, {
    headers: { authorization: `Bearer ${jwt.sign({ role: 'COLABORADOR' }, jwtSecret, { subject: sub })}` },
  });

  const enProceso = (await (await ver('1')).json()).data.ticket;
  assert.equal(enProceso.rejectionReason, null, 'un ticket no rechazado nunca muestra motivo');
  assert.deepEqual(enProceso.comments.map((c) => c.text), ['Recibido, lo revisamos', 'Técnico en camino']);
  assert.equal(enProceso.hasPhoto, false);

  const rechazado = (await (await ver('2')).json()).data.ticket;
  assert.equal(rechazado.rejectionReason, 'Lo ve el edificio');
  assert.deepEqual(rechazado.comments, []);

  // El ticket de otra persona (con su comentario) no se puede ver.
  assert.equal((await ver('9')).status, 404);
  assert.equal((await ver('9', 'w-2')).status, 200);
});

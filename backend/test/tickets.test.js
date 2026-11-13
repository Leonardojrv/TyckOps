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

function ticket(id, ownerId, status, createdAt) {
  return { id, ownerId, code: `REP-${id}`, category: 'Baños', title: `Falla ${id}`, status, priority: 'MEDIA', location: 'Piso 1', createdAt };
}

test('cada colaborador ve solo sus tickets (T5, sin IDOR)', async () => {
  const users = await crearRepositorioEnMemoria([
    { id: 'w-1', name: 'Ana', email: 'ana@gamaitaly.cl', password: 'Temporal2026!', role: 'COLABORADOR', termsAccepted: true },
    { id: 'w-2', name: 'Beto', email: 'beto@gamaitaly.cl', password: 'Temporal2026!', role: 'COLABORADOR', termsAccepted: true },
    { id: 'w-3', name: 'Caro', email: 'caro@gamaitaly.cl', password: 'Temporal2026!', role: 'COLABORADOR', termsAccepted: false },
    { id: 'a-1', name: 'Admin', email: 'admin@gamaitaly.cl', password: 'Temporal2026!', role: 'ADMINISTRADOR', termsAccepted: true },
  ]);
  const authService = new AuthService(users, env, { log: () => {} });
  const ticketService = new TicketService(new MemoryTicketRepository([
    ticket('1', 'w-1', 'EN_PROCESO', new Date('2026-11-10T10:00:00Z')),
    ticket('2', 'w-1', 'CERRADO', new Date('2026-11-01T10:00:00Z')),
    ticket('3', 'w-1', 'RECIBIDO', new Date('2026-11-12T10:00:00Z')),
    ticket('9', 'w-2', 'EN_REVISION', new Date('2026-11-11T10:00:00Z')),
  ]), { slaCumplido: 97 });
  const baseUrl = await start(crearApp({ env, authService, ticketService }));
  const as = (sub, role = 'COLABORADOR') => ({
    authorization: `Bearer ${jwt.sign({ role }, jwtSecret, { subject: sub })}`,
  });

  assert.equal((await fetch(`${baseUrl}/api/tickets/mis-tickets`)).status, 401);
  assert.equal((await fetch(`${baseUrl}/api/tickets/mis-tickets`, { headers: as('a-1', 'ADMINISTRADOR') })).status, 403);
  assert.equal((await fetch(`${baseUrl}/api/tickets/mis-tickets`, { headers: as('w-3') })).status, 403);

  const mine = await (await fetch(`${baseUrl}/api/tickets/mis-tickets`, { headers: as('w-1') })).json();
  assert.deepEqual(mine.data.tickets.map((t) => t.id), ['3', '1', '2']); // más reciente primero
  assert.deepEqual(mine.data.resumen, { total: 3, enAtencion: 2, slaCumplido: 97 });
  assert.ok(mine.data.tickets.every((t) => !('ownerId' in t)));

  assert.equal((await fetch(`${baseUrl}/api/tickets/1`, { headers: as('w-1') })).status, 200);
  // El ticket de otra persona responde igual que uno que no existe.
  const foreign = await fetch(`${baseUrl}/api/tickets/9`, { headers: as('w-1') });
  assert.equal(foreign.status, 404);
  assert.equal((await foreign.json()).error.code, 'TICKET_NO_ENCONTRADO');
  assert.equal((await fetch(`${baseUrl}/api/tickets/no-existe`, { headers: as('w-1') })).status, 404);
  assert.equal((await fetch(`${baseUrl}/api/tickets/${encodeURIComponent('../1')}`, { headers: as('w-1') })).status, 404);
});

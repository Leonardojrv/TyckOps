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

function ticket(id, { category, title, status, createdAt, closedAt = null }) {
  return {
    id,
    ownerId: 'w-1',
    code: `REP-${id}`,
    category,
    title,
    status,
    priority: null,
    location: 'Piso 2',
    createdAt: new Date(createdAt),
    closedAt: closedAt ? new Date(closedAt) : null,
  };
}

test('GET /api/tickets/historial filtra por rango, estado, categoría y texto del dueño', async () => {
  const users = await crearRepositorioEnMemoria([
    { id: 'w-1', name: 'Ana', email: 'ana@gamaitaly.cl', password: 'Temporal2026!', role: 'COLABORADOR', termsAccepted: true },
    { id: 'w-2', name: 'Beto', email: 'beto@gamaitaly.cl', password: 'Temporal2026!', role: 'COLABORADOR', termsAccepted: true },
  ]);
  const repo = new MemoryTicketRepository([
    ticket('1', {
      category: 'Baños',
      title: 'Fuga en lavamanos',
      status: 'CERRADO',
      createdAt: '2026-11-20T10:00:00Z',
      closedAt: '2026-11-21T10:00:00Z',
    }),
    ticket('2', {
      category: 'Eléctrica',
      title: 'Luminaria apagada',
      status: 'CANCELADO',
      createdAt: '2026-11-19T10:00:00Z',
      closedAt: '2026-11-19T11:00:00Z',
    }),
    ticket('3', {
      category: 'Baños',
      title: 'Fuga antigua',
      status: 'RECIBIDO',
      createdAt: '2025-01-02T10:00:00Z',
    }),
    {
      ...ticket('4', {
        category: 'Baños',
        title: 'Fuga de otra persona',
        status: 'CERRADO',
        createdAt: '2026-11-20T10:00:00Z',
        closedAt: '2026-11-21T10:00:00Z',
      }),
      ownerId: 'w-2',
    },
  ]);
  const authService = new AuthService(users, env, { log: () => {} });
  const baseUrl = await start(crearApp({
    env,
    authService,
    ticketService: new TicketService(repo),
  }));
  const token = jwt.sign({ role: 'COLABORADOR' }, jwtSecret, { subject: 'w-1' });

  const response = await fetch(
    `${baseUrl}/api/tickets/historial?rango=30d&estado=finished&categoria=banos&q=fuga`,
    { headers: { authorization: `Bearer ${token}` } },
  );
  assert.equal(response.status, 200);
  const { tickets, total } = (await response.json()).data;
  assert.equal(total, 1);
  assert.deepEqual(tickets.map((item) => item.id), ['1']);
  assert.equal(tickets[0].category, 'Baños');
});

test('GET /api/tickets/historial filtra estados activos y rechaza filtros inválidos', async () => {
  const users = await crearRepositorioEnMemoria([
    { id: 'w-1', name: 'Ana', email: 'ana@gamaitaly.cl', password: 'Temporal2026!', role: 'COLABORADOR', termsAccepted: true },
  ]);
  const repo = new MemoryTicketRepository([
    ticket('1', {
      category: 'Baños',
      title: 'Fuga actual',
      status: 'RECIBIDO',
      createdAt: new Date(),
    }),
  ]);
  const authService = new AuthService(users, env, { log: () => {} });
  const baseUrl = await start(crearApp({
    env,
    authService,
    ticketService: new TicketService(repo),
  }));
  const token = jwt.sign({ role: 'COLABORADOR' }, jwtSecret, { subject: 'w-1' });
  const headers = { authorization: `Bearer ${token}` };

  const active = await fetch(`${baseUrl}/api/tickets/historial?estado=active&rango=7d`, { headers });
  assert.equal(active.status, 200);
  assert.deepEqual((await active.json()).data.tickets.map((item) => item.id), ['1']);

  const invalid = await fetch(`${baseUrl}/api/tickets/historial?estado=unknown`, { headers });
  assert.equal(invalid.status, 400);
});

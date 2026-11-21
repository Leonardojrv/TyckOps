import assert from 'node:assert/strict';
import { after, test } from 'node:test';
import jwt from 'jsonwebtoken';
import { crearApp } from '../src/app.js';
import { AuthService } from '../src/modules/auth/auth.service.js';
import { crearRepositorioEnMemoria } from '../src/modules/auth/auth.memory.repository.js';
import { MemoryTicketRepository } from '../src/modules/tickets/tickets.memory.repository.js';
import { TicketService } from '../src/modules/tickets/tickets.service.js';

const jwtSecret = 'test-secret-with-more-than-thirty-two-characters';
const env = { jwtSecret, jwtExpiresIn: '1h', corsOrigin: '*' };
const servers = [];

async function start(app) {
  const server = app.listen(0, '127.0.0.1');
  servers.push(server);
  await new Promise((resolve) => server.once('listening', resolve));
  return `http://127.0.0.1:${server.address().port}`;
}

after(async () => {
  await Promise.all(servers.map((server) => new Promise((resolve) => server.close(resolve))));
});

function tokenPara(usuario) {
  return jwt.sign(
    { role: usuario.role, termsAccepted: usuario.termsAccepted ?? true, isFirstLogin: false },
    jwtSecret,
    { subject: usuario.id, expiresIn: '1h' },
  );
}

test('GET /tickets/mios, GET /tickets/resumen y GET /tickets/:id (dueño o administrador)', async () => {
  const userRepo = await crearRepositorioEnMemoria([
    { id: 'worker-1', name: 'Camila', email: 'camila@gamaitaly.cl', password: 'WorkerPassword2026!', role: 'COLABORADOR', termsAccepted: true, isFirstLogin: false },
    { id: 'worker-2', name: 'Diego', email: 'diego@gamaitaly.cl', password: 'WorkerPassword2026!', role: 'COLABORADOR', termsAccepted: true, isFirstLogin: false },
    { id: 'admin-1', name: 'Felipe', email: 'admin@gamaitaly.cl', password: 'AdminPassword2026!', role: 'ADMINISTRADOR', termsAccepted: true, isFirstLogin: false },
  ]);
  const authService = new AuthService(userRepo, env);

  const ticketRepo = new MemoryTicketRepository([
    {
      id: '101',
      code: 'REP-0101',
      category: 'Eléctrica',
      title: 'Enchufe sin corriente',
      status: 'RECIBIDO',
      priority: 'ALTA',
      location: 'Piso 2 · Sala 4',
      createdAt: new Date('2026-11-18T10:00:00Z'),
      ownerId: 'worker-1',
    },
    {
      id: '102',
      code: 'REP-0102',
      category: 'Baños',
      title: 'Lavamanos con fuga',
      status: 'EN_PROCESO',
      priority: 'MEDIA',
      location: 'Piso 1 · Baño hombres',
      createdAt: new Date('2026-11-17T15:00:00Z'),
      ownerId: 'worker-1',
    },
    {
      id: '103',
      code: 'REP-0103',
      category: 'Inmobiliario',
      title: 'Cajón roto',
      status: 'CERRADO',
      priority: 'BAJA',
      location: 'Piso 3',
      createdAt: new Date('2026-11-10T12:00:00Z'),
      ownerId: 'worker-1',
    },
    {
      id: '201',
      code: 'REP-0201',
      category: 'Aire acondicionado',
      title: 'Fuga de agua del split',
      status: 'EN_REVISION',
      priority: 'ALTA',
      location: 'Piso 4',
      createdAt: new Date('2026-11-19T08:00:00Z'),
      ownerId: 'worker-2',
    },
  ]);

  const ticketService = new TicketService(ticketRepo, { slaCumplido: 95.5 });
  const baseUrl = await start(crearApp({ env, authService, ticketService }));

  const tokenWorker1 = tokenPara({ id: 'worker-1', role: 'COLABORADOR' });
  const tokenWorker2 = tokenPara({ id: 'worker-2', role: 'COLABORADOR' });
  const tokenAdmin = tokenPara({ id: 'admin-1', role: 'ADMINISTRADOR' });

  // 1. GET /tickets/resumen devuelve conteo de tickets activos del home
  {
    const res = await fetch(`${baseUrl}/tickets/resumen`, {
      headers: { Authorization: `Bearer ${tokenWorker1}` },
    });
    assert.equal(res.status, 200);
    const json = await res.json();
    assert.equal(json.success, true);
    assert.equal(json.data.total, 3);
    assert.equal(json.data.activos, 2); // RECIBIDO + EN_PROCESO (CERRADO no está activo)
    assert.equal(json.data.enAtencion, 2);
    assert.equal(json.data.slaCumplido, 95.5);
  }

  // 2. GET /tickets/mios lista los tickets del usuario autenticado con su estado
  {
    const res = await fetch(`${baseUrl}/tickets/mios`, {
      headers: { Authorization: `Bearer ${tokenWorker1}` },
    });
    assert.equal(res.status, 200);
    const json = await res.json();
    assert.equal(json.success, true);
    assert.equal(json.data.tickets.length, 3);
    assert.deepEqual(
      json.data.tickets.map((t) => t.id),
      ['101', '102', '103'], // ordenados por fecha descendente
    );
    assert.equal(json.data.tickets[0].status, 'RECIBIDO');
    assert.equal(json.data.tickets[1].status, 'EN_PROCESO');
    assert.equal(json.data.tickets[2].status, 'CERRADO');
  }

  // 3. GET /tickets/:id:
  // a) El dueño (colaborador) puede ver su ticket
  {
    const res = await fetch(`${baseUrl}/tickets/101`, {
      headers: { Authorization: `Bearer ${tokenWorker1}` },
    });
    assert.equal(res.status, 200);
    const json = await res.json();
    assert.equal(json.data.ticket.id, '101');
    assert.equal(json.data.ticket.title, 'Enchufe sin corriente');
  }

  // b) Un colaborador ajeno NO puede ver el ticket de otro: responde 404
  {
    const res = await fetch(`${baseUrl}/tickets/101`, {
      headers: { Authorization: `Bearer ${tokenWorker2}` },
    });
    assert.equal(res.status, 404);
    const json = await res.json();
    assert.equal(json.error.code, 'TICKET_NO_ENCONTRADO');
  }

  // c) Un administrador SÍ puede ver el detalle de cualquier ticket
  {
    const res1 = await fetch(`${baseUrl}/tickets/101`, {
      headers: { Authorization: `Bearer ${tokenAdmin}` },
    });
    assert.equal(res1.status, 200);
    const json1 = await res1.json();
    assert.equal(json1.data.ticket.id, '101');
    assert.equal(json1.data.ticket.code, 'REP-0101');

    const res2 = await fetch(`${baseUrl}/tickets/201`, {
      headers: { Authorization: `Bearer ${tokenAdmin}` },
    });
    assert.equal(res2.status, 200);
    const json2 = await res2.json();
    assert.equal(json2.data.ticket.id, '201');
    assert.equal(json2.data.ticket.title, 'Fuga de agua del split');
  }

  // d) Sin token responde 401
  {
    const res = await fetch(`${baseUrl}/tickets/101`);
    assert.equal(res.status, 401);
  }

  // e) Ticket inexistente responde 404 para cualquiera
  {
    const res = await fetch(`${baseUrl}/tickets/99999`, {
      headers: { Authorization: `Bearer ${tokenAdmin}` },
    });
    assert.equal(res.status, 404);
  }
});

// ¿PARA QUÉ SIRVE?
//   Prueba el Home del administrador y el "Listado de personal" (T13).
//
// ¿QUÉ HACE?
//   Revisa que solo un administrador vea el listado y el resumen, que cada
//   persona traiga su área, rol y resumen de tickets, que no salgan datos
//   sensibles y que los números del Home cuadren.
//
// ¿CÓMO LO CAMBIO?
//   Si la pantalla pide otro dato, súmalo aquí y corre `pnpm test`.

import assert from 'node:assert/strict';
import { after, test } from 'node:test';
import jwt from 'jsonwebtoken';
import { crearApp } from '../src/app.js';
import { crearRepositorioEnMemoria } from '../src/modules/auth/auth.memory.repository.js';
import { AuthService } from '../src/modules/auth/auth.service.js';
import { MemoryPersonalRepository } from '../src/modules/personal/personal.repository.js';

const jwtSecret = 'test-secret-with-more-than-thirty-two-characters';
const env = { jwtSecret, jwtExpiresIn: '1h', corsOrigin: '*' };
const servers = [];
after(() => Promise.all(servers.map((s) => new Promise((r) => s.close(r)))));

const hoy = new Date();
const tickets = [
  { id: '1', ownerId: 'w-1', status: 'RECIBIDO', priority: 'ALTA' },
  { id: '2', ownerId: 'w-1', status: 'EN_PROCESO', priority: 'MEDIA' },
  { id: '3', ownerId: 'w-2', status: 'EN_REVISION', priority: 'MEDIA', originalId: '1' },
  { id: '4', ownerId: 'w-2', status: 'RESUELTO', priority: 'BAJA', closedAt: hoy },
  { id: '5', ownerId: 'w-2', status: 'CANCELADO', priority: null },
];

async function preparar() {
  const users = await crearRepositorioEnMemoria([
    { id: 'w-1', name: 'Camila', email: 'camila@gamaitaly.cl', password: 'Temporal2026!', role: 'COLABORADOR', termsAccepted: true },
    { id: 'a-1', name: 'Felipe', email: 'felipe@gamaitaly.cl', password: 'Temporal2026!', role: 'ADMINISTRADOR', termsAccepted: true },
  ]);
  const personalRepository = new MemoryPersonalRepository({
    personas: [
      { id: 'w-1', name: 'Camila', appat: 'Soto', apmat: 'Valenzuela', email: 'camila@gamaitaly.cl', area: 'Tesorería', role: 'colaborador' },
      { id: 'w-2', name: 'Rodrigo', appat: 'Palma', apmat: '', email: 'rodrigo@gmail.com', area: 'Marketing', role: 'colaborador' },
      { id: 'a-1', name: 'Felipe', appat: 'Morales', apmat: '', email: 'felipe@gamaitaly.cl', area: 'Gerencia', role: 'administrador' },
    ],
    tickets,
  });
  const app = crearApp({ env, authService: new AuthService(users, env, { log: () => {} }), personalRepository });
  const server = app.listen(0);
  servers.push(server);
  await new Promise((r) => server.once('listening', r));
  const base = `http://127.0.0.1:${server.address().port}/api/admin`;
  return (ruta, sub, role) => fetch(base + ruta, {
    headers: sub ? { authorization: `Bearer ${jwt.sign({ role }, jwtSecret, { subject: sub })}` } : {},
  });
}

test('T13: solo el administrador ve el personal y el resumen', async () => {
  const get = await preparar();
  assert.equal((await get('/personal')).status, 401);
  assert.equal((await get('/personal', 'w-1', 'COLABORADOR')).status, 403);
  assert.equal((await get('/resumen', 'w-1', 'COLABORADOR')).status, 403);
  assert.equal((await get('/personal', 'a-1', 'ADMINISTRADOR')).status, 200);
});

test('T13: cada persona trae área, rol y su resumen de tickets, sin datos sensibles', async () => {
  const get = await preparar();
  const { personal } = (await (await get('/personal', 'a-1', 'ADMINISTRADOR')).json()).data;
  assert.deepEqual(personal.map((p) => p.nombre), ['Camila Soto Valenzuela', 'Felipe Morales', 'Rodrigo Palma']);

  const camila = personal[0];
  assert.equal(camila.area, 'Tesorería');
  assert.equal(camila.rol, 'COLABORADOR');
  assert.deepEqual(camila.tickets, { activos: 2, urgentes: 1, enProceso: 1, resueltosHoy: 0 });
  assert.equal(personal[1].rol, 'ADMINISTRADOR');
  assert.equal(personal[2].tickets.resueltosHoy, 1);

  for (const p of personal) {
    assert.deepEqual(Object.keys(p).sort(), ['activo', 'area', 'email', 'id', 'nombre', 'rol', 'tickets']);
  }
});

test('T13: los números del Home', async () => {
  const get = await preparar();
  const resumen = (await (await get('/resumen', 'a-1', 'ADMINISTRADOR')).json()).data;
  assert.deepEqual(resumen, { pendientes: 2, urgentes: 1, duplicados: 1, activos: 3, personal: 3 });
});

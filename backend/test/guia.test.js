// ¿PARA QUÉ SIRVE?
//   Prueba la asistencia de IA del colaborador (T10): la guía de autoayuda,
//   "Cerrar ticket", "Reportar a administración" y los tickets duplicados.
//
// ¿QUÉ HACE?
//   Revisa que la guía solo exista para tickets propios de prioridad Baja en
//   Recibido, que cerrar y escalar cambien lo correcto una sola vez, que un
//   ticket ajeno responda 404 y que el duplicado muestre el original sin datos
//   de su dueño.
//
// ¿CÓMO LO CAMBIO?
//   Si cambia una regla (por ejemplo, a qué prioridad sube al escalar), ajusta
//   esta prueba y corre `pnpm test`.

import assert from 'node:assert/strict';
import { after, test } from 'node:test';
import jwt from 'jsonwebtoken';
import { crearApp } from '../src/app.js';
import { crearRepositorioEnMemoria } from '../src/modules/auth/auth.memory.repository.js';
import { AuthService } from '../src/modules/auth/auth.service.js';
import { elegirGuia, pasosDesdeTexto } from '../src/modules/tickets/tickets.guia.js';
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

function ticket(id, ownerId, status, priority, extra = {}) {
  return {
    id, ownerId, code: `REP-${id}`, category: 'Electricidad', title: `Falla ${id}`, status, priority,
    location: 'Piso 2', createdAt: new Date('2026-11-20T10:00:00Z'), ...extra,
  };
}

async function preparar(guiasVigentes = []) {
  const users = await crearRepositorioEnMemoria([
    { id: 'w-1', name: 'Ana', email: 'ana@gamaitaly.cl', password: 'Temporal2026!', role: 'COLABORADOR', termsAccepted: true },
    { id: 'w-2', name: 'Beto', email: 'beto@gmail.com', password: 'Temporal2026!', role: 'COLABORADOR', termsAccepted: true },
  ]);
  const repo = new MemoryTicketRepository([
    ticket('1', 'w-1', 'RECIBIDO', 'BAJA'),
    ticket('2', 'w-1', 'RECIBIDO', 'BAJA'),
    ticket('3', 'w-1', 'RECIBIDO', 'MEDIA'),
    ticket('4', 'w-1', 'EN_REVISION', 'BAJA'),
    ticket('9', 'w-2', 'EN_REVISION', 'ALTA', { description: 'Aire gotea en sala B' }),
    ticket('10', 'w-1', 'RECIBIDO', 'MEDIA', { originalId: '9' }),
  ]);
  const auditoria = [];
  const ticketService = new TicketService(repo, {
    auditLogger: { info: (linea) => auditoria.push(JSON.parse(linea)) },
    obtenerGuiasVigentes: async () => guiasVigentes,
  });
  const authService = new AuthService(users, env, { log: () => {} });
  const baseUrl = await start(crearApp({ env, authService, ticketService }));
  const headers = (sub, role = 'COLABORADOR') => ({ authorization: `Bearer ${jwt.sign({ role }, jwtSecret, { subject: sub })}` });
  const get = (path, sub = 'w-1') => fetch(`${baseUrl}/api/tickets/${path}`, { headers: headers(sub) });
  const post = (path, sub = 'w-1', role) => fetch(`${baseUrl}/api/tickets/${path}`, { method: 'POST', headers: headers(sub, role) });
  return { get, post, auditoria, repo };
}

test('T10: la guía solo aparece en tickets propios de prioridad Baja y en Autogestión', async () => {
  const { get, post } = await preparar();

  const detalle = (await (await get('1')).json()).data.ticket;
  assert.equal(detalle.selfHelp, true);
  assert.equal((await (await get('3')).json()).data.ticket.selfHelp, false, 'prioridad media: sin guía');
  assert.equal((await (await get('4')).json()).data.ticket.selfHelp, false, 'ya en revisión: sin guía');

  const res = await get('1/guia');
  assert.equal(res.status, 404, 'la guía requiere iniciar primero la autogestión');
  const iniciado = await post('1/guia/iniciar');
  assert.equal(iniciado.status, 200);
  assert.equal((await iniciado.json()).data.ticket.status, 'AUTOGESTION');

  const resGuia = await get('1/guia');
  assert.equal(resGuia.status, 200);
  const { guia } = (await resGuia.json()).data;
  assert.equal(guia.origen, 'simulada');
  assert.ok(guia.pasos.length >= 2);
  assert.ok(guia.pasos.every((p) => p.titulo));

  assert.equal((await get('3/guia')).status, 404);
  assert.equal((await get('9/guia')).status, 404, 'ticket ajeno: 404');
  assert.equal((await get(`${encodeURIComponent('../1')}/guia`)).status, 404);
});

test('T10: cerrar (la guía funcionó) y escalar (no funcionó), una sola vez', async () => {
  const { post, get, auditoria, repo } = await preparar();

  assert.equal((await post('1/guia/cerrar', 'w-1', 'ADMINISTRADOR')).status, 403);
  assert.equal((await post('9/guia/cerrar')).status, 404, 'ajeno');
  assert.equal((await post('3/guia/cerrar')).status, 409, 'prioridad media: no aplica');

  assert.equal((await post('1/guia/iniciar')).status, 200);
  assert.equal((await post('2/guia/iniciar')).status, 200);
  const cerrado = await post('1/guia/cerrar');
  assert.equal(cerrado.status, 200);
  const t1 = (await cerrado.json()).data.ticket;
  assert.equal(t1.status, 'CERRADO');
  assert.ok(t1.closedAt);
  assert.equal((await (await get('1')).json()).data.ticket.closedBySelfHelp, true);
  assert.equal((await post('1/guia/escalar')).status, 409, 'ya decidió');

  const escalado = await post('2/guia/escalar');
  assert.equal(escalado.status, 200);
  const t2 = (await escalado.json()).data.ticket;
  assert.equal(t2.status, 'RECIBIDO', 'sigue Recibido, ahora en la bandeja del administrador');
  assert.equal(t2.priority, 'MEDIA');
  assert.equal((await (await get('2')).json()).data.ticket.selfHelp, false, 'la guía ya no se ofrece');
  assert.ok(!('solutionType' in t2), 'el dato interno no sale en la API');

  assert.deepEqual(repo.historialEstados.map(({ estadoAnterior, estadoNuevo }) => [estadoAnterior, estadoNuevo]), [
    ['RECIBIDO', 'AUTOGESTION'],
    ['RECIBIDO', 'AUTOGESTION'],
    ['AUTOGESTION', 'CERRADO'],
    ['AUTOGESTION', 'RECIBIDO'],
  ]);
  assert.equal(repo.historialEstados[2].actorId, 'w-1');
  assert.match(repo.historialEstados[2].motivo, /Cierre por autogestión/);
  assert.match(repo.historialEstados[3].motivo, /reportado a Servicios Generales/);
  assert.deepEqual(auditoria.map((a) => a.action), [
    'autogestion_iniciada',
    'autogestion_iniciada',
    'ticket_cerrado_autoayuda',
    'ticket_escalado_colaborador',
  ]);
});

test('T10: el duplicado muestra el original sin datos de su dueño', async () => {
  const { get, repo } = await preparar();

  const dup = (await (await get('10')).json()).data.ticket;
  assert.equal(dup.duplicateOf.code, 'REP-9');
  assert.equal(dup.duplicateOf.status, 'EN_REVISION');
  assert.equal(dup.duplicateOf.title, 'Aire gotea en sala B');
  assert.deepEqual(Object.keys(dup.duplicateOf).sort(), ['category', 'code', 'createdAt', 'id', 'location', 'mine', 'status', 'title']);
  assert.equal((await (await get('1')).json()).data.ticket.duplicateOf, null);

  // Guardar el duplicado: solo si sigue Recibido y nunca consigo mismo.
  assert.equal(await repo.marcarDuplicado('2', '2'), false);
  assert.equal(await repo.marcarDuplicado('4', '9'), false, 'ya en revisión');
  assert.equal(await repo.marcarDuplicado('2', '9'), true);
  assert.equal(await repo.marcarDuplicado('2', '9'), false, 'ya estaba agrupado');
});

test('T10: la guía vigente del administrador gana a la simulada y se limpia', () => {
  assert.deepEqual(pasosDesdeTexto('1. Revisar interruptor: que esté encendido.\n2. <b>Probar</b> otro enchufe.\n\n'), [
    { titulo: 'Revisar interruptor', detalle: 'que esté encendido.' },
    { titulo: 'Probar otro enchufe.', detalle: '' },
  ]);
  const vigentes = [
    { id: 'g-9', categoria: 'Baños', problema: 'Dispensador vacío', pasos: '1. Reponer', autogestionable: true },
    { id: 'g-1', categoria: 'Eléctrica', problema: 'Luz no enciende', pasos: '1. Revisar interruptor.', autogestionable: true },
  ];
  const guia = elegirGuia({ category: 'Electricidad' }, vigentes);
  assert.equal(guia.origen, 'vigente');
  assert.equal(guia.id, 'g-1');
  assert.equal(elegirGuia({ category: 'Aire acondicionado' }, vigentes).origen, 'simulada');
});

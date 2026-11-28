// ¿PARA QUÉ SIRVE?
//   Prueba GET /api/tickets/:id/estado: el colaborador consulta si su ticket
//   fue marcado como duplicado y en qué quedó (resolución).
//
// ¿QUÉ HACE?
//   Revisa permisos (solo el dueño colaborador, ajeno = 404), que el aviso de
//   duplicado no muestre datos del otro dueño, que el motivo solo viaje si está
//   rechazado y el tipo de resolución de cada estado.
//
// ¿CÓMO LO CAMBIO?
//   Si cambias la respuesta en tickets.service.js (estado / tipoResolucion),
//   ajusta esta prueba y corre `pnpm test`.

import assert from 'node:assert/strict';
import { after, test } from 'node:test';
import jwt from 'jsonwebtoken';
import { crearApp } from '../src/app.js';
import { crearRepositorioEnMemoria } from '../src/modules/auth/auth.memory.repository.js';
import { AuthService } from '../src/modules/auth/auth.service.js';
import { MemoryTicketRepository } from '../src/modules/tickets/tickets.memory.repository.js';
import { TicketService, tipoResolucion } from '../src/modules/tickets/tickets.service.js';

const jwtSecret = 'test-secret-with-more-than-thirty-two-characters';
const env = { jwtSecret, jwtExpiresIn: '1h', corsOrigin: '*' };
const servers = [];
after(async () => {
  await Promise.all(servers.map((server) => new Promise((resolve) => server.close(resolve))));
});

const ahora = new Date('2026-11-20T10:00:00Z');
const MOTIVO = 'No corresponde a Servicios Generales: el equipo pertenece al proveedor externo y lo debe revisar su soporte técnico.';

async function preparar() {
  const users = await crearRepositorioEnMemoria([
    { id: 'w-1', name: 'Ana', email: 'ana@gamaitaly.cl', password: 'Temporal2026!', role: 'COLABORADOR', termsAccepted: true },
    { id: 'w-2', name: 'Beto', email: 'beto@gamaitaly.cl', password: 'Temporal2026!', role: 'COLABORADOR', termsAccepted: true },
    { id: 'a-1', name: 'Admin', email: 'admin@gamaitaly.cl', password: 'Temporal2026!', role: 'ADMINISTRADOR', termsAccepted: true },
  ]);
  const base = { ownerId: 'w-1', category: 'Eléctrica', location: 'Piso 2', title: 'Enchufe con chispas', createdAt: ahora };
  const tickets = new MemoryTicketRepository([
    { ...base, id: '1', code: 'REP-0001', status: 'EN_PROCESO', priority: 'ALTA', ownerId: 'w-2' }, // original de otra persona
    { ...base, id: '2', code: 'REP-0002', status: 'RECIBIDO', priority: 'MEDIA', originalId: '1' }, // duplicado
    { ...base, id: '3', code: 'REP-0003', status: 'RECHAZADO', priority: 'MEDIA', rejectionReason: MOTIVO, closedAt: ahora },
    { ...base, id: '4', code: 'REP-0004', status: 'APROBADO', priority: 'MEDIA', rejectionReason: 'texto viejo' },
    { ...base, id: '5', code: 'REP-0005', status: 'CERRADO', priority: 'BAJA', solutionType: 'autoayuda_ia', closedAt: ahora },
  ]);
  const app = crearApp({
    env,
    authService: new AuthService(users, env, { log: () => {} }),
    ticketService: new TicketService(tickets, { auditLogger: { info: () => {} } }),
  });
  const server = app.listen(0);
  servers.push(server);
  await new Promise((resolve) => server.once('listening', resolve));
  const baseUrl = `http://127.0.0.1:${server.address().port}`;
  const token = (sub, role = 'COLABORADOR') => `Bearer ${jwt.sign({ role }, jwtSecret, { subject: sub })}`;
  return (id, sub = 'w-1', role) => fetch(`${baseUrl}/api/tickets/${id}/estado`, { headers: { authorization: token(sub, role) } });
}

test('duplicado: lo informa con un resumen del original, sin datos de su dueño', async () => {
  const consultar = await preparar();
  const respuesta = await consultar('2');
  assert.equal(respuesta.status, 200);
  const { data } = await respuesta.json();
  assert.deepEqual(data, {
    id: '2',
    code: 'REP-0002',
    status: 'RECIBIDO',
    priority: 'MEDIA',
    duplicate: { isDuplicate: true, original: { id: '1', code: 'REP-0001', status: 'EN_PROCESO', mine: false } },
    resolution: { type: 'pendiente', reason: null, closedAt: null },
  });
});

test('no duplicado: isDuplicate false y original null', async () => {
  const consultar = await preparar();
  const { data } = await (await consultar('4')).json();
  assert.deepEqual(data.duplicate, { isDuplicate: false, original: null });
  assert.equal(data.resolution.type, 'en_gestion');
  assert.equal(data.resolution.reason, null, 'el motivo solo viaja si está rechazado');
});

test('rechazado: informa el motivo y la fecha de cierre (RF-07)', async () => {
  const consultar = await preparar();
  const { data } = await (await consultar('3')).json();
  assert.deepEqual(data.resolution, { type: 'rechazado', reason: MOTIVO, closedAt: ahora.toISOString() });
});

test('cerrado con la guía: resolución cerrado_autoayuda', async () => {
  const consultar = await preparar();
  const { data } = await (await consultar('5')).json();
  assert.equal(data.resolution.type, 'cerrado_autoayuda');
});

test('solo el colaborador dueño: ajeno, inexistente o id raro = 404; administrador = 403', async () => {
  const consultar = await preparar();
  assert.equal((await consultar('1')).status, 404, 'el ticket 1 es de otra persona');
  assert.equal((await consultar('999')).status, 404);
  assert.equal((await consultar('..%2F1')).status, 404);
  assert.equal((await consultar('2', 'a-1', 'ADMINISTRADOR')).status, 403);
});

test('tipoResolucion cubre todo el ciclo de vida', () => {
  const casos = {
    RECIBIDO: 'pendiente', AUTOGESTION: 'autogestion', EN_REVISION: 'en_gestion', APROBADO: 'en_gestion', EN_PROCESO: 'en_gestion',
    RESUELTO: 'resuelto', CERRADO: 'cerrado', RECHAZADO: 'rechazado', CANCELADO: 'cancelado',
  };
  for (const [status, tipo] of Object.entries(casos)) assert.equal(tipoResolucion({ status }), tipo, status);
});

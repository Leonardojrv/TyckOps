// ¿PARA QUÉ SIRVE?
//   Prueba el rechazo de un ticket con el motivo del administrador (RF-07 / RF-17),
//   en memoria: sin PostgreSQL (el flujo contra la base real está en
//   integracion/flujo-estados.spec.js).
//
// ¿QUÉ HACE?
//   1. Servicio: el motivo es obligatorio (no nulo, no vacío, no solo espacios,
//      entre 100 y 255 caracteres), se guarda sin espacios sobrantes, y si es
//      inválido no cambia nada ni avisa a nadie.
//   2. Controlador (PATCH /api/admin/tickets/:id/estado por HTTP): mismas reglas,
//      la respuesta trae el motivo y el colaborador recibe el aviso con él.
//
// ¿CÓMO LO CAMBIO?
//   Los límites están en tickets.service.js (MOTIVO_RECHAZO_MIN / MAX). Si los
//   cambias, cambia también el CHECK ck_ticket_motivo_rechazo y corre `pnpm test`.

import assert from 'node:assert/strict';
import { after, test } from 'node:test';
import jwt from 'jsonwebtoken';
import { crearApp } from '../src/app.js';
import { crearRepositorioEnMemoria } from '../src/modules/auth/auth.memory.repository.js';
import { AuthService } from '../src/modules/auth/auth.service.js';
import { MemoryNotificacionesRepository } from '../src/modules/notificaciones/notificaciones.repositories.js';
import { NotificacionesService } from '../src/modules/notificaciones/notificaciones.service.js';
import { MemoryTicketRepository } from '../src/modules/tickets/tickets.memory.repository.js';
import {
  MOTIVO_RECHAZO_MAX, MOTIVO_RECHAZO_MIN, TicketService, validarMotivoRechazo,
} from '../src/modules/tickets/tickets.service.js';

const jwtSecret = 'test-secret-with-more-than-thirty-two-characters';
const env = { jwtSecret, jwtExpiresIn: '1h', corsOrigin: '*' };
const servers = [];
after(async () => {
  await Promise.all(servers.map((server) => new Promise((resolve) => server.close(resolve))));
});

const MOTIVO = 'El equipo pertenece al proveedor externo de climatización y debe gestionarse por su mesa de soporte, según el contrato vigente.';

// Un ticket En revisión (el único estado desde el que se puede rechazar).
function preparar() {
  const tickets = new MemoryTicketRepository([
    { id: '7', code: 'REP-0007', ownerId: 'w-1', status: 'EN_REVISION', priority: 'MEDIA', title: 'Aire no enfría', createdAt: new Date() },
  ]);
  const avisos = new MemoryNotificacionesRepository();
  const notificaciones = new NotificacionesService(avisos, { enviar: async () => ({ invalidos: [] }) });
  const service = new TicketService(tickets, { auditLogger: { info: () => {} }, notificaciones });
  return { tickets, avisos, service };
}

// ---------- 1. Reglas del servicio ----------

test('validarMotivoRechazo: nulo, vacío, solo espacios, corto o largo = 400 DATOS_INVALIDOS', () => {
  const invalidos = [
    null, undefined, '', '     ', 123, { texto: MOTIVO },
    'x'.repeat(MOTIVO_RECHAZO_MIN - 1),
    `   ${'x'.repeat(MOTIVO_RECHAZO_MIN - 1)}   `, // los espacios no cuentan
    'x'.repeat(MOTIVO_RECHAZO_MAX + 1),
  ];
  for (const motivo of invalidos) {
    assert.throws(() => validarMotivoRechazo(motivo), { status: 400, code: 'DATOS_INVALIDOS' }, JSON.stringify(motivo));
  }
  assert.equal(validarMotivoRechazo(`  ${MOTIVO}  `), MOTIVO, 'se guarda sin espacios sobrantes');
  assert.equal(validarMotivoRechazo('x'.repeat(MOTIVO_RECHAZO_MIN)).length, MOTIVO_RECHAZO_MIN);
  assert.equal(validarMotivoRechazo('x'.repeat(MOTIVO_RECHAZO_MAX)).length, MOTIVO_RECHAZO_MAX);
});

test('servicio: un rechazo sin motivo válido no cambia el ticket ni avisa al colaborador', async () => {
  const { tickets, avisos, service } = preparar();
  for (const motivo of [null, '', '   ', 'No corresponde.']) {
    await assert.rejects(service.cambiarEstado('a-1', '7', 'RECHAZADO', motivo), { status: 400, code: 'DATOS_INVALIDOS' });
  }
  const ticket = await tickets.findById('7');
  assert.equal(ticket.status, 'EN_REVISION');
  assert.equal(ticket.rejectionReason, undefined);
  assert.equal(avisos.notificaciones.length, 0);
});

test('servicio: rechazo válido guarda el motivo limpio, lo devuelve y avisa al colaborador con él', async () => {
  const { tickets, avisos, service } = preparar();
  const respuesta = await service.cambiarEstado('a-1', '7', 'RECHAZADO', `\n  ${MOTIVO}  `);

  assert.equal(respuesta.status, 'RECHAZADO');
  assert.equal(respuesta.rejectionReason, MOTIVO);
  assert.ok(respuesta.closedAt);
  assert.equal((await tickets.findById('7')).rejectionReason, MOTIVO);

  assert.equal(avisos.notificaciones.length, 1);
  const [aviso] = avisos.notificaciones;
  assert.equal(aviso.ID_user, 'w-1', 'el aviso es para el dueño');
  assert.equal(aviso.Tipo, 'estado');
  assert.match(aviso.Cuerpo, /Motivo: El equipo pertenece al proveedor/);
});

test('servicio: en los demás estados el motivo se ignora y la respuesta trae rejectionReason null', async () => {
  const { tickets, service } = preparar();
  const respuesta = await service.cambiarEstado('a-1', '7', 'APROBADO', 'un texto que no corresponde');
  assert.equal(respuesta.status, 'APROBADO');
  assert.equal(respuesta.rejectionReason, null);
  assert.equal((await tickets.findById('7')).rejectionReason, undefined);
});

// ---------- 2. Controlador por HTTP ----------

async function servidor() {
  const users = await crearRepositorioEnMemoria([
    { id: 'w-1', name: 'Ana', email: 'ana@gamaitaly.cl', password: 'Temporal2026!', role: 'COLABORADOR', termsAccepted: true },
    { id: 'a-1', name: 'Admin', email: 'admin@gamaitaly.cl', password: 'Temporal2026!', role: 'ADMINISTRADOR', termsAccepted: true },
  ]);
  const { tickets, avisos, service } = preparar();
  const app = crearApp({ env, authService: new AuthService(users, env, { log: () => {} }), ticketService: service });
  const server = app.listen(0);
  servers.push(server);
  await new Promise((resolve) => server.once('listening', resolve));
  const url = `http://127.0.0.1:${server.address().port}/api/admin/tickets/7/estado`;
  const token = (sub, role) => `Bearer ${jwt.sign({ role }, jwtSecret, { subject: sub })}`;
  const rechazar = (cuerpo, { sub = 'a-1', role = 'ADMINISTRADOR' } = {}) => fetch(url, {
    method: 'PATCH',
    headers: { authorization: token(sub, role), 'content-type': 'application/json' },
    body: typeof cuerpo === 'string' ? cuerpo : JSON.stringify(cuerpo),
  });
  return { tickets, avisos, rechazar };
}

test('PATCH /estado: payload inválido = 400 con mensaje claro y el ticket no cambia', async () => {
  const { tickets, avisos, rechazar } = await servidor();
  const casos = [
    { estado: 'RECHAZADO' }, // sin motivo
    { estado: 'RECHAZADO', motivo: null },
    { estado: 'RECHAZADO', motivo: '' },
    { estado: 'RECHAZADO', motivo: '      ' },
    { estado: 'RECHAZADO', motivo: 'Muy corto' },
    { estado: 'RECHAZADO', motivo: 'x'.repeat(MOTIVO_RECHAZO_MAX + 1) },
    { estado: 'RECHAZADO', motivo: 12345 },
  ];
  for (const cuerpo of casos) {
    const res = await rechazar(cuerpo);
    assert.equal(res.status, 400, JSON.stringify(cuerpo));
    const { error } = await res.json();
    assert.equal(error.code, 'DATOS_INVALIDOS');
    assert.ok(error.message.length > 0);
  }
  // JSON mal formado también es 400 (no 500).
  assert.equal((await rechazar('{"estado": "RECHAZADO", ')).status, 400);

  assert.equal((await tickets.findById('7')).status, 'EN_REVISION');
  assert.equal(avisos.notificaciones.length, 0);
});

test('PATCH /estado: rechazo válido responde 200 con el motivo en el ticket', async () => {
  const { tickets, avisos, rechazar } = await servidor();
  const res = await rechazar({ estado: 'rechazado', motivo: `  ${MOTIVO}  ` });
  assert.equal(res.status, 200);
  const { data } = await res.json();
  assert.equal(data.ticket.status, 'RECHAZADO');
  assert.equal(data.ticket.rejectionReason, MOTIVO);
  assert.equal((await tickets.findById('7')).rejectionReason, MOTIVO);
  assert.equal(avisos.notificaciones.length, 1);
});

test('PATCH /estado: solo un administrador puede rechazar', async () => {
  const { tickets, rechazar } = await servidor();
  const res = await rechazar({ estado: 'RECHAZADO', motivo: MOTIVO }, { sub: 'w-1', role: 'COLABORADOR' });
  assert.equal(res.status, 403);
  assert.equal((await tickets.findById('7')).status, 'EN_REVISION');
});

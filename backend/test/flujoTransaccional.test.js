// ¿PARA QUÉ SIRVE?
//   Prueba el flujo transaccional del ticket operativo (falla real que gestiona
//   Servicios Generales del lado del administrador).
//
// ¿QUÉ HACE?
//   Revisa los valores por defecto (estado Recibido y prioridad Media si la IA
//   no respondió), que el historial registre quién hizo cada cambio, que un ticket sin
//   prioridad no pase a gestión y el ciclo completo
//   Recibido → En revisión → Aprobado → En proceso → Resuelto → Cerrado
//   por los dos caminos: media/alta desde la creación y baja escalada.
//
// ¿CÓMO LO CAMBIO?
//   Si cambias el ciclo de vida (TRANSICIONES_TICKET en ticket-states.js) o la prioridad por
//   defecto, ajusta esta prueba y corre `pnpm test`.

import assert from 'node:assert/strict';
import { test } from 'node:test';
import { MemoryTicketRepository } from '../src/modules/tickets/tickets.memory.repository.js';
import { PRIORIDAD_POR_DEFECTO, TicketService } from '../src/modules/tickets/tickets.service.js';

const silencio = { info: () => {} };

function preparar({ tickets = [], analizadorIA = null } = {}) {
  const repo = new MemoryTicketRepository(tickets);
  const service = new TicketService(repo, { auditLogger: silencio, analizadorIA });
  return { repo, service };
}

async function nuevoTicket(repo, ownerId = 'w-1') {
  return repo.create({ ownerId, category: 'ELECTRICA', location: 'Piso 2, Sala B', description: 'El enchufe echa chispas' });
}

// Recorre el ciclo completo del administrador y revisa cada paso.
async function cicloCompleto(service, repo, id, adminId = 'a-1') {
  const pasos = ['EN_REVISION', 'APROBADO', 'EN_PROCESO', 'RESUELTO', 'CERRADO'];
  for (const estado of pasos) {
    const ticket = await service.cambiarEstado(adminId, id, estado);
    assert.equal(ticket.status, estado);
  }
  const final = await repo.findById(id);
  const aprobacion = repo.historialEstados.find((h) => h.ticketId === id && h.estadoNuevo === 'APROBADO');
  assert.equal(aprobacion?.actorId, adminId, 'el historial registra quién aprobó');
  assert.ok(final.closedAt, 'al cerrar queda la fecha de cierre');
  return final;
}

test('sin motor de IA: el ticket queda Recibido con prioridad Media (origen "defecto")', async () => {
  const { repo, service } = preparar();
  const ticket = await nuevoTicket(repo);
  const resultado = await service.enrutarTicket(ticket);
  assert.equal(resultado.resultado, 'pendiente_ia');

  const guardado = await repo.findById(ticket.id);
  assert.equal(guardado.status, 'RECIBIDO');
  assert.equal(guardado.priority, PRIORIDAD_POR_DEFECTO);
  assert.equal(guardado.priority, 'MEDIA', 'nunca Baja: una falla que nadie evaluó no va a la guía');
  assert.equal(guardado.initialPriority, 'MEDIA');
  assert.equal(guardado.priorityOrigin, 'defecto');
});

test('si la IA falla: prioridad Media con origen "falla_ia"', async () => {
  const analizadorIA = { analizar: async () => { throw Object.assign(new Error('timeout'), { code: 'TIMEOUT' }); } };
  const { repo, service } = preparar({ analizadorIA });
  const ticket = await nuevoTicket(repo);
  const resultado = await service.enrutarTicket(ticket);
  assert.equal(resultado.resultado, 'error_ia');

  const guardado = await repo.findById(ticket.id);
  assert.equal(guardado.priority, 'MEDIA');
  assert.equal(guardado.priorityOrigin, 'falla_ia');
});

test('la prioridad por defecto no pisa una que ya existe ni un ticket que ya no está Recibido', async () => {
  const { repo, service } = preparar({
    tickets: [
      { id: '1', ownerId: 'w-1', status: 'RECIBIDO', priority: 'ALTA', createdAt: new Date() },
      { id: '2', ownerId: 'w-1', status: 'CANCELADO', priority: null, createdAt: new Date() },
    ],
  });
  await service.enrutarTicket(await repo.findById('1'));
  // El 2 no se envía (no está Recibido): queda sin prioridad.
  await service.enrutarTicket(await repo.findById('2'));
  assert.equal((await repo.findById('1')).priority, 'ALTA');
  assert.equal((await repo.findById('2')).priority, null);
});

test('camino 1: ticket Media/Alta (sin guía) recorre el ciclo completo y el historial registra al aprobador', async () => {
  const { repo, service } = preparar({
    tickets: [{ id: '10', ownerId: 'w-1', status: 'RECIBIDO', priority: 'ALTA', createdAt: new Date() }],
  });
  const final = await cicloCompleto(service, repo, '10', 'a-1');
  assert.equal(final.priority, 'ALTA', 'la prioridad de la IA se respeta');
});

test('camino 2: ticket Baja escalado por el colaborador (falla real) sube a Media y recorre el ciclo', async () => {
  const { repo, service } = preparar({
    tickets: [{ id: '20', ownerId: 'w-1', status: 'RECIBIDO', priority: 'BAJA', createdAt: new Date() }],
  });
  // Primero abre la guía (Recibido → Autogestión) y luego la escala.
  assert.equal((await service.iniciarAutogestion('w-1', '20')).status, 'AUTOGESTION');
  const escalado = await service.resolverGuia('w-1', '20', 'escalar');
  assert.equal(escalado.status, 'RECIBIDO', 'estado inicial del ticket operativo');
  assert.equal(escalado.priority, 'MEDIA');
  assert.equal((await repo.findById('20')).solutionType, 'escalado_colaborador');

  await cicloCompleto(service, repo, '20', 'a-2');
});

test('un ticket sin prioridad no pasa a gestión (409 TICKET_SIN_PRIORIDAD)', async () => {
  const { repo, service } = preparar({
    tickets: [{ id: '30', ownerId: 'w-1', status: 'RECIBIDO', priority: null, createdAt: new Date() }],
  });
  await assert.rejects(service.cambiarEstado('a-1', '30', 'EN_REVISION'), { status: 409, code: 'TICKET_SIN_PRIORIDAD' });
  assert.equal((await repo.findById('30')).status, 'RECIBIDO', 'no cambió nada');
});

test('nadie aprueba su propio ticket (409 APROBACION_PROPIA); otro administrador sí', async () => {
  const { repo, service } = preparar({
    tickets: [{ id: '40', ownerId: 'a-1', status: 'EN_REVISION', priority: 'MEDIA', createdAt: new Date() }],
  });
  await assert.rejects(service.cambiarEstado('a-1', '40', 'APROBADO'), { status: 409, code: 'APROBACION_PROPIA' });
  assert.equal((await repo.findById('40')).status, 'EN_REVISION');

  await service.cambiarEstado('a-2', '40', 'APROBADO');
  assert.equal(repo.historialEstados.at(-1).actorId, 'a-2');
});

test('rechazar queda en el historial con quién y por qué, y se mantiene el ciclo de vida', async () => {
  const { repo, service } = preparar({
    tickets: [{ id: '50', ownerId: 'w-1', status: 'EN_REVISION', priority: 'MEDIA', createdAt: new Date() }],
  });
  await service.cambiarEstado('a-1', '50', 'RECHAZADO', 'x'.repeat(100));
  const ticket = await repo.findById('50');
  assert.equal(ticket.status, 'RECHAZADO');
  assert.deepEqual(
    { actor: repo.historialEstados.at(-1).actorId, motivo: repo.historialEstados.at(-1).motivo },
    { actor: 'a-1', motivo: 'x'.repeat(100) },
  );
  // Saltarse pasos sigue prohibido.
  await assert.rejects(service.cambiarEstado('a-1', '50', 'EN_PROCESO'), { code: 'TRANSICION_NO_PERMITIDA' });
});

test('nadie rechaza su propio ticket (409 RECHAZO_PROPIO); otro administrador sí', async () => {
  const { repo, service } = preparar({
    tickets: [{ id: '60', ownerId: 'a-1', status: 'EN_REVISION', priority: 'MEDIA', createdAt: new Date() }],
  });
  await assert.rejects(service.cambiarEstado('a-1', '60', 'RECHAZADO', 'x'.repeat(100)), { status: 409, code: 'RECHAZO_PROPIO' });
  const intacto = await repo.findById('60');
  assert.equal(intacto.status, 'EN_REVISION');
  assert.equal(intacto.rejectionReason, undefined);

  await service.cambiarEstado('a-2', '60', 'RECHAZADO', 'x'.repeat(100));
  assert.equal((await repo.findById('60')).status, 'RECHAZADO');
  assert.equal(repo.historialEstados.at(-1).actorId, 'a-2');
});

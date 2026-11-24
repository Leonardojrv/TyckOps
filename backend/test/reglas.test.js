// ¿PARA QUÉ SIRVE?
//   Prueba el .txt de reglas de prioridad y sus rutas (MM2), y el cambio de
//   prioridad del administrador con su registro (quién y cuándo).
//
// ¿CÓMO LO CAMBIO?
//   Si cambia el formato del .txt (src/modules/reglas/reglas.parser.js),
//   ajusta los ejemplos de aquí.

import assert from 'node:assert/strict';
import { after, test } from 'node:test';
import jwt from 'jsonwebtoken';
import { crearApp } from '../src/app.js';
import { crearRepositorioEnMemoria } from '../src/modules/auth/auth.memory.repository.js';
import { AuthService } from '../src/modules/auth/auth.service.js';
import { parsearReglas } from '../src/modules/reglas/reglas.parser.js';
import { MemoryReglasRepository } from '../src/modules/reglas/reglas.repositories.js';
import { ReglasService } from '../src/modules/reglas/reglas.service.js';
import { MemoryTicketRepository } from '../src/modules/tickets/tickets.memory.repository.js';
import { TicketService } from '../src/modules/tickets/tickets.service.js';

const jwtSecret = 'test-secret-with-more-than-thirty-two-characters';
const env = { jwtSecret, jwtExpiresIn: '1h', corsOrigin: '*' };
const servers = [];
after(() => Promise.all(servers.map((server) => new Promise((resolve) => server.close(resolve)))));

const ARCHIVO_OK = `# Reglas de Servicios Generales
id | categoria | prioridad | descripcion
ELE-01 | Eléctrica | alta | Enchufe o tablero con chispas, humo u olor a quemado
ELE-02 | electrica | Media | Luminaria apagada en un sector

BAN-01 | Baños | alta | Fuga de agua que no se puede cortar | ni con la llave de paso
AIR-01 | Aire acondicionado | media | Equipo no enfría en una sala
`;

test('parser: acepta comentarios, encabezado, tildes y "|" dentro de la descripción', () => {
  const r = parsearReglas(`﻿${ARCHIVO_OK}`);
  assert.equal(r.ok, true);
  assert.deepEqual(r.reglas.map((x) => [x.id, x.categoria, x.prioridad]), [
    ['ELE-01', 'ELECTRICA', 'ALTA'],
    ['ELE-02', 'ELECTRICA', 'MEDIA'],
    ['BAN-01', 'BANOS', 'ALTA'],
    ['AIR-01', 'AIRE_ACONDICIONADO', 'MEDIA'],
  ]);
  assert.equal(r.reglas[2].descripcion, 'Fuga de agua que no se puede cortar | ni con la llave de paso');
});

test('parser: devuelve todos los errores con su número de línea', () => {
  const r = parsearReglas([
    'ELE-01 | Electrica | alta | Chispas', // 1 ok
    'ELE-01 | Electrica | media | Repetido', // 2 id repetido
    'ELE-03 | Jardineria | alta | Pasto largo', // 3 categoría
    'ELE-04 | Electrica | baja | Ampolleta', // 4 baja no permitida
    'ELE-05 | Electrica | urgente | Algo', // 5 prioridad inválida
    'ELE-06 | Electrica | alta', // 6 faltan campos
    ' | Electrica | alta | Sin id', // 7 id obligatorio
    'ELE 08 | Electrica | alta | Id con espacio', // 8 id inválido
    'ELE-09 | Electrica | alta | ', // 9 descripción vacía
  ].join('\n'));
  assert.equal(r.ok, false);
  const porLinea = Object.fromEntries(r.errores.map((e) => [e.linea, e.campo]));
  assert.deepEqual(porLinea, { 2: 'id', 3: 'categoria', 4: 'prioridad', 5: 'prioridad', 6: null, 7: 'id', 8: 'id', 9: 'descripcion' });
  assert.match(r.errores.find((e) => e.linea === 2).mensaje, /línea 1/);
  assert.match(r.errores.find((e) => e.linea === 4).mensaje, /guía de autoayuda/);
});

test('parser: un archivo sin reglas es un error', () => {
  const r = parsearReglas('# solo comentarios\n\n');
  assert.deepEqual([r.ok, r.errores[0].linea], [false, null]);
});

async function iniciar() {
  const users = await crearRepositorioEnMemoria([
    { id: 'w-1', name: 'Ana', email: 'ana@gamaitaly.cl', password: 'Temporal2026!', role: 'COLABORADOR', termsAccepted: true },
    { id: 'a-1', name: 'Admin', email: 'admin@gamaitaly.cl', password: 'Temporal2026!', role: 'ADMINISTRADOR', termsAccepted: true },
  ]);
  const authService = new AuthService(users, env, { log: () => {} });
  const ticketRepository = new MemoryTicketRepository([
    { id: '5', ownerId: 'w-1', code: 'REP-0005', category: 'Eléctrica', title: 'Luz', status: 'EN_REVISION', priority: 'BAJA', initialPriority: 'BAJA', priorityOrigin: 'guia', location: 'P1', createdAt: new Date() },
    { id: '6', ownerId: 'w-1', code: 'REP-0006', category: 'Baños', title: 'Jabón', status: 'CERRADO', priority: 'BAJA', location: 'P1', createdAt: new Date() },
  ]);
  const ticketService = new TicketService(ticketRepository, { auditLogger: { info() {} } });
  const reglasService = new ReglasService(new MemoryReglasRepository());
  const app = crearApp({ env, authService, ticketService, reglasService });
  const server = app.listen(0);
  servers.push(server);
  await new Promise((resolve) => server.once('listening', resolve));
  const as = (sub, role) => ({ authorization: `Bearer ${jwt.sign({ role }, jwtSecret, { subject: sub })}` });
  return {
    base: `http://127.0.0.1:${server.address().port}`,
    admin: as('a-1', 'ADMINISTRADOR'),
    colaborador: as('w-1', 'COLABORADOR'),
    ticketRepository,
    reglasService,
  };
}

function formulario(texto, nombre = 'reglas.txt') {
  const form = new FormData();
  form.append('archivo', new Blob([texto], { type: 'text/plain' }), nombre);
  return form;
}

test('POST /api/reglas/archivo + activar + GET /api/reglas (solo administradores)', async () => {
  const { base, admin, colaborador, reglasService } = await iniciar();

  // Solo administradores.
  assert.equal((await fetch(`${base}/api/reglas`)).status, 401);
  assert.equal((await fetch(`${base}/api/reglas`, { headers: colaborador })).status, 403);
  const subidaColaborador = await fetch(`${base}/api/reglas/archivo`, { method: 'POST', headers: colaborador, body: formulario(ARCHIVO_OK) });
  assert.equal(subidaColaborador.status, 403);

  // Errores con número de línea; nada se guarda.
  const mala = await fetch(`${base}/api/reglas/archivo`, { method: 'POST', headers: admin, body: formulario('X-1 | Electrica | baja | Ampolleta') });
  assert.equal(mala.status, 400);
  const cuerpoMala = await mala.json();
  assert.equal(cuerpoMala.error.code, 'ERRORES_VALIDACION');
  assert.equal(cuerpoMala.error.details[0].linea, 1);

  // Extensión y contenido binario.
  const pdf = await fetch(`${base}/api/reglas/archivo`, { method: 'POST', headers: admin, body: formulario(ARCHIVO_OK, 'reglas.pdf') });
  assert.equal((await pdf.json()).error.code, 'FORMATO_INVALIDO');
  const binario = new FormData();
  binario.append('archivo', new Blob([new Uint8Array([0xff, 0xfe, 0x00, 0x01])]), 'reglas.txt');
  assert.equal((await (await fetch(`${base}/api/reglas/archivo`, { method: 'POST', headers: admin, body: binario })).json()).error.code, 'FORMATO_INVALIDO');

  // Subida válida: queda inactiva hasta activarla.
  const ok = await fetch(`${base}/api/reglas/archivo`, { method: 'POST', headers: admin, body: formulario(ARCHIVO_OK) });
  assert.equal(ok.status, 201);
  const subida = (await ok.json()).data;
  assert.deepEqual([subida.version, subida.activa, subida.totalReglas], [1, false, 4]);
  assert.equal((await (await fetch(`${base}/api/reglas`, { headers: admin })).json()).data.total, 0);
  assert.deepEqual(await reglasService.vigentes(), { version: null, reglas: [] });

  const activar = await fetch(`${base}/api/reglas/v1/activar`, { method: 'POST', headers: admin });
  assert.equal((await activar.json()).data.activa, true);
  assert.equal((await fetch(`${base}/api/reglas/99/activar`, { method: 'POST', headers: admin })).status, 404);

  const vigentes = (await (await fetch(`${base}/api/reglas`, { headers: admin })).json()).data;
  assert.deepEqual([vigentes.version.version, vigentes.total, vigentes.reglas[0].id], [1, 4, 'ELE-01']);

  // Una versión nueva reemplaza a la anterior al activarla.
  await fetch(`${base}/api/reglas/archivo`, { method: 'POST', headers: admin, body: formulario('NEW-1 | Electrica | alta | Solo esta') });
  await fetch(`${base}/api/reglas/2/activar`, { method: 'POST', headers: admin });
  const nuevas = await reglasService.vigentes();
  assert.deepEqual([nuevas.version, nuevas.reglas.map((r) => r.id)], [2, ['NEW-1']]);
});

test('PATCH /api/admin/tickets/:id/prioridad registra quién y cuándo', async () => {
  const { base, admin, colaborador, ticketRepository } = await iniciar();
  const patch = (id, body, headers = admin) => fetch(`${base}/api/admin/tickets/${id}/prioridad`, {
    method: 'PATCH',
    headers: { ...headers, 'content-type': 'application/json' },
    body: JSON.stringify(body),
  });

  assert.equal((await patch('5', { prioridad: 'alta' }, colaborador)).status, 403);
  assert.equal((await patch('5', { prioridad: 'urgente' })).status, 400);
  assert.equal((await patch('999', { prioridad: 'alta' })).status, 404);
  assert.equal((await patch('6', { prioridad: 'alta' })).status, 409, 'ticket cerrado');

  // El admin escala una baja que vino de una guía.
  const respuesta = await patch('5', { prioridad: 'alta' });
  assert.equal(respuesta.status, 200);
  const { ticket } = (await respuesta.json()).data;
  assert.deepEqual(
    [ticket.priority, ticket.initialPriority, ticket.priorityOrigin, ticket.changed],
    ['ALTA', 'BAJA', 'guia', true],
  );
  assert.equal(ticketRepository.cambiosPrioridad.length, 1);
  const [cambio] = ticketRepository.cambiosPrioridad;
  assert.deepEqual([cambio.ticketId, cambio.adminId, cambio.anterior, cambio.nueva], ['5', 'a-1', 'BAJA', 'ALTA']);
  assert.ok(cambio.fecha instanceof Date);

  // Misma prioridad: no se registra otro cambio.
  assert.equal((await (await patch('5', { prioridad: 'ALTA' })).json()).data.ticket.changed, false);
  assert.equal(ticketRepository.cambiosPrioridad.length, 1);

  // La prioridad viaja en la respuesta de los tickets del colaborador.
  const mios = (await (await fetch(`${base}/api/tickets/mis-tickets`, { headers: colaborador })).json()).data;
  assert.equal(mios.tickets.find((t) => t.id === '5').priority, 'ALTA');
});

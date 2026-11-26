// ¿PARA QUÉ SIRVE?
//   Prueba el tiempo límite de 3 minutos para crear un ticket.
//
// ¿QUÉ HACE?
//   Revisa que el permiso dure 3 minutos, que un permiso vencido NO guarde el
//   ticket (410 TIEMPO_CREACION_EXPIRADO), que no sirva el de otra persona ni
//   falte, y que no abra las rutas normales como si fuera una sesión.
//
// ¿CÓMO LO CAMBIO?
//   Si cambias DURACION_CREACION_SEGUNDOS, ajusta esta prueba y corre `pnpm test`.

import assert from 'node:assert/strict';
import { after, test } from 'node:test';
import jwt from 'jsonwebtoken';
import { crearApp } from '../src/app.js';
import { crearRepositorioEnMemoria } from '../src/modules/auth/auth.memory.repository.js';
import { AuthService } from '../src/modules/auth/auth.service.js';
import { MemoryTicketRepository } from '../src/modules/tickets/tickets.memory.repository.js';
import { DURACION_CREACION_SEGUNDOS, crearSesionCreacion } from '../src/modules/tickets/tickets.sesionCreacion.js';
import { TicketService } from '../src/modules/tickets/tickets.service.js';

const jwtSecret = 'test-secret-with-more-than-thirty-two-characters';
const env = { jwtSecret, jwtExpiresIn: '1h', corsOrigin: '*' };
const servers = [];

after(async () => {
  await Promise.all(servers.map((server) => new Promise((resolve) => server.close(resolve))));
});

async function preparar() {
  const users = await crearRepositorioEnMemoria([
    { id: 'w-1', name: 'Ana', email: 'ana@gamaitaly.cl', password: 'Temporal2026!', role: 'COLABORADOR', termsAccepted: true },
    { id: 'w-2', name: 'Beto', email: 'beto@gamaitaly.cl', password: 'Temporal2026!', role: 'COLABORADOR', termsAccepted: true },
    { id: 'a-1', name: 'Admin', email: 'admin@gamaitaly.cl', password: 'Temporal2026!', role: 'ADMINISTRADOR', termsAccepted: true },
  ]);
  const tickets = new MemoryTicketRepository([]);
  const app = crearApp({
    env,
    authService: new AuthService(users, env, { log: () => {} }),
    ticketService: new TicketService(tickets, { auditLogger: { info: () => {} } }),
  });
  const server = app.listen(0);
  servers.push(server);
  await new Promise((resolve) => server.once('listening', resolve));
  return { baseUrl: `http://127.0.0.1:${server.address().port}`, tickets };
}

const sesion = (sub, role = 'COLABORADOR') => `Bearer ${jwt.sign({ role }, jwtSecret, { subject: sub })}`;

function reportar(baseUrl, { sub = 'w-1', permiso } = {}) {
  const form = new FormData();
  form.append('categoria', 'ELECTRICA');
  form.append('ubicacion', 'Piso 2, Sala B');
  form.append('descripcion', 'El enchufe echa chispas al conectar');
  const headers = { authorization: sesion(sub) };
  if (permiso) headers['x-sesion-creacion'] = permiso;
  return fetch(`${baseUrl}/api/tickets`, { method: 'POST', headers, body: form });
}

// Un permiso que venció hace un momento (firmado "hace 3 min y 1 s").
function permisoVencido(sub) {
  const iat = Math.floor(Date.now() / 1000) - DURACION_CREACION_SEGUNDOS - 1;
  return jwt.sign({ typ: 'creacion_ticket', iat }, jwtSecret, { subject: sub, expiresIn: DURACION_CREACION_SEGUNDOS });
}

const error = async (respuesta) => (await respuesta.json()).error.code;

test('POST /tickets/sesion-creacion entrega un permiso de 3 minutos (solo colaborador)', async () => {
  const { baseUrl } = await preparar();
  const pedir = (sub, role) => fetch(`${baseUrl}/api/tickets/sesion-creacion`, { method: 'POST', headers: { authorization: sesion(sub, role) } });

  assert.equal((await pedir('a-1', 'ADMINISTRADOR')).status, 403);

  const respuesta = await pedir('w-1');
  assert.equal(respuesta.status, 201);
  const { token, duracionSegundos, expiraEn } = (await respuesta.json()).data;
  assert.equal(duracionSegundos, 180);
  const segundosRestantes = (new Date(expiraEn).getTime() - Date.now()) / 1000;
  assert.ok(segundosRestantes > 175 && segundosRestantes <= 180, `quedan ${segundosRestantes} s`);
  assert.equal(jwt.decode(token).sub, 'w-1');
});

test('con el permiso vigente se crea el ticket', async () => {
  const { baseUrl, tickets } = await preparar();
  const respuesta = await reportar(baseUrl, { permiso: crearSesionCreacion(jwtSecret, 'w-1').token });
  assert.equal(respuesta.status, 201);
  assert.equal(tickets.tickets.length, 1);
});

test('vencidos los 3 minutos el ticket NO se guarda (410 TIEMPO_CREACION_EXPIRADO)', async () => {
  const { baseUrl, tickets } = await preparar();
  const respuesta = await reportar(baseUrl, { permiso: permisoVencido('w-1') });
  assert.equal(respuesta.status, 410);
  assert.equal(await error(respuesta), 'TIEMPO_CREACION_EXPIRADO');
  assert.equal(tickets.tickets.length, 0);
});

test('sin permiso, con uno ajeno o falsificado, no se crea el ticket', async () => {
  const { baseUrl, tickets } = await preparar();

  const sinPermiso = await reportar(baseUrl);
  assert.equal(sinPermiso.status, 400);
  assert.equal(await error(sinPermiso), 'SESION_CREACION_REQUERIDA');

  const ajeno = await reportar(baseUrl, { permiso: crearSesionCreacion(jwtSecret, 'w-2').token });
  assert.equal(await error(ajeno), 'SESION_CREACION_INVALIDA');

  const falso = await reportar(baseUrl, { permiso: crearSesionCreacion('otro-secreto-de-mas-de-32-caracteres!!', 'w-1').token });
  assert.equal(await error(falso), 'SESION_CREACION_INVALIDA');

  // Una sesión normal no sirve como permiso de creación.
  const sesionComoPermiso = await reportar(baseUrl, { permiso: sesion('w-1').slice('Bearer '.length) });
  assert.equal(await error(sesionComoPermiso), 'SESION_CREACION_INVALIDA');

  assert.equal(tickets.tickets.length, 0);
});

test('el permiso de creación no abre las rutas normales como si fuera una sesión', async () => {
  const { baseUrl } = await preparar();
  const { token } = crearSesionCreacion(jwtSecret, 'w-1');
  const respuesta = await fetch(`${baseUrl}/api/tickets/mios`, { headers: { authorization: `Bearer ${token}` } });
  assert.equal(respuesta.status, 401);
});

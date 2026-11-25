// ¿PARA QUÉ SIRVE?
//   Prueba las notificaciones push (T11) de punta a punta, con el envío simulado.
//
// ¿QUÉ HACE?
//   Registra el celular del colaborador, hace que el administrador cambie el
//   estado y comente, y revisa que: llegue el push al celular correcto con el
//   número del ticket (y el del comentario), quede en el historial, se pueda
//   marcar como leído, y nadie vea o marque avisos ajenos.
//
// ¿CÓMO LO CAMBIO?
//   Si cambian los textos o las reglas de estados, ajusta esta prueba y corre
//   `pnpm test`.

import assert from 'node:assert/strict';
import { after, test } from 'node:test';
import jwt from 'jsonwebtoken';
import { crearApp } from '../src/app.js';
import { crearRepositorioEnMemoria } from '../src/modules/auth/auth.memory.repository.js';
import { AuthService } from '../src/modules/auth/auth.service.js';
import { EnviadorSimulado, mensajeFcm } from '../src/modules/notificaciones/notificaciones.enviador.js';
import { MemoryNotificacionesRepository } from '../src/modules/notificaciones/notificaciones.repositories.js';
import { NotificacionesService } from '../src/modules/notificaciones/notificaciones.service.js';
import { MemoryTicketRepository } from '../src/modules/tickets/tickets.memory.repository.js';
import { TicketService } from '../src/modules/tickets/tickets.service.js';

const jwtSecret = 'test-secret-with-more-than-thirty-two-characters';
const env = { jwtSecret, jwtExpiresIn: '1h', corsOrigin: '*' };
const servers = [];
const TOKEN_ANA = 'fcm-token-de-ana:APA91b_celular_de_prueba_123';

after(() => Promise.all(servers.map((server) => new Promise((resolve) => server.close(resolve)))));

async function preparar() {
  const users = await crearRepositorioEnMemoria([
    { id: 'w-1', name: 'Ana', email: 'ana@gamaitaly.cl', password: 'Temporal2026!', role: 'COLABORADOR', termsAccepted: true },
    { id: 'w-2', name: 'Beto', email: 'beto@gmail.com', password: 'Temporal2026!', role: 'COLABORADOR', termsAccepted: true },
    { id: 'a-1', name: 'Admin', email: 'admin@gamaitaly.cl', password: 'Temporal2026!', role: 'ADMINISTRADOR', termsAccepted: true },
  ]);
  const enviador = new EnviadorSimulado();
  const notificacionesService = new NotificacionesService(new MemoryNotificacionesRepository(), enviador);
  const ticketService = new TicketService(new MemoryTicketRepository([
    { id: '87', ownerId: 'w-1', code: 'REP-0087', category: 'Eléctrica', title: 'Enchufe', status: 'RECIBIDO', priority: 'MEDIA', location: 'Piso 2', createdAt: new Date() },
  ]), { auditLogger: { info: () => {} }, notificaciones: notificacionesService });
  const authService = new AuthService(users, env, { log: () => {} });
  const app = crearApp({ env, authService, ticketService, notificacionesService });
  const server = app.listen(0);
  servers.push(server);
  await new Promise((resolve) => server.once('listening', resolve));
  const base = `http://127.0.0.1:${server.address().port}/api`;

  const llamar = (metodo, ruta, sub, body, role = 'COLABORADOR') => fetch(base + ruta, {
    method: metodo,
    headers: {
      'content-type': 'application/json',
      ...(sub && { authorization: `Bearer ${jwt.sign({ role }, jwtSecret, { subject: sub })}` }),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const admin = (metodo, ruta, body) => llamar(metodo, ruta, 'a-1', body, 'ADMINISTRADOR');
  return { llamar, admin, enviador };
}

test('T11: registrar el celular solo acepta tokens válidos y con sesión', async () => {
  const { llamar } = await preparar();
  assert.equal((await llamar('POST', '/notificaciones/dispositivos', null, { token: TOKEN_ANA, plataforma: 'android' })).status, 401);
  assert.equal((await llamar('POST', '/notificaciones/dispositivos', 'w-1', { token: 'corto', plataforma: 'android' })).status, 400);
  assert.equal((await llamar('POST', '/notificaciones/dispositivos', 'w-1', { token: '<script>alert(1)</script>xxxxxxxxxxxxx', plataforma: 'ios' })).status, 400);
  assert.equal((await llamar('POST', '/notificaciones/dispositivos', 'w-1', { token: TOKEN_ANA, plataforma: 'windows' })).status, 400);
  assert.equal((await llamar('POST', '/notificaciones/dispositivos', 'w-1', { token: TOKEN_ANA, plataforma: 'android' })).status, 201);
});

test('T11: cambio de estado y comentario llegan al dueño con el número del ticket', async () => {
  const { llamar, admin, enviador } = await preparar();
  await llamar('POST', '/notificaciones/dispositivos', 'w-1', { token: TOKEN_ANA, plataforma: 'android' });

  // El colaborador no puede usar las rutas del administrador.
  assert.equal((await llamar('PATCH', '/admin/tickets/87/estado', 'w-1', { estado: 'EN_REVISION' })).status, 403);

  // Cambio de estado: aviso con el número del ticket.
  assert.equal((await admin('PATCH', '/admin/tickets/87/estado', { estado: 'EN_REVISION' })).status, 200);
  const push1 = enviador.enviadosSimulados.at(-1);
  assert.deepEqual(push1.tokens, [TOKEN_ANA]);
  assert.equal(push1.datos.tipo, 'estado');
  assert.equal(push1.datos.ticketId, '87');
  assert.match(push1.cuerpo, /#REP-0087 cambió a "En revisión"/);

  // Transición no permitida y rechazo sin motivo suficiente.
  assert.equal((await admin('PATCH', '/admin/tickets/87/estado', { estado: 'CERRADO' })).status, 409);
  assert.equal((await admin('PATCH', '/admin/tickets/87/estado', { estado: 'RECHAZADO', motivo: 'corto' })).status, 400);

  // Comentario: "Nuevo comentario en tu ticket", con el id del comentario.
  const res = await admin('POST', '/admin/tickets/87/comentarios', { texto: 'Se constata daño térmico en enchufe mural.' });
  assert.equal(res.status, 201);
  const { comentario } = (await res.json()).data;
  const push2 = enviador.enviadosSimulados.at(-1);
  assert.equal(push2.titulo, 'Nuevo comentario en tu ticket');
  assert.equal(push2.datos.tipo, 'comentario');
  assert.equal(push2.datos.ticketId, '87');
  assert.equal(push2.datos.comentarioId, comentario.id);
  assert.ok(!JSON.stringify(push2.datos).includes('ana@'), 'por el push no viajan datos personales');

  // El comentario aparece en el detalle del ticket del colaborador.
  const detalle = (await (await llamar('GET', '/tickets/87', 'w-1')).json()).data.ticket;
  assert.equal(detalle.comments.at(-1).text, 'Se constata daño térmico en enchufe mural.');
});

test('T11: historial propio, marcar leídas y nada de avisos ajenos', async () => {
  const { llamar, admin } = await preparar();
  await admin('PATCH', '/admin/tickets/87/estado', { estado: 'EN_REVISION' });
  await admin('POST', '/admin/tickets/87/comentarios', { texto: 'Revisamos el enchufe.' });

  const lista = (await (await llamar('GET', '/notificaciones', 'w-1')).json()).data;
  assert.equal(lista.sinLeer, 2);
  assert.deepEqual(lista.notificaciones.map((n) => n.tipo), ['comentario', 'estado']);
  assert.equal(lista.notificaciones[0].codigo, 'REP-0087');
  assert.equal(lista.notificaciones[1].estado, 'EN_REVISION');

  // Otra persona no ve ni puede marcar los avisos de Ana.
  assert.equal((await (await llamar('GET', '/notificaciones', 'w-2')).json()).data.notificaciones.length, 0);
  const idAjeno = lista.notificaciones[0].id;
  await llamar('POST', `/notificaciones/${idAjeno}/leida`, 'w-2');
  assert.equal((await (await llamar('GET', '/notificaciones', 'w-1')).json()).data.sinLeer, 2);

  await llamar('POST', `/notificaciones/${idAjeno}/leida`, 'w-1');
  assert.equal((await (await llamar('GET', '/notificaciones', 'w-1')).json()).data.sinLeer, 1);
  await llamar('POST', '/notificaciones/leidas', 'w-1');
  assert.equal((await (await llamar('GET', '/notificaciones', 'w-1')).json()).data.sinLeer, 0);
});

test('T11: al cerrar sesión el celular deja de recibir; un token pasa al nuevo usuario', async () => {
  const { llamar, admin, enviador } = await preparar();
  await llamar('POST', '/notificaciones/dispositivos', 'w-1', { token: TOKEN_ANA, plataforma: 'android' });
  // Beto inicia sesión en el mismo celular: el token pasa a él.
  await llamar('POST', '/notificaciones/dispositivos', 'w-2', { token: TOKEN_ANA, plataforma: 'android' });
  await admin('PATCH', '/admin/tickets/87/estado', { estado: 'EN_REVISION' });
  assert.deepEqual(enviador.enviadosSimulados.at(-1).tokens, [], 'Ana ya no tiene ese celular');

  // Ana no puede quitar un token que ya no es suyo.
  await llamar('DELETE', '/notificaciones/dispositivos', 'w-1', { token: TOKEN_ANA });
  await llamar('POST', '/notificaciones/dispositivos', 'w-1', { token: TOKEN_ANA, plataforma: 'android' });
  await llamar('DELETE', '/notificaciones/dispositivos', 'w-1', { token: TOKEN_ANA });
  await admin('PATCH', '/admin/tickets/87/estado', { estado: 'APROBADO' });
  assert.deepEqual(enviador.enviadosSimulados.at(-1).tokens, []);
});

test('el push se arma para verse bien con el celular bloqueado (Android e iOS)', () => {
  const m = mensajeFcm({
    titulo: 'Ticket #REP-0087 pasó a "En proceso"',
    cuerpo: 'Tu ticket #REP-0087 cambió a "En proceso".',
    datos: { tipo: 'estado', ticketId: '87', notificacionId: 'n-1' },
  });
  assert.equal(m.notification.title, 'Ticket #REP-0087 pasó a "En proceso"');
  assert.deepEqual(m.data, { tipo: 'estado', ticketId: '87', notificacionId: 'n-1' });
  // Android: ícono propio, visible bloqueado y un aviso por ticket y tipo.
  assert.equal(m.android.notification.channelId, 'tickets');
  assert.equal(m.android.notification.icon, 'ic_stat_tyckops');
  assert.equal(m.android.notification.visibility, 'public');
  assert.equal(m.android.notification.tag, 'ticket-87-estado');
  // iOS: alerta con sonido, agrupada por ticket y que reemplaza la anterior.
  assert.equal(m.apns.payload.aps.sound, 'default');
  assert.equal(m.apns.payload.aps['thread-id'], 'ticket-87');
  assert.equal(m.apns.headers['apns-collapse-id'], 'ticket-87-estado');
  assert.equal(m.apns.headers['apns-push-type'], 'alert');
});

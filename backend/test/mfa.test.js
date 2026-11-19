// ¿PARA QUÉ SIRVE?
//   Prueba la verificación en dos pasos (T8) y el orden del acceso.
//
// ¿QUÉ HACE?
//   Revisa el criterio de la tarjeta: el código correcto deja entrar; uno
//   incorrecto, vencido o ya usado se rechaza con su mensaje; muchos intentos
//   bloquean; y las llaves limitadas (primer acceso o verificación) no abren
//   ninguna ruta interna.
//
// ¿CÓMO LO CAMBIO?
//   Si cambias los tiempos o los intentos del MFA, ajusta esta prueba y corre `pnpm test`.

import assert from 'node:assert/strict';
import { after, test } from 'node:test';
import { crearApp } from '../src/app.js';
import { crearRepositorioEnMemoria } from '../src/modules/auth/auth.memory.repository.js';
import { MfaService } from '../src/modules/auth/auth.mfa.js';

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

async function preparar() {
  let reloj = Date.parse('2026-11-19T12:00:00Z');
  const enviados = [];
  const users = await crearRepositorioEnMemoria([
    { id: 'w-1', name: 'Ana', email: 'ana@gamaitaly.cl', password: 'Temporal2026!', role: 'COLABORADOR', termsAccepted: true, isFirstLogin: false },
    { id: 'w-2', name: 'Beto', email: 'beto@gamaitaly.cl', password: 'Temporal2026!', role: 'COLABORADOR', termsAccepted: false, isFirstLogin: true },
  ]);
  const mfaService = new MfaService({
    jwtSecret,
    codigoFijo: '123456',
    enviarCodigo: async (datos) => enviados.push(datos),
    ahora: () => reloj,
  });
  const baseUrl = await start(crearApp({ env, userRepository: users, mfaService, auditLogger: { log: () => {} } }));
  const post = (ruta, body, token) => fetch(`${baseUrl}/api/auth/${ruta}`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', ...(token && { authorization: `Bearer ${token}` }) },
    body: JSON.stringify(body ?? {}),
  });
  const get = (ruta, token) => fetch(`${baseUrl}${ruta}`, { headers: { authorization: `Bearer ${token}` } });
  const login = async (email) => (await (await post('login', { email, password: 'Temporal2026!' })).json()).data;
  return { post, get, login, enviados, avanzar: (ms) => { reloj += ms; } };
}

const codigo = async (respuesta) => (await respuesta.json()).error?.code;

test('MFA: el login no entrega la sesión hasta verificar el código (T8)', async () => {
  const { post, get, login, enviados } = await preparar();

  const paso = await login('ana@gamaitaly.cl');
  assert.equal(paso.step, 'MFA');
  assert.equal(paso.token, undefined, 'sin código no hay sesión');
  assert.equal(paso.email, 'ana@gamaitaly.cl');
  assert.equal(enviados.length, 1, 'se envió el código al correo');

  // El pase de verificación no abre nada más.
  assert.equal((await get('/api/auth/me', paso.mfaToken)).status, 403);
  assert.equal((await get('/api/tickets/mis-tickets', paso.mfaToken)).status, 403);

  // Código incorrecto: mensaje con intentos restantes.
  const malo = await post('mfa/verificar', { codigo: '000000' }, paso.mfaToken);
  assert.equal(malo.status, 400);
  assert.equal(await codigo(malo), 'MFA_CODIGO_INCORRECTO');

  // Código correcto: ahora sí, sesión completa.
  const ok = await post('mfa/verificar', { codigo: '123456' }, paso.mfaToken);
  assert.equal(ok.status, 200);
  const { token, user } = (await ok.json()).data;
  assert.equal(user.email, 'ana@gamaitaly.cl');
  assert.equal((await get('/api/auth/sesion', token)).status, 200);

  // Ya usado: el mismo código no sirve dos veces.
  const repetido = await post('mfa/verificar', { codigo: '123456' }, paso.mfaToken);
  assert.equal(await codigo(repetido), 'MFA_SESION_INVALIDA');
});

test('MFA: código vencido, reenvío con espera y bloqueo por intentos', async () => {
  const { post, login, avanzar, enviados } = await preparar();

  const paso = await login('ana@gamaitaly.cl');
  // Reenviar antes de tiempo no se permite.
  assert.equal(await codigo(await post('mfa/reenviar', {}, paso.mfaToken)), 'MFA_ESPERA_REENVIO');

  // Pasan 3 minutos: el código vence.
  avanzar(3 * 60 * 1000 + 1);
  assert.equal(await codigo(await post('mfa/verificar', { codigo: '123456' }, paso.mfaToken)), 'MFA_CODIGO_VENCIDO');

  // Se pide otro y funciona.
  assert.equal((await post('mfa/reenviar', {}, paso.mfaToken)).status, 200);
  assert.equal(enviados.length, 2);
  assert.equal((await post('mfa/verificar', { codigo: '123456' }, paso.mfaToken)).status, 200);

  // Muchos intentos fallidos bloquean la verificación.
  const otro = await login('ana@gamaitaly.cl');
  let ultimo;
  for (let i = 0; i < 5; i++) ultimo = await post('mfa/verificar', { codigo: '999999' }, otro.mfaToken);
  assert.equal(ultimo.status, 429);
  assert.equal(await codigo(ultimo), 'MFA_DEMASIADOS_INTENTOS');
  assert.equal(await codigo(await post('mfa/verificar', { codigo: '123456' }, otro.mfaToken)), 'MFA_SESION_INVALIDA');
});

test('Primer ingreso: primero el primer acceso con llave limitada, después el código', async () => {
  const { post, get, login } = await preparar();

  const paso = await login('beto@gamaitaly.cl');
  assert.equal(paso.step, 'PRIMER_ACCESO');
  // La llave limitada sirve para "¿quién soy?" y el primer acceso, pero no para la app.
  assert.equal((await get('/api/auth/me', paso.token)).status, 200);
  assert.equal((await get('/api/tickets/mis-tickets', paso.token)).status, 403);

  const hecho = await post('primer-acceso', { acceptTerms: true, termsVersion: 'GA-TOS-2026' }, paso.token);
  assert.equal(hecho.status, 200);

  // Vuelve a iniciar sesión: ahora le toca la verificación en dos pasos.
  const segundo = await login('beto@gamaitaly.cl');
  assert.equal(segundo.step, 'MFA');
});

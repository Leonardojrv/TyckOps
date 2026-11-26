// ¿PARA QUÉ SIRVE?
//   Prueba el ingreso del administrador (T12): login, código MFA, cambio de
//   contraseña en el primer ingreso y llegada al Home.
//
// ¿QUÉ HACE?
//   Revisa que el administrador SIEMPRE pase primero por el código, que en su
//   primer ingreso reciba una llave limitada que solo sirve para el cambio de
//   contraseña (sin Términos), que esa llave no se pueda conseguir sin el código,
//   y que al terminar quede con la sesión completa. El colaborador no cambia.
//
// ¿CÓMO LO CAMBIO?
//   Si cambia el orden del ingreso del administrador, ajusta esta prueba y corre
//   `pnpm test`.

import assert from 'node:assert/strict';
import { after, test } from 'node:test';
import jwt from 'jsonwebtoken';
import { crearApp } from '../src/app.js';
import { crearRepositorioEnMemoria } from '../src/modules/auth/auth.memory.repository.js';
import { MfaService } from '../src/modules/auth/auth.mfa.js';

const jwtSecret = 'test-secret-with-more-than-thirty-two-characters';
const env = { jwtSecret, jwtExpiresIn: '1h', corsOrigin: '*' };
const servers = [];
const CLAVE = 'Temporal2026!';

after(() => Promise.all(servers.map((server) => new Promise((resolve) => server.close(resolve)))));

async function preparar() {
  const users = await crearRepositorioEnMemoria([
    { id: 'a-1', name: 'Felipe', email: 'felipe.morales@gamaitaly.cl', password: CLAVE, role: 'ADMINISTRADOR', termsAccepted: false, isFirstLogin: true },
    { id: 'a-2', name: 'Admin', email: 'admin@gamaitaly.cl', password: CLAVE, role: 'ADMINISTRADOR', termsAccepted: false, isFirstLogin: false },
    { id: 'w-1', name: 'Beto', email: 'beto@gamaitaly.cl', password: CLAVE, role: 'COLABORADOR', termsAccepted: false, isFirstLogin: true },
  ]);
  const mfaService = new MfaService({ jwtSecret, codigoFijo: '123456', enviarCodigo: async () => {} });
  const app = crearApp({ env, userRepository: users, mfaService, auditLogger: { log: () => {} } });
  const server = app.listen(0);
  servers.push(server);
  await new Promise((resolve) => server.once('listening', resolve));
  const base = `http://127.0.0.1:${server.address().port}/api/auth`;
  const post = async (ruta, body, token) => {
    const r = await fetch(`${base}/${ruta}`, {
      method: 'POST',
      headers: { 'content-type': 'application/json', ...(token && { authorization: `Bearer ${token}` }) },
      body: JSON.stringify(body ?? {}),
    });
    return { status: r.status, body: await r.json() };
  };
  const get = async (ruta, token) => {
    const r = await fetch(`${base}/${ruta}`, { headers: { authorization: `Bearer ${token}` } });
    return { status: r.status, body: await r.json() };
  };
  const entrar = async (email, password = CLAVE) => {
    const paso = (await post('login', { email, password })).body.data;
    return { paso, verificado: paso.step === 'MFA' ? await post('mfa/verificar', { codigo: '123456' }, paso.mfaToken) : null };
  };
  return { post, get, entrar };
}

test('T12: administrador nuevo → código → cambio de contraseña → Home', async () => {
  const { post, get, entrar } = await preparar();

  // 1) Login: primero el código (nunca el cambio de contraseña antes del MFA).
  const { paso, verificado } = await entrar('felipe.morales@gamaitaly.cl');
  assert.equal(paso.step, 'MFA');
  assert.equal(paso.role, 'ADMINISTRADOR');
  assert.equal(paso.token, undefined, 'sin código no hay ninguna llave');

  // 2) Código correcto en el primer ingreso: llave LIMITADA para cambiar la contraseña.
  assert.equal(verificado.status, 200);
  assert.equal(verificado.body.data.step, 'PRIMER_ACCESO');
  const llave = verificado.body.data.token;
  assert.equal(jwt.decode(llave).typ, 'primer_acceso');
  assert.equal((await get('sesion', llave)).status, 403, 'la llave limitada no abre la app');

  // 3) Cambia la contraseña (sin términos) y recibe la sesión completa.
  assert.equal((await post('primer-acceso/administrador', { newPassword: 'NuevaClave2026' }, llave)).status, 400, 'falta la actual');
  assert.equal((await post('primer-acceso/administrador', { currentPassword: 'mala', newPassword: 'NuevaClave2026' }, llave)).body.error.code, 'CONTRASENA_ACTUAL_INCORRECTA');
  const listo = await post('primer-acceso/administrador', { currentPassword: CLAVE, newPassword: 'NuevaClave2026' }, llave);
  assert.equal(listo.status, 200);
  assert.equal(listo.body.data.user.isFirstLogin, false);
  const sesion = listo.body.data.token;
  assert.equal(jwt.decode(sesion).typ, 'acceso');

  // 4) Home del administrador: ya puede entrar (sin haber aceptado Términos).
  assert.equal((await get('sesion', sesion)).status, 200);
  assert.equal((await post('primer-acceso/administrador', {}, llave)).body.error.code, 'PRIMER_ACCESO_COMPLETADO', 'una sola vez');

  // La próxima vez: login → código → directo al Home, con la contraseña nueva.
  const otraVez = await entrar('felipe.morales@gamaitaly.cl', 'NuevaClave2026');
  assert.equal(otraVez.paso.step, 'MFA');
  assert.equal(jwt.decode(otraVez.verificado.body.data.token).typ, 'acceso');
});

test('T12: "Mantener la actual" también termina el primer ingreso', async () => {
  const { post, get, entrar } = await preparar();
  const { verificado } = await entrar('felipe.morales@gamaitaly.cl');
  const listo = await post('primer-acceso/administrador', {}, verificado.body.data.token);
  assert.equal(listo.status, 200);
  assert.equal((await get('sesion', listo.body.data.token)).status, 200);
});

test('T12: la llave del cambio de contraseña no se consigue sin el código', async () => {
  const { post } = await preparar();
  // Una llave "primer_acceso" firmada sin la marca mfa (como la del colaborador) no sirve.
  const sinMfa = jwt.sign({ role: 'ADMINISTRADOR', typ: 'primer_acceso' }, jwtSecret, { subject: 'a-1', expiresIn: '15m' });
  assert.equal((await post('primer-acceso/administrador', {}, sinMfa)).body.error.code, 'MFA_REQUERIDO');
  // Un colaborador no puede usar la ruta del administrador.
  const colab = jwt.sign({ role: 'COLABORADOR', typ: 'primer_acceso', mfa: true }, jwtSecret, { subject: 'w-1', expiresIn: '15m' });
  assert.equal((await post('primer-acceso/administrador', {}, colab)).body.error.code, 'SOLO_ADMINISTRADOR');
  // No acepta campos extra (por ejemplo, términos o un rol).
  const conMfa = jwt.sign({ role: 'ADMINISTRADOR', typ: 'primer_acceso', mfa: true }, jwtSecret, { subject: 'a-1', expiresIn: '15m' });
  assert.equal((await post('primer-acceso/administrador', { role: 'COLABORADOR' }, conMfa)).status, 400);
});

test('T12: el colaborador sigue con su orden (primer acceso antes del código)', async () => {
  const { entrar } = await preparar();
  const { paso } = await entrar('beto@gamaitaly.cl');
  assert.equal(paso.step, 'PRIMER_ACCESO');
});

test('T12: un administrador ya configurado va del código directo al Home', async () => {
  const { entrar, get } = await preparar();
  const { verificado } = await entrar('admin@gamaitaly.cl');
  assert.equal(verificado.body.data.step, undefined);
  assert.equal((await get('sesion', verificado.body.data.token)).status, 200);
});

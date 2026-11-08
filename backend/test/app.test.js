import assert from 'node:assert/strict';
import { after, test } from 'node:test';
import jwt from 'jsonwebtoken';
import { crearApp } from '../src/app.js';
import { AuthService } from '../src/modules/auth/auth.service.js';
import { crearRepositorioEnMemoria } from '../src/modules/auth/auth.memory.repository.js';

const jwtSecret = 'test-secret-with-more-than-thirty-two-characters';
const env = { jwtSecret, jwtExpiresIn: '1h', corsOrigin: '*' };
const servers = [];

async function start(app) {
  const server = app.listen(0, '127.0.0.1');
  servers.push(server);
  await new Promise((resolve) => server.once('listening', resolve));
  return `http://127.0.0.1:${server.address().port}`;
}

after(async () => {
  await Promise.all(servers.map((server) => new Promise((resolve) => server.close(resolve))));
});

test('GET /salud funciona sin base de datos', async () => {
  const baseUrl = await start(crearApp({ env, databaseStatus: 'not_configured' }));
  const response = await fetch(`${baseUrl}/salud`);

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), {
    success: true,
    data: { status: 'ok', database: 'not_configured' },
  });
});

test('login valida datos y funciona para colaborador y administrador en memoria', async () => {
  const auditEvents = [];
  const repository = await crearRepositorioEnMemoria([
    {
      id: 'worker-1',
      name: 'Camila Henríquez',
      email: 'camila@gamaitaly.cl',
      password: 'WorkerPassword2026!',
      role: 'COLABORADOR',
      termsAccepted: true,
    },
    {
      id: 'admin-1',
      name: 'Felipe Morales',
      email: 'admin@gamaitaly.cl',
      password: 'AdminPassword2026!',
      role: 'ADMINISTRADOR',
    },
  ]);
  const authService = new AuthService(repository, env, { log: (event) => auditEvents.push(event) });
  const baseUrl = await start(crearApp({ env, authService }));
  const badResponse = await fetch(`${baseUrl}/api/auth/login`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ email: 'user@example.com', password: 'pass' }),
  });
  assert.equal(badResponse.status, 400);
  assert.equal((await badResponse.json()).error.code, 'DATOS_INVALIDOS');

  const missingDataResponse = await fetch(`${baseUrl}/api/auth/login`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ email: 'camila@gamaitaly.cl' }),
  });
  assert.equal(missingDataResponse.status, 400);
  assert.equal((await missingDataResponse.json()).error.code, 'DATOS_INVALIDOS');

  const response = await fetch(`${baseUrl}/api/auth/login`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ email: 'CAMIla@gamaitaly.cl', password: 'WorkerPassword2026!' }),
  });
  const body = await response.json();

  assert.equal(response.status, 200);
  assert.equal(body.success, true);
  assert.equal(body.data.user.email, 'camila@gamaitaly.cl');
  assert.equal(body.data.user.role, 'COLABORADOR');
  assert.equal(body.data.user.name, 'Camila Henríquez');
  assert.equal(jwt.verify(body.data.token, jwtSecret).sub, 'worker-1');
  assert.ok(jwt.verify(body.data.token, jwtSecret).exp);

  const meResponse = await fetch(`${baseUrl}/api/auth/me`, {
    headers: { authorization: `Bearer ${body.data.token}` },
  });
  const meBody = await meResponse.json();
  assert.equal(meResponse.status, 200);
  assert.deepEqual(meBody.data.user, body.data.user);

  const expiredToken = jwt.sign({ role: 'COLABORADOR' }, jwtSecret, {
    subject: 'worker-1',
    expiresIn: -1,
  });
  const expiredMeResponse = await fetch(`${baseUrl}/api/auth/me`, {
    headers: { authorization: `Bearer ${expiredToken}` },
  });
  assert.equal(expiredMeResponse.status, 401);

  const adminResponse = await fetch(`${baseUrl}/api/auth/login`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ email: 'admin@gamaitaly.cl', password: 'AdminPassword2026!' }),
  });
  const adminBody = await adminResponse.json();
  assert.equal(adminResponse.status, 200);
  assert.equal(adminBody.data.user.role, 'ADMINISTRADOR');
  assert.equal(jwt.verify(adminBody.data.token, jwtSecret).sub, 'admin-1');

  const wrongPasswordResponse = await fetch(`${baseUrl}/api/auth/login`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ email: 'admin@gamaitaly.cl', password: 'wrong-password' }),
  });
  assert.equal(wrongPasswordResponse.status, 401);
  assert.equal((await wrongPasswordResponse.json()).error.code, 'CREDENCIALES_INVALIDAS');
  assert.deepEqual(auditEvents.map((event) => event.action), [
    'login_succeeded',
    'login_succeeded',
    'login_failed',
  ]);
  assert.ok(auditEvents.every((event) => !('password' in event)));
});

test('GET /api/admin/ejemplo requiere token válido y rol administrador', async () => {
  const baseUrl = await start(crearApp({ env }));

  const missingToken = await fetch(`${baseUrl}/api/admin/ejemplo`);
  assert.equal(missingToken.status, 401);

  const expiredToken = jwt.sign({ role: 'ADMINISTRADOR' }, jwtSecret, {
    subject: 'admin-expired',
    expiresIn: -1,
  });
  const expired = await fetch(`${baseUrl}/api/admin/ejemplo`, {
    headers: { authorization: `Bearer ${expiredToken}` },
  });
  assert.equal(expired.status, 401);

  const workerToken = jwt.sign({ role: 'COLABORADOR' }, jwtSecret, { subject: 'worker-1' });
  const forbidden = await fetch(`${baseUrl}/api/admin/ejemplo`, {
    headers: { authorization: `Bearer ${workerToken}` },
  });
  assert.equal(forbidden.status, 403);
  assert.equal((await forbidden.json()).error.code, 'SIN_ROL_ADMIN');

  const adminToken = jwt.sign({ role: 'ADMINISTRADOR' }, jwtSecret, { subject: 'admin-1' });
  const allowed = await fetch(`${baseUrl}/api/admin/ejemplo`, {
    headers: { authorization: `Bearer ${adminToken}` },
  });
  assert.equal(allowed.status, 200);
  assert.deepEqual((await allowed.json()).data, {
    message: 'Acceso de administrador autorizado.',
    userId: 'admin-1',
    role: 'ADMINISTRADOR',
  });
});

test('login limita intentos y devuelve DEMASIADOS_INTENTOS', async () => {
  const authService = { login: async () => ({}) };
  const baseUrl = await start(crearApp({ env, authService }));
  let response;

  for (let attempt = 0; attempt < 6; attempt += 1) {
    response = await fetch(`${baseUrl}/api/auth/login`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ email: 'admin@gamaitaly.cl', password: 'a-valid-password' }),
    });
  }

  assert.equal(response.status, 429);
  assert.equal((await response.json()).error.code, 'DEMASIADOS_INTENTOS');
});
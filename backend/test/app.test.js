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
  const repository = await crearRepositorioEnMemoria([
    { id: 'admin-1', name: 'Admin', email: 'admin@gamaitaly.cl', password: 'Temporal2026!', role: 'ADMINISTRADOR', termsAccepted: true },
  ]);
  const authService = new AuthService(repository, env, { log: () => {} });
  const baseUrl = await start(crearApp({ env, authService }));

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

test('primer acceso permite cambiar o mantener la contraseña temporal (RF-02)', async () => {
  const auditEvents = [];
  const repository = await crearRepositorioEnMemoria([
    {
      id: 'worker-1',
      name: 'Camila Henríquez',
      email: 'camila@gamaitaly.cl',
      password: 'Temporal2026!',
      role: 'COLABORADOR',
      isFirstLogin: true,
    },
    {
      id: 'worker-2',
      name: 'Pedro Soto',
      email: 'pedro@gamaitaly.cl',
      password: 'Temporal2026!',
      role: 'COLABORADOR',
      isFirstLogin: true,
    },
  ]);
  const authService = new AuthService(repository, env, { log: (event) => auditEvents.push(event) });
  const baseUrl = await start(crearApp({ env, authService }));
  const TERMS = { acceptTerms: true, termsVersion: 'GA-TOS-2026' };
  const primerAcceso = (userId, body) => fetch(`${baseUrl}/api/auth/primer-acceso`, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      ...(userId && {
        authorization: `Bearer ${jwt.sign({ role: 'COLABORADOR' }, jwtSecret, { subject: userId })}`,
      }),
    },
    body: JSON.stringify(body && body.noTerms ? {} : { ...TERMS, ...body }),
  });
  const login = (email, password) => fetch(`${baseUrl}/api/auth/login`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ email, password }),
  });

  assert.equal((await primerAcceso(null, {})).status, 401);

  const weak = await primerAcceso('worker-1', { currentPassword: 'Temporal2026!', newPassword: 'corta' });
  assert.equal(weak.status, 400);
  assert.equal((await weak.json()).error.code, 'DATOS_INVALIDOS');

  const wrongCurrent = await primerAcceso('worker-1', {
    currentPassword: 'NoEsLaClave1',
    newPassword: 'NuevaClave2026',
  });
  assert.equal(wrongCurrent.status, 400);
  assert.equal((await wrongCurrent.json()).error.code, 'CONTRASENA_ACTUAL_INCORRECTA');

  const changed = await primerAcceso('worker-1', {
    currentPassword: 'Temporal2026!',
    newPassword: 'NuevaClave2026',
  });
  assert.equal(changed.status, 200);
  assert.equal((await changed.json()).data.user.isFirstLogin, false);
  assert.equal((await login('camila@gamaitaly.cl', 'NuevaClave2026')).status, 200);
  assert.equal((await login('camila@gamaitaly.cl', 'Temporal2026!')).status, 401);

  const repeated = await primerAcceso('worker-1', {});
  assert.equal(repeated.status, 409);
  assert.equal((await repeated.json()).error.code, 'PRIMER_ACCESO_COMPLETADO');

  const kept = await primerAcceso('worker-2', {});
  assert.equal(kept.status, 200);
  assert.equal((await kept.json()).data.user.isFirstLogin, false);

  assert.deepEqual(
    auditEvents.filter((event) => event.action.startsWith('password')).map((event) => event.action),
    ['password_change_failed', 'password_changed', 'password_kept'],
  );
  assert.ok(auditEvents.every((event) => !('password' in event) && !('newPassword' in event)));
});

test('sin aceptar los Términos el servidor rechaza y bloquea (RF-03)', async () => {
  const auditEvents = [];
  const repository = await crearRepositorioEnMemoria([
    {
      id: 'worker-9',
      name: 'Luis Rojas',
      email: 'luis@gamaitaly.cl',
      password: 'Temporal2026!',
      role: 'COLABORADOR',
      termsAccepted: false,
      isFirstLogin: true,
    },
  ]);
  const authService = new AuthService(repository, env, { log: (event) => auditEvents.push(event) });
  const baseUrl = await start(crearApp({ env, authService }));
  const headers = {
    'content-type': 'application/json',
    authorization: `Bearer ${jwt.sign({ role: 'COLABORADOR' }, jwtSecret, { subject: 'worker-9' })}`,
  };
  const post = (body) => fetch(`${baseUrl}/api/auth/primer-acceso`, { method: 'POST', headers, body: JSON.stringify(body) });

  // Aún sin aceptar: las rutas protegidas responden 403.
  const blocked = await fetch(`${baseUrl}/api/auth/sesion`, { headers });
  assert.equal(blocked.status, 403);
  assert.equal((await blocked.json()).error.code, 'TERMINOS_NO_ACEPTADOS');

  // Rechazar o aceptar una versión distinta no sirve.
  assert.equal((await post({ acceptTerms: false, termsVersion: 'GA-TOS-2026' })).status, 400);
  const old = await post({ acceptTerms: true, termsVersion: 'GA-TOS-2025' });
  assert.equal((await old.json()).error.code, 'TERMINOS_REQUERIDOS');
  assert.equal((await repository.findById('worker-9')).termsAccepted, false);

  // Aceptar la versión vigente guarda quién, cuándo y qué versión.
  assert.equal((await post({ acceptTerms: true, termsVersion: 'GA-TOS-2026' })).status, 200);
  const saved = await repository.findById('worker-9');
  assert.equal(saved.termsAccepted, true);
  assert.equal(saved.termsVersion, 'GA-TOS-2026');
  assert.ok(saved.termsAcceptedAt instanceof Date);
  assert.equal((await fetch(`${baseUrl}/api/auth/sesion`, { headers })).status, 200);
});

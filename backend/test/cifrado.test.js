import assert from 'node:assert/strict';
import { after, test } from 'node:test';
import { crearApp } from '../src/app.js';
import { conSslObligatorio } from '../src/config/env.js';

const base = 'postgresql://u:p@localhost:5432/BDTyckOps?schema=public';

test('DATABASE_URL sin sslmode recibe sslmode=require', () => {
  const url = new URL(conSslObligatorio(base));
  assert.equal(url.searchParams.get('sslmode'), 'require');
  assert.equal(url.searchParams.get('schema'), 'public');
});

test('DATABASE_URL con sslmode=require se mantiene', () => {
  assert.equal(new URL(conSslObligatorio(`${base}&sslmode=require`)).searchParams.get('sslmode'), 'require');
});

test('DATABASE_URL con sslmode que permite ir sin cifrar se rechaza', () => {
  for (const modo of ['disable', 'prefer', 'allow']) {
    assert.throws(() => conSslObligatorio(`${base}&sslmode=${modo}`), /debe ir cifrada/);
  }
});

const servers = [];
after(() => Promise.all(servers.map((s) => new Promise((r) => s.close(r)))));

async function iniciar(nodeEnv) {
  const app = crearApp({ env: { nodeEnv, jwtSecret: 'x'.repeat(40), corsOrigin: '*' } });
  const server = app.listen(0, '127.0.0.1');
  servers.push(server);
  await new Promise((r) => server.once('listening', r));
  return `http://127.0.0.1:${server.address().port}`;
}

test('producción: rechaza http y acepta lo que el proxy marca como https', async () => {
  const url = await iniciar('production');

  const porHttp = await fetch(`${url}/api/auth/login`, { method: 'POST' });
  assert.equal(porHttp.status, 403);
  assert.equal((await porHttp.json()).error.code, 'HTTPS_REQUERIDO');

  const porHttps = await fetch(`${url}/api/auth/me`, { headers: { 'x-forwarded-proto': 'https' } });
  assert.equal(porHttps.status, 401); // pasó el filtro https; falla solo por no tener sesión

  assert.equal((await fetch(`${url}/salud`)).status, 200); // chequeo de salud libre
  assert.match(porHttps.headers.get('strict-transport-security') ?? '', /max-age/);
});

test('desarrollo: http sigue funcionando', async () => {
  const url = await iniciar('development');
  assert.equal((await fetch(`${url}/api/auth/me`)).status, 401); // no 403 HTTPS_REQUERIDO
});

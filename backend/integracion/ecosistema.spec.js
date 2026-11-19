// ECOSISTEMA: Docker -> PostgreSQL -> Prisma -> servidor backend real (HTTP).
// Aquí el backend se levanta como proceso de verdad (node src/server.js) y se
// le habla por la red, igual que lo hace la app móvil.
import { execSync, spawn } from 'node:child_process';
import path from 'node:path';
import request from 'supertest';
import { PrismaClient } from '@prisma/client';
import {
  RAIZ_BACKEND,
  crearClientePruebas,
  reiniciarDatos,
  urlPruebas,
  urlReal,
  nombreBaseReal,
} from './helpers/baseDePruebas.js';
import { USUARIOS } from './helpers/usuarios.js';

const SCHEMA = path.resolve(RAIZ_BACKEND, '../database/BaseDatos/prisma/schema.prisma');

function levantarServidor(puerto, databaseUrl) {
  return new Promise((resolve, reject) => {
    const proceso = spawn(process.execPath, ['src/server.js'], {
      cwd: RAIZ_BACKEND,
      env: { ...process.env, PORT: String(puerto), DATABASE_URL: databaseUrl, NODE_ENV: 'development' },
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    const salida = [];
    const timer = setTimeout(() => reject(new Error(`El servidor no arrancó:\n${salida.join('')}`)), 30000);
    proceso.stdout.on('data', (d) => {
      salida.push(String(d));
      if (String(d).includes('escuchando')) {
        clearTimeout(timer);
        resolve(proceso);
      }
    });
    proceso.stderr.on('data', (d) => salida.push(String(d)));
    proceso.on('exit', (code) => {
      clearTimeout(timer);
      reject(new Error(`El servidor terminó (código ${code}):\n${salida.join('')}`));
    });
  });
}

function detener(proceso) {
  if (!proceso || proceso.exitCode !== null) return Promise.resolve();
  return new Promise((resolve) => {
    proceso.removeAllListeners('exit');
    proceso.once('exit', resolve);
    proceso.kill();
  });
}

describe('Docker y PostgreSQL', () => {
  test('el contenedor postgres_db está corriendo', () => {
    const estado = execSync('docker inspect -f "{{.State.Status}}" postgres_db').toString().trim();
    expect(estado).toBe('running');
  });

  test('la imagen es PostgreSQL 15', async () => {
    const prisma = new PrismaClient({ datasources: { db: { url: urlReal() } } });
    try {
      const [{ server_version: version }] = await prisma.$queryRaw`SHOW server_version`;
      expect(version).toMatch(/^15\./);
    } finally {
      await prisma.$disconnect();
    }
  });

  test('la base real tiene todas las migraciones aplicadas (solo lectura)', () => {
    const salida = execSync(`npx prisma migrate status --schema "${SCHEMA}"`, {
      cwd: RAIZ_BACKEND,
      env: { ...process.env, DATABASE_URL: urlReal() },
    }).toString();
    expect(salida).toContain('Database schema is up to date!');
  });

  test('la base real coincide exactamente con schema.prisma (sin diferencias)', () => {
    const diff = execSync(
      `npx prisma migrate diff --from-url "${urlReal()}" --to-schema-datamodel "${SCHEMA}" --exit-code`,
      { cwd: RAIZ_BACKEND },
    ).toString();
    expect(diff).toMatch(/No difference detected|empty migration/i);
  });

  test('la base real tiene las 9 tablas del modelo relacional', async () => {
    const prisma = new PrismaClient({ datasources: { db: { url: urlReal() } } });
    try {
      const filas = await prisma.$queryRaw`
        SELECT table_name FROM information_schema.tables
        WHERE table_schema = 'public' AND table_name <> '_prisma_migrations'`;
      expect(filas.map((f) => f.table_name).sort()).toEqual([
        'CategoriaReparacion', 'ComentarioTicket', 'Departamento', 'GuiaAutoayuda', 'Informe',
        'ReglasPrioridad', 'Roles', 'Ticket', 'Usuario',
      ]);
    } finally {
      await prisma.$disconnect();
    }
  });
});

describe('Backend real conectado a la base REAL (solo lectura)', () => {
  let servidor;
  const url = 'http://127.0.0.1:3101';

  beforeAll(async () => {
    servidor = await levantarServidor(3101, urlReal());
  });

  afterAll(() => detener(servidor));

  test(`/salud informa database=connected contra ${'BDTyckOps'}`, async () => {
    const res = await request(url).get('/salud');
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ success: true, data: { status: 'ok', database: 'connected' } });
    expect(nombreBaseReal()).toBe('BDTyckOps');
  });

  test('un login con clave errónea llega a la BD y responde 401 (no modifica datos)', async () => {
    const res = await request(url)
      .post('/api/auth/login')
      .send({ email: 'martin@gamaitaly.cl', password: 'ClaveQueNoEs123' });
    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe('CREDENCIALES_INVALIDAS');
  });
});

describe('Backend real por HTTP + base de pruebas: flujo completo', () => {
  let servidor;
  let prisma;
  const url = 'http://127.0.0.1:3102';

  beforeAll(async () => {
    prisma = crearClientePruebas();
    await reiniciarDatos(prisma);
    servidor = await levantarServidor(3102, urlPruebas());
  });

  afterAll(async () => {
    await detener(servidor);
    await prisma.$disconnect();
  });

  test('login -> primer acceso -> /me: cada paso se refleja en PostgreSQL', async () => {
    const u = USUARIOS.colaboradorNuevo;

    const login = await request(url).post('/api/auth/login').send({ email: u.email, password: u.password });
    expect(login.status).toBe(200);
    expect(login.body.data.user).toMatchObject({ isFirstLogin: true, termsAccepted: false });
    const { token } = login.body.data;

    const primerAcceso = await request(url)
      .post('/api/auth/primer-acceso')
      .set('Authorization', `Bearer ${token}`)
      .send({ acceptTerms: true, termsVersion: 'GA-TOS-2026' });
    expect(primerAcceso.status).toBe(200);

    const fila = await prisma.user.findUnique({ where: { email: u.email } });
    expect(fila).toMatchObject({ isFirstLogin: false, termsAccepted: true, termsVersion: 'GA-TOS-2026' });

    const me = await request(url).get('/api/auth/me').set('Authorization', `Bearer ${token}`);
    expect(me.body.data.user).toMatchObject({ isFirstLogin: false, termsAccepted: true });
  });

  test('CORS permite peticiones desde la app web (Flutter en Chrome)', async () => {
    const res = await request(url)
      .options('/api/auth/login')
      .set('Origin', 'http://localhost:5000')
      .set('Access-Control-Request-Method', 'POST');
    expect(res.status).toBe(204);
    expect(res.headers['access-control-allow-origin']).toBe('*');
  });
});

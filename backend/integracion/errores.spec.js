// CÓDIGOS DE ERROR: cada situación debe responder su código HTTP y su
// código interno, siempre con el formato {success:false, error:{code, message}}.
import { jest } from '@jest/globals';
import request from 'supertest';
import { crearApp } from '../src/app.js';
import { crearClientePruebas, reiniciarDatos } from './helpers/baseDePruebas.js';
import { crearAppPruebas, firmarToken, ENV_PRUEBAS } from './helpers/app.js';
import { USUARIOS } from './helpers/usuarios.js';

let prisma;
let usuarios;

beforeAll(async () => {
  prisma = crearClientePruebas();
  usuarios = await reiniciarDatos(prisma);
});

afterAll(async () => {
  await prisma.$disconnect();
});

function formatoDeError(res, status, code) {
  expect(res.status).toBe(status);
  expect(res.body).toEqual({
    success: false,
    error: expect.objectContaining({ code, message: expect.any(String) }),
  });
}

describe('404 - Ruta no encontrada', () => {
  test.each([
    ['GET', '/api/no-existe'],
    ['GET', '/api/auth'],
    ['POST', '/api/tickets'],
    ['DELETE', '/api/auth/login'],
    ['GET', '/'],
  ])('%s %s responde 404 RUTA_NO_ENCONTRADA', async (metodo, ruta) => {
    const { app } = crearAppPruebas(prisma);
    const res = await request(app)[metodo.toLowerCase()](ruta);
    formatoDeError(res, 404, 'RUTA_NO_ENCONTRADA');
  });
});

describe('401 - No autenticado / sesión inválida', () => {
  test('sin encabezado Authorization: 401 NO_AUTENTICADO', async () => {
    const { app } = crearAppPruebas(prisma);
    formatoDeError(await request(app).get('/api/auth/me'), 401, 'NO_AUTENTICADO');
  });

  test('esquema distinto de Bearer: 401 NO_AUTENTICADO', async () => {
    const { app } = crearAppPruebas(prisma);
    const res = await request(app).get('/api/auth/me').set('Authorization', 'Basic abc');
    formatoDeError(res, 401, 'NO_AUTENTICADO');
  });

  test('token que no es un JWT: 401 TOKEN_INVALIDO', async () => {
    const { app } = crearAppPruebas(prisma);
    const res = await request(app).get('/api/auth/me').set('Authorization', 'Bearer basura');
    formatoDeError(res, 401, 'TOKEN_INVALIDO');
  });

  test('token firmado con otra clave: 401 TOKEN_INVALIDO', async () => {
    const { app } = crearAppPruebas(prisma);
    const token = firmarToken(
      { id: usuarios.adminActivo.id, role: 'ADMINISTRADOR' },
      { secreto: 'otra-clave-distinta-de-la-del-servidor-123456' },
    );
    const res = await request(app).get('/api/admin/ejemplo').set('Authorization', `Bearer ${token}`);
    formatoDeError(res, 401, 'TOKEN_INVALIDO');
  });

  test('token vencido: 401 TOKEN_INVALIDO', async () => {
    const { app } = crearAppPruebas(prisma);
    const token = firmarToken({ id: usuarios.colaboradorActivo.id, role: 'COLABORADOR' }, { expiresIn: '-10s' });
    const res = await request(app).get('/api/auth/me').set('Authorization', `Bearer ${token}`);
    formatoDeError(res, 401, 'TOKEN_INVALIDO');
  });

  test('token de un usuario que ya no existe en la BD: 401 SESION_INVALIDA', async () => {
    const { app } = crearAppPruebas(prisma);
    const token = firmarToken({ id: 999999, role: 'COLABORADOR' });
    const res = await request(app).get('/api/auth/me').set('Authorization', `Bearer ${token}`);
    formatoDeError(res, 401, 'SESION_INVALIDA');
  });

  test('credenciales incorrectas: 401 CREDENCIALES_INVALIDAS', async () => {
    const { app } = crearAppPruebas(prisma);
    const res = await request(app)
      .post('/api/auth/login')
      .send({ email: USUARIOS.adminActivo.email, password: 'NoEsLaClave1' });
    formatoDeError(res, 401, 'CREDENCIALES_INVALIDAS');
  });
});

describe('403 - Prohibido (autenticado, pero sin permiso)', () => {
  test('colaborador en ruta de administrador: 403 SIN_ROL_ADMIN', async () => {
    const { app } = crearAppPruebas(prisma);
    const token = firmarToken({ id: usuarios.colaboradorActivo.id, role: 'COLABORADOR' });
    const res = await request(app).get('/api/admin/ejemplo').set('Authorization', `Bearer ${token}`);
    formatoDeError(res, 403, 'SIN_ROL_ADMIN');
  });

  test('administrador que no aceptó los Términos: 403 TERMINOS_NO_ACEPTADOS', async () => {
    const { app } = crearAppPruebas(prisma);
    const token = firmarToken({ id: usuarios.adminNuevo.id, role: 'ADMINISTRADOR' });
    const res = await request(app).get('/api/admin/ejemplo').set('Authorization', `Bearer ${token}`);
    formatoDeError(res, 403, 'TERMINOS_NO_ACEPTADOS');
  });

  test('rol no habilitado al iniciar sesión: 403 ROL_INVALIDO', async () => {
    const { app } = crearAppPruebas(prisma);
    const res = await request(app)
      .post('/api/auth/login')
      .send({ email: USUARIOS.sinRolValido.email, password: USUARIOS.sinRolValido.password });
    formatoDeError(res, 403, 'ROL_INVALIDO');
  });
});

describe('400 - Datos inválidos', () => {
  test('validación de Zod devuelve el detalle por campo', async () => {
    const { app } = crearAppPruebas(prisma);
    const res = await request(app).post('/api/auth/login').send({ email: 'x' });
    formatoDeError(res, 400, 'DATOS_INVALIDOS');
    expect(res.body.error.details.map((d) => d.field)).toEqual(expect.arrayContaining(['email', 'password']));
  });

  test('JSON mal formado responde 400 DATOS_INVALIDOS sin registrar una traza', async () => {
    const { app } = crearAppPruebas(prisma);
    const silenciar = jest.spyOn(console, 'error').mockImplementation(() => {});
    try {
      const res = await request(app)
        .post('/api/auth/login')
        .set('Content-Type', 'application/json')
        .send('{"email": "roto"');
      formatoDeError(res, 400, 'DATOS_INVALIDOS');
      expect(silenciar).not.toHaveBeenCalled();
    } finally {
      silenciar.mockRestore();
    }
  });
});

describe('409 - Conflicto de estado', () => {
  test('repetir el primer acceso: 409 PRIMER_ACCESO_COMPLETADO', async () => {
    const { app } = crearAppPruebas(prisma);
    const token = firmarToken({ id: usuarios.colaboradorActivo.id, role: 'COLABORADOR' });
    const res = await request(app)
      .post('/api/auth/primer-acceso')
      .set('Authorization', `Bearer ${token}`)
      .send({ acceptTerms: true, termsVersion: 'GA-TOS-2026' });
    formatoDeError(res, 409, 'PRIMER_ACCESO_COMPLETADO');
  });
});

describe('503 - Base de datos no disponible', () => {
  test('sin conexión a PostgreSQL el login responde 503 AUTENTICACION_NO_DISPONIBLE', async () => {
    const app = crearApp({ env: ENV_PRUEBAS, databaseStatus: 'disconnected' });
    const res = await request(app)
      .post('/api/auth/login')
      .send({ email: USUARIOS.adminActivo.email, password: USUARIOS.adminActivo.password });
    formatoDeError(res, 503, 'AUTENTICACION_NO_DISPONIBLE');

    const salud = await request(app).get('/salud');
    expect(salud.status).toBe(200);
    expect(salud.body.data.database).toBe('disconnected');
  });
});

describe('Encabezados de seguridad', () => {
  test('Helmet activo y sin X-Powered-By', async () => {
    const { app } = crearAppPruebas(prisma);
    const res = await request(app).get('/salud');
    expect(res.headers['x-powered-by']).toBeUndefined();
    expect(res.headers['x-content-type-options']).toBe('nosniff');
    expect(res.headers['access-control-allow-origin']).toBe('*');
  });
});

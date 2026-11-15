// PRIMER INGRESO (RF-02) y TÉRMINOS Y CONDICIONES (RF-03).
// Cada prueba verifica la respuesta HTTP Y lo que quedó guardado en PostgreSQL.
import request from 'supertest';
import bcrypt from 'bcryptjs';
import { crearClientePruebas, reiniciarDatos } from './helpers/baseDePruebas.js';
import { crearAppPruebas } from './helpers/app.js';
import { USUARIOS } from './helpers/usuarios.js';

const VERSION = 'GA-TOS-2026';
let prisma;

beforeAll(() => {
  prisma = crearClientePruebas();
});

beforeEach(async () => {
  await reiniciarDatos(prisma); // cada prueba parte con los usuarios "nuevos"
});

afterAll(async () => {
  await prisma.$disconnect();
});

async function iniciarSesion(app, u) {
  const res = await request(app).post('/api/auth/login').send({ email: u.email, password: u.password });
  expect(res.status).toBe(200);
  return res.body.data;
}

const enBd = (email) => prisma.user.findUnique({ where: { email } });

describe('Login de un usuario que entra por primera vez', () => {
  test.each([
    ['colaborador', USUARIOS.colaboradorNuevo, 'COLABORADOR'],
    ['administrador', USUARIOS.adminNuevo, 'ADMINISTRADOR'],
  ])('%s nuevo: el login indica isFirstLogin=true y termsAccepted=false', async (_rol, u, role) => {
    const { app } = crearAppPruebas(prisma);
    const { user } = await iniciarSesion(app, u);
    expect(user).toMatchObject({ role, isFirstLogin: true, termsAccepted: false });
  });

  test('usuario que ya completó el primer acceso: isFirstLogin=false y termsAccepted=true', async () => {
    const { app } = crearAppPruebas(prisma);
    const { user } = await iniciarSesion(app, USUARIOS.colaboradorActivo);
    expect(user).toMatchObject({ isFirstLogin: false, termsAccepted: true });
  });
});

describe('Primer acceso SIN aceptar los Términos', () => {
  test.each([
    ['acceptTerms=false', { acceptTerms: false, termsVersion: VERSION }],
    ['versión de Términos distinta', { acceptTerms: true, termsVersion: 'GA-TOS-2025' }],
  ])('%s: 400 TERMINOS_REQUERIDOS y la BD no cambia', async (_caso, cuerpo) => {
    const { app, auditoria } = crearAppPruebas(prisma);
    const u = USUARIOS.colaboradorNuevo;
    const { token } = await iniciarSesion(app, u);

    const res = await request(app)
      .post('/api/auth/primer-acceso')
      .set('Authorization', `Bearer ${token}`)
      .send(cuerpo);

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('TERMINOS_REQUERIDOS');
    expect(auditoria).toContainEqual(expect.objectContaining({ action: 'terms_rejected' }));

    const fila = await enBd(u.email);
    expect(fila).toMatchObject({ isFirstLogin: true, termsAccepted: false, termsVersion: null, termsAcceptedAt: null });
  });

  test('sin el campo acceptTerms: 400 DATOS_INVALIDOS', async () => {
    const { app } = crearAppPruebas(prisma);
    const { token } = await iniciarSesion(app, USUARIOS.colaboradorNuevo);
    const res = await request(app)
      .post('/api/auth/primer-acceso')
      .set('Authorization', `Bearer ${token}`)
      .send({ termsVersion: VERSION });
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('DATOS_INVALIDOS');
  });

  test('mientras no acepte, las rutas que exigen Términos responden 403', async () => {
    const { app } = crearAppPruebas(prisma);
    const { token } = await iniciarSesion(app, USUARIOS.colaboradorNuevo);
    const res = await request(app).get('/api/auth/sesion').set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe('TERMINOS_NO_ACEPTADOS');
  });
});

describe('Primer acceso ACEPTANDO los Términos', () => {
  test('mantener la contraseña temporal: 200 y queda registrado en la BD', async () => {
    const { app, auditoria } = crearAppPruebas(prisma);
    const u = USUARIOS.colaboradorNuevo;
    const { token } = await iniciarSesion(app, u);
    const antes = Date.now();

    const res = await request(app)
      .post('/api/auth/primer-acceso')
      .set('Authorization', `Bearer ${token}`)
      .send({ acceptTerms: true, termsVersion: VERSION });

    expect(res.status).toBe(200);
    expect(res.body.data.user).toMatchObject({ isFirstLogin: false, termsAccepted: true, role: 'COLABORADOR' });

    const fila = await enBd(u.email);
    expect(fila.isFirstLogin).toBe(false);
    expect(fila.termsAccepted).toBe(true);
    expect(fila.termsVersion).toBe(VERSION);
    expect(fila.termsAcceptedAt.getTime()).toBeGreaterThanOrEqual(antes - 5000);
    expect(await bcrypt.compare(u.password, fila.passwordHash)).toBe(true); // misma clave

    expect(auditoria.map((e) => e.action)).toEqual(expect.arrayContaining(['terms_accepted', 'password_kept']));

    // Ahora sí puede usar las rutas protegidas por Términos.
    const sesion = await request(app).get('/api/auth/sesion').set('Authorization', `Bearer ${token}`);
    expect(sesion.status).toBe(200);
  });

  test('cambiar la contraseña: la nueva funciona, la antigua no, y se guarda cifrada', async () => {
    const { app } = crearAppPruebas(prisma);
    const u = USUARIOS.adminNuevo;
    const { token } = await iniciarSesion(app, u);
    const nueva = 'NuevaClaveAdmin2026';

    const res = await request(app)
      .post('/api/auth/primer-acceso')
      .set('Authorization', `Bearer ${token}`)
      .send({ acceptTerms: true, termsVersion: VERSION, currentPassword: u.password, newPassword: nueva });
    expect(res.status).toBe(200);

    const fila = await enBd(u.email);
    expect(fila.passwordHash).not.toContain(nueva);
    expect(fila.passwordHash).toMatch(/^\$2[aby]\$12\$/);

    const { app: app2 } = crearAppPruebas(prisma);
    const conNueva = await request(app2).post('/api/auth/login').send({ email: u.email, password: nueva });
    expect(conNueva.status).toBe(200);
    expect(conNueva.body.data.user).toMatchObject({ isFirstLogin: false, termsAccepted: true });

    const conAntigua = await request(app2).post('/api/auth/login').send({ email: u.email, password: u.password });
    expect(conAntigua.status).toBe(401);
  });

  test('administrador: tras aceptar, la ruta de administrador responde 200', async () => {
    const { app } = crearAppPruebas(prisma);
    const { token } = await iniciarSesion(app, USUARIOS.adminNuevo);
    const antes = await request(app).get('/api/admin/ejemplo').set('Authorization', `Bearer ${token}`);
    expect(antes.status).toBe(403);
    expect(antes.body.error.code).toBe('TERMINOS_NO_ACEPTADOS');

    await request(app)
      .post('/api/auth/primer-acceso')
      .set('Authorization', `Bearer ${token}`)
      .send({ acceptTerms: true, termsVersion: VERSION })
      .expect(200);

    const despues = await request(app).get('/api/admin/ejemplo').set('Authorization', `Bearer ${token}`);
    expect(despues.status).toBe(200);
    expect(despues.body.data.role).toBe('ADMINISTRADOR');
  });

  test('contraseña temporal actual incorrecta: 400 y la BD no cambia', async () => {
    const { app } = crearAppPruebas(prisma);
    const u = USUARIOS.colaboradorNuevo;
    const { token } = await iniciarSesion(app, u);
    const res = await request(app)
      .post('/api/auth/primer-acceso')
      .set('Authorization', `Bearer ${token}`)
      .send({ acceptTerms: true, termsVersion: VERSION, currentPassword: 'NoEsLaActual1', newPassword: 'OtraClave2026' });

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('CONTRASENA_ACTUAL_INCORRECTA');
    expect(await enBd(u.email)).toMatchObject({ isFirstLogin: true, termsAccepted: false });
  });

  test('nueva contraseña igual a la actual: 400 CONTRASENA_REPETIDA', async () => {
    const { app } = crearAppPruebas(prisma);
    const u = USUARIOS.colaboradorNuevo;
    const { token } = await iniciarSesion(app, u);
    const res = await request(app)
      .post('/api/auth/primer-acceso')
      .set('Authorization', `Bearer ${token}`)
      .send({ acceptTerms: true, termsVersion: VERSION, currentPassword: u.password, newPassword: u.password });
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('CONTRASENA_REPETIDA');
  });

  test.each([
    ['menos de 8 caracteres', 'Abc123'],
    ['sin números', 'SoloLetrasAqui'],
    ['sin letras', '1234567890'],
  ])('nueva contraseña %s: 400 DATOS_INVALIDOS', async (_caso, nueva) => {
    const { app } = crearAppPruebas(prisma);
    const u = USUARIOS.colaboradorNuevo;
    const { token } = await iniciarSesion(app, u);
    const res = await request(app)
      .post('/api/auth/primer-acceso')
      .set('Authorization', `Bearer ${token}`)
      .send({ acceptTerms: true, termsVersion: VERSION, currentPassword: u.password, newPassword: nueva });
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('DATOS_INVALIDOS');
  });

  test('intentar el primer acceso por segunda vez: 409', async () => {
    const { app } = crearAppPruebas(prisma);
    const { token } = await iniciarSesion(app, USUARIOS.colaboradorNuevo);
    const cuerpo = { acceptTerms: true, termsVersion: VERSION };
    await request(app).post('/api/auth/primer-acceso').set('Authorization', `Bearer ${token}`).send(cuerpo).expect(200);
    const segunda = await request(app).post('/api/auth/primer-acceso').set('Authorization', `Bearer ${token}`).send(cuerpo);
    expect(segunda.status).toBe(409);
    expect(segunda.body.error.code).toBe('PRIMER_ACCESO_COMPLETADO');
  });

  test('/auth/me refleja el estado actualizado tras el primer acceso', async () => {
    const { app } = crearAppPruebas(prisma);
    const { token } = await iniciarSesion(app, USUARIOS.adminNuevo);
    await request(app)
      .post('/api/auth/primer-acceso')
      .set('Authorization', `Bearer ${token}`)
      .send({ acceptTerms: true, termsVersion: VERSION })
      .expect(200);
    const me = await request(app).get('/api/auth/me').set('Authorization', `Bearer ${token}`);
    expect(me.status).toBe(200);
    expect(me.body.data.user).toMatchObject({ isFirstLogin: false, termsAccepted: true, role: 'ADMINISTRADOR' });
  });
});

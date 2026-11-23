// LOGIN (RF-01) contra PostgreSQL real: casos correctos e incorrectos.
import request from 'supertest';
import jwt from 'jsonwebtoken';
import { crearClientePruebas, reiniciarDatos } from './helpers/baseDePruebas.js';
import { crearAppPruebas, ENV_PRUEBAS } from './helpers/app.js';
import { USUARIOS } from './helpers/usuarios.js';

let prisma;

beforeAll(async () => {
  prisma = crearClientePruebas();
  await reiniciarDatos(prisma);
});

afterAll(async () => {
  await prisma.$disconnect();
});

const login = (app, email, password) =>
  request(app).post('/api/auth/login').send({ email, password });

describe('Login correcto', () => {
  test('colaborador: 200, token válido y datos leídos de la BD', async () => {
    const { app, auditoria } = crearAppPruebas(prisma);
    const u = USUARIOS.colaboradorActivo;
    const res = await login(app, u.email, u.password);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.user).toEqual({
      id: expect.any(String),
      name: 'Martin',
      email: u.email,
      role: 'COLABORADOR',
      area: 'Servicios generales', // sale de la tabla Departamento
      termsAccepted: true,
      isFirstLogin: false,
    });

    const enBd = await prisma.user.findUnique({ where: { email: u.email } });
    expect(res.body.data.user.id).toBe(String(enBd.id));

    const payload = jwt.verify(res.body.data.token, ENV_PRUEBAS.jwtSecret);
    expect(payload.sub).toBe(String(enBd.id));
    expect(payload.role).toBe('COLABORADOR');
    expect(payload.exp - payload.iat).toBe(3600); // expira en 1 hora

    expect(auditoria).toContainEqual(expect.objectContaining({ action: 'login_succeeded', email: u.email }));
  });

  test('administrador: 200 con rol ADMINISTRADOR', async () => {
    const { app } = crearAppPruebas(prisma);
    const u = USUARIOS.adminActivo;
    const res = await login(app, u.email, u.password);

    expect(res.status).toBe(200);
    expect(res.body.data.user.role).toBe('ADMINISTRADOR');
    expect(res.body.data.user.area).toBe('Administracion');
    expect(jwt.verify(res.body.data.token, ENV_PRUEBAS.jwtSecret).role).toBe('ADMINISTRADOR');
  });

  test('el correo no distingue mayúsculas ni espacios', async () => {
    const { app } = crearAppPruebas(prisma);
    const u = USUARIOS.colaboradorActivo;
    const res = await login(app, `  ${u.email.toUpperCase()}  `, u.password);
    expect(res.status).toBe(200);
    expect(res.body.data.user.email).toBe(u.email);
  });

  test('la respuesta nunca incluye la contraseña ni su hash', async () => {
    const { app } = crearAppPruebas(prisma);
    const u = USUARIOS.adminActivo;
    const res = await login(app, u.email, u.password);
    const texto = JSON.stringify(res.body);
    expect(texto).not.toMatch(/password/i);
    expect(texto).not.toContain('$argon2id$');
    expect(texto).not.toContain('$2b$');
  });

  test('las contraseñas en la BD están cifradas con Argon2id (parámetros OWASP)', async () => {
    const usuarios = await prisma.user.findMany();
    for (const usuario of usuarios) {
      expect(usuario.passwordHash).toMatch(/^\$argon2id\$v=19\$m=19456,t=2,p=1\$/);
    }
  });
});

describe('Login incorrecto', () => {
  test('contraseña equivocada: 401 CREDENCIALES_INVALIDAS', async () => {
    const { app, auditoria } = crearAppPruebas(prisma);
    const res = await login(app, USUARIOS.colaboradorActivo.email, 'ClaveEquivocada9');

    expect(res.status).toBe(401);
    expect(res.body).toEqual({
      success: false,
      error: { code: 'CREDENCIALES_INVALIDAS', message: 'Correo o contraseña incorrectos.' },
    });
    expect(auditoria).toContainEqual(expect.objectContaining({ action: 'login_failed' }));
  });

  test('correo inexistente: misma respuesta 401 (no revela qué cuentas existen)', async () => {
    const { app } = crearAppPruebas(prisma);
    const malaClave = await login(app, USUARIOS.colaboradorActivo.email, 'ClaveEquivocada9');
    const noExiste = await login(app, 'nadie@gamaitaly.cl', 'ClaveEquivocada9');

    expect(noExiste.status).toBe(401);
    expect(noExiste.body).toEqual(malaClave.body);
  });

  test('correo no corporativo: 400 DATOS_INVALIDOS', async () => {
    const { app } = crearAppPruebas(prisma);
    const res = await login(app, 'usuario@example.com', 'cualquiera');

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('DATOS_INVALIDOS');
    expect(res.body.error.details).toContainEqual({
      field: 'email',
      message: 'Usa tu correo corporativo @gamaitaly.cl.',
    });
  });

  test.each([
    ['cuerpo vacío', {}],
    ['correo con formato inválido', { email: 'no-es-correo', password: 'x' }],
    ['contraseña vacía', { email: 'colaborador.activo@gamaitaly.cl', password: '' }],
    ['contraseña de más de 128 caracteres', { email: 'colaborador.activo@gamaitaly.cl', password: 'a'.repeat(129) }],
  ])('%s: 400 DATOS_INVALIDOS', async (_caso, cuerpo) => {
    const { app } = crearAppPruebas(prisma);
    const res = await request(app).post('/api/auth/login').send(cuerpo);
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('DATOS_INVALIDOS');
  });

  test('usuario con un rol no habilitado: 403 ROL_INVALIDO', async () => {
    const { app } = crearAppPruebas(prisma);
    const u = USUARIOS.sinRolValido;
    const res = await login(app, u.email, u.password);
    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe('ROL_INVALIDO');
  });

  test('6.º intento en 15 minutos: 429 DEMASIADOS_INTENTOS', async () => {
    const { app } = crearAppPruebas(prisma);
    for (let i = 0; i < 5; i += 1) {
      const res = await login(app, USUARIOS.colaboradorActivo.email, 'ClaveEquivocada9');
      expect(res.status).toBe(401);
    }
    const bloqueado = await login(app, USUARIOS.colaboradorActivo.email, USUARIOS.colaboradorActivo.password);
    expect(bloqueado.status).toBe(429);
    expect(bloqueado.body.error.code).toBe('DEMASIADOS_INTENTOS');
  });
});

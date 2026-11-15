// ACCESO POR ROL en el backend: el colaborador solo accede a lo suyo y el
// administrador a lo suyo. (La app móvil oculta pantallas, pero quien
// protege los datos de verdad es el servidor.)
import request from 'supertest';
import { crearClientePruebas, reiniciarDatos } from './helpers/baseDePruebas.js';
import { crearAppPruebas } from './helpers/app.js';
import { USUARIOS } from './helpers/usuarios.js';

let prisma;

beforeAll(async () => {
  prisma = crearClientePruebas();
  await reiniciarDatos(prisma);
});

afterAll(async () => {
  await prisma.$disconnect();
});

async function tokenDe(app, u) {
  const res = await request(app).post('/api/auth/login').send({ email: u.email, password: u.password });
  expect(res.status).toBe(200);
  return res.body.data.token;
}

describe('Colaborador', () => {
  test('puede ver su propia sesión (/auth/me y /auth/sesion)', async () => {
    const { app } = crearAppPruebas(prisma);
    const token = await tokenDe(app, USUARIOS.colaboradorActivo);
    const me = await request(app).get('/api/auth/me').set('Authorization', `Bearer ${token}`);
    expect(me.status).toBe(200);
    expect(me.body.data.user.email).toBe(USUARIOS.colaboradorActivo.email);
    const sesion = await request(app).get('/api/auth/sesion').set('Authorization', `Bearer ${token}`);
    expect(sesion.status).toBe(200);
    expect(sesion.body.data.role).toBe('COLABORADOR');
  });

  test('NO puede entrar a la ruta de administrador: 403 SIN_ROL_ADMIN', async () => {
    const { app } = crearAppPruebas(prisma);
    const token = await tokenDe(app, USUARIOS.colaboradorActivo);
    const res = await request(app).get('/api/admin/ejemplo').set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe('SIN_ROL_ADMIN');
  });
});

describe('Administrador', () => {
  test('puede entrar a la ruta de administrador: 200', async () => {
    const { app } = crearAppPruebas(prisma);
    const token = await tokenDe(app, USUARIOS.adminActivo);
    const res = await request(app).get('/api/admin/ejemplo').set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(200);
    expect(res.body.data).toMatchObject({ message: 'Acceso de administrador autorizado.', role: 'ADMINISTRADOR' });
  });

  test('/auth/me devuelve su propio usuario, no el de otro', async () => {
    const { app } = crearAppPruebas(prisma);
    const token = await tokenDe(app, USUARIOS.adminActivo);
    const me = await request(app).get('/api/auth/me').set('Authorization', `Bearer ${token}`);
    expect(me.body.data.user).toMatchObject({ email: USUARIOS.adminActivo.email, role: 'ADMINISTRADOR' });
  });
});

describe('El rol lo decide la BD, no el cliente', () => {
  test('si se cambia el rol en la BD, el siguiente login entrega el rol nuevo', async () => {
    const { app } = crearAppPruebas(prisma);
    const u = USUARIOS.colaboradorActivo;
    const admin = await prisma.roles.findFirst({ where: { NombreRol: 'administrador' } });
    const colab = await prisma.roles.findFirst({ where: { NombreRol: 'colaborador' } });

    await prisma.user.update({ where: { email: u.email }, data: { ID_Rol: admin.ID_Rol } });
    try {
      const token = await tokenDe(app, u);
      const res = await request(app).get('/api/admin/ejemplo').set('Authorization', `Bearer ${token}`);
      expect(res.status).toBe(200);
    } finally {
      await prisma.user.update({ where: { email: u.email }, data: { ID_Rol: colab.ID_Rol } });
    }
  });
});

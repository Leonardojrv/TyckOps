// REPORTAR FALLA (RF-04) contra PostgreSQL real: la foto se guarda en la
// columna imagen (BYTEA) del ticket, sin metadatos, y nunca viaja en las
// respuestas ni en los listados.
import jwt from 'jsonwebtoken';
import request from 'supertest';
import { crearClientePruebas, reiniciarDatos } from './helpers/baseDePruebas.js';
import { ENV_PRUEBAS, crearAppPruebas } from './helpers/app.js';
import { USUARIOS } from './helpers/usuarios.js';
import { crearSesionCreacion } from '../src/modules/tickets/tickets.sesionCreacion.js';

let prisma;

beforeAll(() => {
  prisma = crearClientePruebas();
});

beforeEach(async () => {
  await reiniciarDatos(prisma);
});

afterAll(async () => {
  await prisma.$disconnect();
});

const segmento = (marcador, datos) => {
  const largo = Buffer.alloc(2);
  largo.writeUInt16BE(datos.length + 2);
  return Buffer.concat([Buffer.from([0xff, marcador]), largo, datos]);
};

// JPG mínimo con un bloque EXIF que trae "coordenadas GPS" falsas.
const JPG_CON_GPS = Buffer.concat([
  Buffer.from([0xff, 0xd8]),
  segmento(0xe0, Buffer.from('JFIF\0')),
  segmento(0xe1, Buffer.from('Exif\0\0GPS-33.4489,-70.6693')),
  segmento(0xdb, Buffer.alloc(65)),
  Buffer.from([0xff, 0xda, 0x00, 0x02, 0x11, 0x22, 0xff, 0xd9]),
]);

async function tokenDe(app, u) {
  const res = await request(app).post('/api/auth/login').send({ email: u.email, password: u.password });
  expect(res.status).toBe(200);
  return res.body.data.token;
}

function reportar(app, token, { categoria = 'ELECTRICA', foto = JPG_CON_GPS } = {}) {
  const peticion = request(app)
    .post('/api/tickets')
    .set('Authorization', `Bearer ${token}`)
    .set('X-Sesion-Creacion', crearSesionCreacion(ENV_PRUEBAS.jwtSecret, jwt.decode(token).sub).token)
    .field('categoria', categoria)
    .field('ubicacion', 'Piso 2, Sala B')
    .field('descripcion', 'El enchufe echa chispas al conectar');
  return foto ? peticion.attach('foto', foto, { filename: 'falla.jpg', contentType: 'image/jpeg' }) : peticion;
}

describe('Foto del reporte en la columna imagen (BYTEA)', () => {
  test('con foto: se guarda en Ticket.imagen, limpia de metadatos', async () => {
    const { app } = crearAppPruebas(prisma);
    const token = await tokenDe(app, USUARIOS.colaboradorActivo);

    const res = await reportar(app, token);
    expect(res.status).toBe(201);
    const { ticket } = res.body.data;
    expect(ticket).toMatchObject({ status: 'RECIBIDO', category: 'Eléctrica' });
    expect(ticket).not.toHaveProperty('imagen'); // la foto no viaja en la respuesta

    const fila = await prisma.ticket.findUnique({ where: { ID_Ticket: Number(ticket.id) } });
    const imagen = Buffer.from(fila.imagen);
    expect(imagen.subarray(0, 3)).toEqual(Buffer.from([0xff, 0xd8, 0xff])); // sigue siendo un JPG
    expect(imagen.includes('JFIF')).toBe(true);
    expect(imagen.includes('GPS')).toBe(false); // EXIF eliminado
    expect(imagen.length).toBeLessThan(JPG_CON_GPS.length);
  });

  test('sin foto: el ticket se crea con imagen = NULL', async () => {
    const { app } = crearAppPruebas(prisma);
    const token = await tokenDe(app, USUARIOS.colaboradorActivo);

    const res = await reportar(app, token, { foto: null, categoria: 'BANOS' });
    expect(res.status).toBe(201);
    const fila = await prisma.ticket.findUnique({ where: { ID_Ticket: Number(res.body.data.ticket.id) } });
    expect(fila.imagen).toBeNull();
  });

  test('archivo que no es imagen: 415 y no se crea ningún ticket', async () => {
    const { app } = crearAppPruebas(prisma);
    const token = await tokenDe(app, USUARIOS.colaboradorActivo);

    const res = await reportar(app, token, { foto: Buffer.from('MZ esto no es una foto') });
    expect(res.status).toBe(415);
    expect(res.body.error.code).toBe('FOTO_TIPO_INVALIDO');
    expect(await prisma.ticket.count()).toBe(0);
  });

  test('"mis tickets" y el detalle no incluyen la imagen', async () => {
    const { app } = crearAppPruebas(prisma);
    const token = await tokenDe(app, USUARIOS.colaboradorActivo);
    const creado = (await reportar(app, token)).body.data.ticket;

    const lista = await request(app).get('/api/tickets/mis-tickets').set('Authorization', `Bearer ${token}`);
    expect(lista.status).toBe(200);
    expect(lista.body.data.tickets).toHaveLength(1);
    expect(JSON.stringify(lista.body)).not.toMatch(/imagen|JFIF/);

    const detalle = await request(app).get(`/api/tickets/${creado.id}`).set('Authorization', `Bearer ${token}`);
    expect(detalle.status).toBe(200);
    expect(detalle.body.data.ticket ?? detalle.body.data).not.toHaveProperty('imagen');
  });
});

describe('Categoría Inmobiliario (nombre corregido)', () => {
  test('la BD guarda "Inmobiliario" y un reporte de esa categoría se crea bien', async () => {
    expect(await prisma.categoriaReparacion.findFirst({ where: { nombre: 'Inmoviliario' } })).toBeNull();

    const { app } = crearAppPruebas(prisma);
    const token = await tokenDe(app, USUARIOS.colaboradorActivo);
    const res = await reportar(app, token, { categoria: 'INMOBILIARIO', foto: null });
    expect(res.status).toBe(201);
    expect(res.body.data.ticket.category).toBe('Inmobiliario');

    const fila = await prisma.ticket.findUnique({
      where: { ID_Ticket: Number(res.body.data.ticket.id) },
      include: { categoriaReparacion: true },
    });
    expect(fila.categoriaReparacion.nombre).toBe('Inmobiliario');
  });
});

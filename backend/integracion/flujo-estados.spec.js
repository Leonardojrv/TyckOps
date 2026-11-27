// FLUJO TRANSACCIONAL DE ESTADOS contra PostgreSQL real (BDTyckOps_pruebas).
// Todo se hace por HTTP, como la app y el administrador: el colaborador crea
// el ticket, el administrador lo aprueba o rechaza, y después de cada paso se
// revisa que las tablas Ticket y Notificacion queden coherentes y que el
// colaborador vea su estado en GET /api/tickets/:id/estado.

import request from 'supertest';
import { crearClientePruebas, reiniciarDatos } from './helpers/baseDePruebas.js';
import { ENV_PRUEBAS, crearAppPruebas, firmarToken } from './helpers/app.js';
import { PrismaTicketRepository } from '../src/modules/tickets/tickets.prisma.repository.js';
import { crearSesionCreacion } from '../src/modules/tickets/tickets.sesionCreacion.js';

const prisma = crearClientePruebas();
let usuarios;
let app;
let tokenColaborador;
let tokenAdmin;

const MOTIVO_RECHAZO = 'El equipo reportado pertenece al proveedor externo de climatización; '
  + 'debe gestionarse por su mesa de soporte según el contrato vigente.';

beforeAll(() => prisma.$connect());
afterAll(() => prisma.$disconnect());

beforeEach(async () => {
  usuarios = await reiniciarDatos(prisma);
  ({ app } = crearAppPruebas(prisma));
  tokenColaborador = firmarToken({ id: usuarios.colaboradorActivo.id, role: 'COLABORADOR' });
  tokenAdmin = firmarToken({ id: usuarios.adminActivo.id, role: 'ADMINISTRADOR' });
});

// ---------- Ayudas ----------

/** El colaborador reporta una falla por HTTP (con su permiso de creación). */
async function reportar({ ubicacion = 'Piso 2, Sala B', descripcion = 'El enchufe echa chispas al conectar' } = {}) {
  const res = await request(app)
    .post('/api/tickets')
    .set('Authorization', `Bearer ${tokenColaborador}`)
    .set('X-Sesion-Creacion', crearSesionCreacion(ENV_PRUEBAS.jwtSecret, usuarios.colaboradorActivo.id).token)
    .field('categoria', 'ELECTRICA')
    .field('ubicacion', ubicacion)
    .field('descripcion', descripcion);
  expect(res.status).toBe(201);
  return res.body.data.ticket.id;
}

/** La prioridad la pone el backend un instante después de crear el ticket. */
async function esperarPrioridad(id) {
  for (let intento = 0; intento < 50; intento += 1) {
    const fila = await prisma.ticket.findUnique({ where: { ID_Ticket: Number(id) }, select: { Prioridad: true } });
    if (fila?.Prioridad) return fila.Prioridad;
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  throw new Error(`El ticket ${id} nunca recibió prioridad`);
}

const cambiarEstado = (id, estado, motivo) => request(app)
  .patch(`/api/admin/tickets/${id}/estado`)
  .set('Authorization', `Bearer ${tokenAdmin}`)
  .send(motivo ? { estado, motivo } : { estado });

const consultarEstado = (id, token = tokenColaborador) => request(app)
  .get(`/api/tickets/${id}/estado`)
  .set('Authorization', `Bearer ${token}`);

const filaTicket = (id) => prisma.ticket.findUnique({
  where: { ID_Ticket: Number(id) },
  select: {
    Estado: true, Prioridad: true, PrioridadInicial: true, OrigenPrioridad: true,
    ID_admin_revisor: true, FechaCierre: true, MotivoRechazo: true, ID_user: true,
  },
});

const avisosDeEstado = (id) => prisma.notificacion.findMany({
  where: { ID_Ticket: Number(id), Tipo: 'estado' },
  orderBy: { ID_Notificacion: 'asc' },
  select: { EstadoTicket: true, ID_user: true, Leida: true },
});

// ---------- Flujo de aprobación ----------

describe('Aprobación completa por HTTP: Recibido → En revisión → Aprobado → En proceso → Resuelto → Cerrado', () => {
  test('cada paso queda coherente en Ticket y Notificacion, y el colaborador lo ve en /estado', async () => {
    const id = await reportar();

    // Valores por defecto del ticket operativo (sin IA conectada): Recibido y Media.
    expect(await esperarPrioridad(id)).toBe('media');
    expect(await filaTicket(id)).toMatchObject({
      Estado: 'recibido', PrioridadInicial: 'media', OrigenPrioridad: 'defecto',
      ID_admin_revisor: null, FechaCierre: null, MotivoRechazo: null,
    });
    let estado = (await consultarEstado(id)).body.data;
    expect(estado).toMatchObject({ status: 'RECIBIDO', priority: 'MEDIA', resolution: { type: 'pendiente' } });
    expect(estado.duplicate).toEqual({ isDuplicate: false, original: null });

    const pasos = [
      { estado: 'EN_REVISION', resolucion: 'en_gestion', revisor: null, cerrado: false },
      { estado: 'APROBADO', resolucion: 'en_gestion', revisor: usuarios.adminActivo.id, cerrado: false },
      { estado: 'EN_PROCESO', resolucion: 'en_gestion', revisor: usuarios.adminActivo.id, cerrado: false },
      { estado: 'RESUELTO', resolucion: 'resuelto', revisor: usuarios.adminActivo.id, cerrado: true },
      { estado: 'CERRADO', resolucion: 'cerrado', revisor: usuarios.adminActivo.id, cerrado: true },
    ];

    for (const [indice, paso] of pasos.entries()) {
      const res = await cambiarEstado(id, paso.estado);
      expect(res.status).toBe(200);
      expect(res.body.data.ticket.status).toBe(paso.estado);

      // Tabla Ticket.
      const fila = await filaTicket(id);
      expect(fila.Estado).toBe(paso.estado.toLowerCase());
      expect(fila.Prioridad).toBe('media'); // la prioridad no cambia con el estado
      expect(fila.ID_admin_revisor).toBe(paso.revisor);
      expect(fila.FechaCierre === null).toBe(!paso.cerrado);
      expect(fila.MotivoRechazo).toBeNull();

      // Tabla Notificacion: un aviso por cada cambio, para el dueño, con el estado nuevo.
      const avisos = await avisosDeEstado(id);
      expect(avisos).toHaveLength(indice + 1);
      expect(avisos.at(-1)).toMatchObject({
        EstadoTicket: paso.estado.toLowerCase(), ID_user: usuarios.colaboradorActivo.id, Leida: false,
      });

      // Lo que ve el colaborador.
      estado = (await consultarEstado(id)).body.data;
      expect(estado.status).toBe(paso.estado);
      expect(estado.resolution.type).toBe(paso.resolucion);
      expect(estado.resolution.reason).toBeNull();
      expect(estado.resolution.closedAt === null).toBe(!paso.cerrado);
    }
  });
});

// ---------- Flujo de rechazo ----------

describe('Rechazo por HTTP: En revisión → Rechazado', () => {
  test('motivo corto: 400 y nada cambia; motivo válido: queda guardado y el colaborador lo ve', async () => {
    const id = await reportar();
    await esperarPrioridad(id);
    expect((await cambiarEstado(id, 'EN_REVISION')).status).toBe(200);

    const corto = await cambiarEstado(id, 'RECHAZADO', 'No corresponde.');
    expect(corto.status).toBe(400);
    expect(await filaTicket(id)).toMatchObject({ Estado: 'en_revision', MotivoRechazo: null, FechaCierre: null });
    expect(await avisosDeEstado(id)).toHaveLength(1); // solo el de "en revisión"

    const res = await cambiarEstado(id, 'RECHAZADO', MOTIVO_RECHAZO);
    expect(res.status).toBe(200);
    const fila = await filaTicket(id);
    expect(fila).toMatchObject({ Estado: 'rechazado', MotivoRechazo: MOTIVO_RECHAZO, ID_admin_revisor: usuarios.adminActivo.id }); // queda quién lo rechazó
    expect(fila.FechaCierre).not.toBeNull();
    expect((await avisosDeEstado(id)).at(-1).EstadoTicket).toBe('rechazado');

    const estado = (await consultarEstado(id)).body.data;
    expect(estado.resolution).toEqual({ type: 'rechazado', reason: MOTIVO_RECHAZO, closedAt: fila.FechaCierre.toISOString() });

    // Un rechazado ya terminó: no se puede aprobar después.
    expect((await cambiarEstado(id, 'APROBADO')).status).toBe(409);
    expect((await filaTicket(id)).Estado).toBe('rechazado');
  });
});

// ---------- Duplicados ----------

describe('GET /api/tickets/:id/estado informa si el ticket fue marcado como duplicado', () => {
  test('duplicado de otro colaborador: lo dice sin mostrar datos del otro dueño', async () => {
    // El original es de otra persona (se crea directo en la base).
    const original = await prisma.ticket.create({
      data: {
        Descripcion: 'El enchufe de la sala echa chispas', Ubicacion: 'Piso 2, Sala B', Estado: 'en_proceso',
        Prioridad: 'alta', ID_user: usuarios.adminActivo.id, ID_CateRepa: 2,
      },
    });
    const id = await reportar();
    // Igual que cuando la IA detecta el duplicado (tickets.service.js → marcarDuplicado).
    expect(await new PrismaTicketRepository(prisma).marcarDuplicado(id, original.ID_Ticket)).toBe(true);

    const res = await consultarEstado(id);
    expect(res.status).toBe(200);
    expect(res.body.data.duplicate).toEqual({
      isDuplicate: true,
      original: { id: String(original.ID_Ticket), code: expect.stringMatching(/^REP-/), status: 'EN_PROCESO', mine: false },
    });
    const texto = JSON.stringify(res.body);
    expect(texto).not.toContain(usuarios.adminActivo.email);
    expect(texto).not.toContain('Pablo');

    // Un ticket normal del mismo colaborador no es duplicado.
    const normal = await reportar({ ubicacion: 'Piso 5, Bodega' });
    expect((await consultarEstado(normal)).body.data.duplicate).toEqual({ isDuplicate: false, original: null });
  });

  test('solo el dueño colaborador: otro usuario = 404, administrador = 403', async () => {
    const id = await reportar();
    const otro = firmarToken({ id: usuarios.colaboradorNuevo.id, role: 'COLABORADOR' });
    // colaboradorNuevo no aceptó Términos: igual queda fuera (no puede ver nada).
    expect([403, 404]).toContain((await consultarEstado(id, otro)).status);
    expect((await consultarEstado(id, tokenAdmin)).status).toBe(403);
    expect((await consultarEstado('999999')).status).toBe(404);
  });
});

// ---------- Cambios que deben fallar sin tocar la base ----------

describe('Transiciones inválidas: responden error y la base queda igual', () => {
  test('saltarse pasos (Recibido → Aprobado) = 409 TRANSICION_NO_PERMITIDA', async () => {
    const id = await reportar();
    await esperarPrioridad(id);
    const res = await cambiarEstado(id, 'APROBADO');
    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('TRANSICION_NO_PERMITIDA');
    expect(await filaTicket(id)).toMatchObject({ Estado: 'recibido', ID_admin_revisor: null });
    expect(await avisosDeEstado(id)).toHaveLength(0);
  });

  test('aprobar un ticket propio = 409 APROBACION_PROPIA', async () => {
    const propio = await prisma.ticket.create({
      data: {
        Descripcion: 'Luminaria parpadea', Ubicacion: 'Piso 1', Estado: 'en_revision', Prioridad: 'media',
        ID_user: usuarios.adminActivo.id, ID_CateRepa: 2,
      },
    });
    const res = await cambiarEstado(propio.ID_Ticket, 'APROBADO');
    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('APROBACION_PROPIA');
    expect(await filaTicket(propio.ID_Ticket)).toMatchObject({ Estado: 'en_revision', ID_admin_revisor: null });
  });

  test('rechazar un ticket propio = 409 RECHAZO_PROPIO', async () => {
    const propio = await prisma.ticket.create({
      data: {
        Descripcion: 'Enchufe suelto', Ubicacion: 'Piso 2', Estado: 'en_revision', Prioridad: 'media',
        ID_user: usuarios.adminActivo.id, ID_CateRepa: 2,
      },
    });
    const res = await cambiarEstado(propio.ID_Ticket, 'RECHAZADO', MOTIVO_RECHAZO);
    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('RECHAZO_PROPIO');
    expect(await filaTicket(propio.ID_Ticket)).toMatchObject({ Estado: 'en_revision', ID_admin_revisor: null, MotivoRechazo: null });
  });

  test('gestionar un ticket sin prioridad = 409 TICKET_SIN_PRIORIDAD', async () => {
    const sinPrioridad = await prisma.ticket.create({
      data: { Descripcion: 'Puerta no cierra', Ubicacion: 'Piso 3', ID_user: usuarios.colaboradorActivo.id, ID_CateRepa: 1 },
    });
    const res = await cambiarEstado(sinPrioridad.ID_Ticket, 'EN_REVISION');
    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('TICKET_SIN_PRIORIDAD');
    expect((await filaTicket(sinPrioridad.ID_Ticket)).Estado).toBe('recibido');
  });

  test('el colaborador no puede cancelar un ticket que ya está en revisión (RF-09)', async () => {
    const id = await reportar();
    await esperarPrioridad(id);
    await cambiarEstado(id, 'EN_REVISION');
    const res = await request(app).post(`/api/tickets/${id}/cancelar`).set('Authorization', `Bearer ${tokenColaborador}`);
    expect(res.status).toBe(409);
    expect((await filaTicket(id)).Estado).toBe('en_revision');
  });
});

// ---------- Restricciones de la base ----------

describe('PostgreSQL protege la coherencia aunque alguien escriba directo en la tabla', () => {
  test('ck_ticket_operativo_prioridad y ck_ticket_prioridad rechazan datos incoherentes', async () => {
    const ticket = await prisma.ticket.create({
      data: { Descripcion: 'Aire no enfría', Ubicacion: 'Piso 4', ID_user: usuarios.colaboradorActivo.id, ID_CateRepa: 4 },
    });
    await expect(prisma.$executeRawUnsafe(
      `UPDATE "Ticket" SET "Estado" = 'en_revision' WHERE "ID_Ticket" = ${ticket.ID_Ticket}`,
    )).rejects.toThrow(/ck_ticket_operativo_prioridad/);
    await expect(prisma.$executeRawUnsafe(
      `UPDATE "Ticket" SET "Prioridad" = 'urgente' WHERE "ID_Ticket" = ${ticket.ID_Ticket}`,
    )).rejects.toThrow(/ck_ticket_prioridad/);
    expect(await filaTicket(ticket.ID_Ticket)).toMatchObject({ Estado: 'recibido', Prioridad: null });
  });
});

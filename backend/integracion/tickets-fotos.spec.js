import { afterEach, beforeEach, describe, expect, it, jest } from '@jest/globals';
import { mkdtemp, readdir, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import jwt from 'jsonwebtoken';
import request from 'supertest';
import { crearApp } from '../src/app.js';
import { AuthService } from '../src/modules/auth/auth.service.js';
import { crearRepositorioEnMemoria } from '../src/modules/auth/auth.memory.repository.js';
import { MemoryTicketRepository } from '../src/modules/tickets/tickets.memory.repository.js';
import { TicketService } from '../src/modules/tickets/tickets.service.js';

const jwtSecret = 'test-secret-with-more-than-thirty-two-characters';
const env = { jwtSecret, jwtExpiresIn: '1h', corsOrigin: '*' };
const jpg = Buffer.from([0xff, 0xd8, 0xff, 0xda, 0x00, 0x02, 0x11, 0xff, 0xd9]);
let uploadsDir;

beforeEach(async () => {
  uploadsDir = await mkdtemp(path.join(tmpdir(), 'tyckops-ticket-fotos-'));
});

afterEach(async () => {
  await rm(uploadsDir, { recursive: true, force: true });
});

async function crearContexto({ photoStorage } = {}) {
  const users = await crearRepositorioEnMemoria([
    { id: 'worker-1', name: 'Ana', email: 'ana@gamaitaly.cl', password: 'Temporal2026!', role: 'COLABORADOR', termsAccepted: true },
    { id: 'worker-2', name: 'Luis', email: 'luis@gamaitaly.cl', password: 'Temporal2026!', role: 'COLABORADOR', termsAccepted: true },
    { id: 'admin-1', name: 'Admin', email: 'admin@gamaitaly.cl', password: 'Temporal2026!', role: 'ADMINISTRADOR', termsAccepted: true },
  ]);
  const tickets = new MemoryTicketRepository([]);
  const authService = new AuthService(users, env, { log: () => {} });
  const ticketService = new TicketService(tickets, {
    uploadsDir,
    photoStorage,
    auditLogger: { info: () => {}, error: () => {} },
  });
  return { app: crearApp({ env, authService, ticketService }), tickets };
}

function authorization(id, role = 'COLABORADOR') {
  return `Bearer ${jwt.sign({ role }, jwtSecret, { subject: id })}`;
}

function reporte(app, ruta = '/api/tickets/reparaciones', userId = 'worker-1', categoria = 'mobiliario') {
  return request(app)
    .post(ruta)
    .set('Authorization', authorization(userId))
    .field('categoria', categoria)
    .field('ubicacion', 'Piso 2, recepción')
    .field('descripcion', 'Silla con una pata quebrada en recepción');
}

describe('fotos en reportes de reparación', () => {
  it('crea un ticket recibido con varias fotos JPG', async () => {
    const { app, tickets } = await crearContexto();
    const response = await reporte(app)
      .attach('fotos', jpg, { filename: 'silla-1.jpg', contentType: 'image/jpeg' })
      .attach('fotos', jpg, { filename: 'silla-2.jpg', contentType: 'image/jpeg' });

    expect(response.status).toBe(201);
    expect(response.body.data.ticket).toMatchObject({
      category: 'Inmobiliario',
      status: 'RECIBIDO',
      location: 'Piso 2, recepción',
    });
    expect(response.body.data.ticket.fotos).toHaveLength(2);
    const listado = await request(app)
      .get(`/api/tickets/${response.body.data.ticket.id}/fotos`)
      .set('Authorization', authorization('worker-1'));
    expect(listado.status).toBe(200);
    expect(listado.body.data.fotos).toEqual(response.body.data.ticket.fotos);
    expect((await readdir(uploadsDir))).toHaveLength(2);
    expect(tickets.tickets).toHaveLength(1);
  });

  it('mantiene el endpoint y campo de foto que ya usa el móvil', async () => {
    const { app } = await crearContexto();
    const response = await reporte(app, '/api/tickets', 'worker-1', 'ELECTRICA')
      .attach('foto', jpg, { filename: 'foto.jpg', contentType: 'image/jpeg' });

    expect(response.status).toBe(201);
    expect(response.body.data.ticket.fotos).toHaveLength(1);
  });

  it('rechaza una extensión de imagen con contenido no permitido sin crear ticket ni archivo', async () => {
    const { app, tickets } = await crearContexto();
    const response = await reporte(app)
      .attach('fotos', Buffer.from('no es una imagen'), { filename: 'imagen.jpg', contentType: 'image/jpeg' });

    expect(response.status).toBe(415);
    expect(response.body.error.code).toBe('FOTO_TIPO_INVALIDO');
    expect(tickets.tickets).toHaveLength(0);
    expect(await readdir(uploadsDir)).toHaveLength(0);
  });

  it('limita el reporte a tres fotos', async () => {
    const { app } = await crearContexto();
    const response = await reporte(app)
      .attach('fotos', jpg, { filename: '1.jpg', contentType: 'image/jpeg' })
      .attach('fotos', jpg, { filename: '2.jpg', contentType: 'image/jpeg' })
      .attach('fotos', jpg, { filename: '3.jpg', contentType: 'image/jpeg' })
      .attach('fotos', jpg, { filename: '4.jpg', contentType: 'image/jpeg' });

    expect(response.status).toBe(400);
    expect(response.body.error.code).toBe('FOTO_INVALIDA');
    expect(await readdir(uploadsDir)).toHaveLength(0);
  });

  it('permite descargar al dueño y administrador, pero no a otro colaborador ni sin sesión', async () => {
    const { app } = await crearContexto();
    const created = await reporte(app)
      .attach('fotos', jpg, { filename: 'silla.jpg', contentType: 'image/jpeg' });
    const fotoUrl = created.body.data.ticket.fotos[0].url;

    const owner = await request(app).get(fotoUrl).set('Authorization', authorization('worker-1'));
    expect(owner.status).toBe(200);
    expect(owner.headers['content-type']).toMatch(/image\/jpeg/);
    expect(owner.headers['cache-control']).toBe('private, no-store');

    const otherWorker = await request(app).get(fotoUrl).set('Authorization', authorization('worker-2'));
    expect(otherWorker.status).toBe(404);

    const admin = await request(app).get(fotoUrl).set('Authorization', authorization('admin-1', 'ADMINISTRADOR'));
    expect(admin.status).toBe(200);

    const anonymous = await request(app).get(fotoUrl);
    expect(anonymous.status).toBe(401);
  });

  it('borra fotos ya guardadas y el ticket si falla el guardado siguiente', async () => {
    const nombresBorrados = [];
    let guardados = 0;
    const photoStorage = {
      save: async () => {
        guardados += 1;
        if (guardados === 2) throw new Error('disco lleno');
        return 'ticket-t-1-00000000-0000-4000-8000-000000000001.jpg';
      },
      remove: async (_dir, _ticketId, nombres) => nombresBorrados.push(...nombres),
      read: async () => null,
    };
    const { app, tickets } = await crearContexto({ photoStorage });
    const consoleError = jest.spyOn(console, 'error').mockImplementation(() => {});

    try {
      const response = await reporte(app)
        .attach('fotos', jpg, { filename: '1.jpg', contentType: 'image/jpeg' })
        .attach('fotos', jpg, { filename: '2.jpg', contentType: 'image/jpeg' });

      expect(response.status).toBe(500);
      expect(nombresBorrados).toEqual(['ticket-t-1-00000000-0000-4000-8000-000000000001.jpg']);
      expect(tickets.tickets).toHaveLength(0);
    } finally {
      consoleError.mockRestore();
    }
  });
});
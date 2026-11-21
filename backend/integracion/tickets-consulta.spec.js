import request from 'supertest';
import { crearApp } from '../src/app.js';
import { AuthService } from '../src/modules/auth/auth.service.js';
import { crearRepositorioEnMemoria } from '../src/modules/auth/auth.memory.repository.js';
import { MemoryTicketRepository } from '../src/modules/tickets/tickets.memory.repository.js';
import { TicketService } from '../src/modules/tickets/tickets.service.js';
import { firmarToken, ENV_PRUEBAS } from './helpers/app.js';

describe('Consultas de Tickets (GET /tickets/mios, /resumen, /:id)', () => {
  let app;
  let tokenWorker1;
  let tokenWorker2;
  let tokenAdmin;

  beforeEach(async () => {
    const userRepo = await crearRepositorioEnMemoria([
      { id: 'w-1', name: 'Usuario 1', email: 'u1@gamaitaly.cl', password: 'Pass2026!', role: 'COLABORADOR', termsAccepted: true, isFirstLogin: false },
      { id: 'w-2', name: 'Usuario 2', email: 'u2@gamaitaly.cl', password: 'Pass2026!', role: 'COLABORADOR', termsAccepted: true, isFirstLogin: false },
      { id: 'adm', name: 'Administrador', email: 'admin@gamaitaly.cl', password: 'Pass2026!', role: 'ADMINISTRADOR', termsAccepted: true, isFirstLogin: false },
    ]);
    const authService = new AuthService(userRepo, ENV_PRUEBAS);
    const ticketRepo = new MemoryTicketRepository([
      {
        id: '1',
        code: 'REP-0001',
        category: 'Eléctrica',
        title: 'Falla eléctrica en sala',
        status: 'EN_PROCESO',
        priority: 'ALTA',
        location: 'Piso 1',
        createdAt: new Date('2026-11-18T10:00:00Z'),
        ownerId: 'w-1',
      },
      {
        id: '2',
        code: 'REP-0002',
        category: 'Baños',
        title: 'Llave goteando',
        status: 'RESUELTO',
        priority: 'MEDIA',
        location: 'Piso 2',
        createdAt: new Date('2026-11-15T10:00:00Z'),
        ownerId: 'w-1',
      },
      {
        id: '99',
        code: 'REP-0099',
        category: 'Aire acondicionado',
        title: 'Aire no enfría',
        status: 'RECIBIDO',
        priority: 'MEDIA',
        location: 'Piso 3',
        createdAt: new Date('2026-11-19T10:00:00Z'),
        ownerId: 'w-2',
      },
    ]);
    const ticketService = new TicketService(ticketRepo, { slaCumplido: 99.0 });

    app = crearApp({
      env: ENV_PRUEBAS,
      authService,
      ticketService,
    });

    tokenWorker1 = firmarToken({ id: 'w-1', role: 'COLABORADOR' });
    tokenWorker2 = firmarToken({ id: 'w-2', role: 'COLABORADOR' });
    tokenAdmin = firmarToken({ id: 'adm', role: 'ADMINISTRADOR' });
  });

  describe('GET /tickets/resumen', () => {
    test('entrega el conteo de tickets activos para el home', async () => {
      const res = await request(app)
        .get('/tickets/resumen')
        .set('Authorization', `Bearer ${tokenWorker1}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.total).toBe(2);
      expect(res.body.data.activos).toBe(1); // Solo EN_PROCESO está activo; RESUELTO no
      expect(res.body.data.enAtencion).toBe(1);
      expect(res.body.data.slaCumplido).toBe(99.0);
    });
  });

  describe('GET /tickets/mios', () => {
    test('entrega la lista del usuario y su estado', async () => {
      const res = await request(app)
        .get('/tickets/mios')
        .set('Authorization', `Bearer ${tokenWorker1}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.tickets.length).toBe(2);
      expect(res.body.data.tickets[0].id).toBe('1');
      expect(res.body.data.tickets[0].status).toBe('EN_PROCESO');
      expect(res.body.data.tickets[1].id).toBe('2');
      expect(res.body.data.tickets[1].status).toBe('RESUELTO');
    });
  });

  describe('GET /tickets/:id con permisos (dueño o administrador)', () => {
    test('el colaborador dueño puede ver el detalle de su ticket', async () => {
      const res = await request(app)
        .get('/tickets/1')
        .set('Authorization', `Bearer ${tokenWorker1}`);

      expect(res.status).toBe(200);
      expect(res.body.data.ticket.id).toBe('1');
      expect(res.body.data.ticket.title).toBe('Falla eléctrica en sala');
    });

    test('un colaborador ajeno no puede ver el ticket (404)', async () => {
      const res = await request(app)
        .get('/tickets/1')
        .set('Authorization', `Bearer ${tokenWorker2}`);

      expect(res.status).toBe(404);
      expect(res.body.error.code).toBe('TICKET_NO_ENCONTRADO');
    });

    test('un administrador puede ver el detalle de cualquier ticket', async () => {
      const res = await request(app)
        .get('/tickets/1')
        .set('Authorization', `Bearer ${tokenAdmin}`);

      expect(res.status).toBe(200);
      expect(res.body.data.ticket.id).toBe('1');
      expect(res.body.data.ticket.code).toBe('REP-0001');

      const res2 = await request(app)
        .get('/tickets/99')
        .set('Authorization', `Bearer ${tokenAdmin}`);

      expect(res2.status).toBe(200);
      expect(res2.body.data.ticket.id).toBe('99');
      expect(res2.body.data.ticket.title).toBe('Aire no enfría');
    });
  });
});

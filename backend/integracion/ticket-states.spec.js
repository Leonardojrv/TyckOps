import { MemoryTicketRepository } from '../src/modules/tickets/tickets.memory.repository.js';
import { TicketService } from '../src/modules/tickets/tickets.service.js';

function prepararTicket(status = 'RECIBIDO') {
  const repo = new MemoryTicketRepository([{
    id: '1',
    ownerId: 'worker-1',
    code: 'REP-0001',
    category: 'Eléctrica',
    title: 'Equipo sin energía',
    status,
    priority: 'BAJA',
    location: 'Piso 2',
    createdAt: new Date('2026-11-25T10:00:00Z'),
  }]);
  return { repo, service: new TicketService(repo, { auditLogger: { info: () => {} } }) };
}

describe('flujo de estados e historial', () => {
  test('registra actor y motivo, exige motivo al rechazar y rechaza transiciones inválidas', async () => {
    const { repo, service } = prepararTicket('EN_REVISION');
    const motivo = 'La reparación requiere un proveedor externo autorizado por el fabricante del equipo y su coordinación con la administración del edificio.';

    await expect(service.cambiarEstado('admin-1', '1', 'RECHAZADO', 'breve'))
      .rejects.toMatchObject({ status: 400, code: 'MOTIVO_RECHAZO_INVALIDO' });
    await expect(service.cambiarEstado('admin-1', '1', 'CERRADO'))
      .rejects.toMatchObject({ status: 409, code: 'TRANSICION_NO_PERMITIDA' });

    await service.cambiarEstado('admin-1', '1', 'RECHAZADO', motivo);
    expect(repo.historialEstados).toHaveLength(1);
    expect(repo.historialEstados[0]).toMatchObject({
      estadoAnterior: 'EN_REVISION',
      estadoNuevo: 'RECHAZADO',
      actorId: 'admin-1',
      motivo,
    });
    expect(repo.historialEstados[0].fecha).toBeInstanceOf(Date);
  });

  test.each([
    ['cerrar', 'CERRADO', /Cierre por autogestión/],
    ['escalar', 'RECIBIDO', /reportado a Servicios Generales/],
  ])('autogestión puede %s con salida %s e historial', async (accion, destino, textoMotivo) => {
    const { repo, service } = prepararTicket();
    await service.iniciarAutogestion('worker-1', '1');
    const ticket = await service.resolverGuia('worker-1', '1', accion);

    expect(ticket.status).toBe(destino);
    expect(repo.historialEstados.map(({ estadoAnterior, estadoNuevo }) => [estadoAnterior, estadoNuevo]))
      .toEqual([['RECIBIDO', 'AUTOGESTION'], ['AUTOGESTION', destino]]);
    expect(repo.historialEstados[1].actorId).toBe('worker-1');
    expect(repo.historialEstados[1].motivo).toMatch(textoMotivo);
    if (accion === 'cerrar') expect(ticket.closedAt).toBeTruthy();
  });
});

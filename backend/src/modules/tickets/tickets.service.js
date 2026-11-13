import { HttpError } from '../../utils/http-error.js';

// Estados en los que el ticket sigue "en atención" (RF-05).
const ESTADOS_ACTIVOS = new Set(['RECIBIDO', 'EN_REVISION', 'APROBADO', 'EN_PROCESO']);

// Solo lo que la app necesita mostrar: nunca el ownerId ni datos internos.
function publicTicket(ticket) {
  return {
    id: ticket.id,
    code: ticket.code,
    category: ticket.category,
    title: ticket.title,
    status: ticket.status,
    priority: ticket.priority,
    location: ticket.location,
    createdAt: new Date(ticket.createdAt).toISOString(),
  };
}

export class TicketService {
  // slaCumplido: % de tickets atendidos a tiempo. Lo calculará el backend
  // real; mientras tanto viene de la configuración de la demo (o null).
  constructor(ticketRepository, { slaCumplido = null } = {}) {
    this.ticketRepository = ticketRepository;
    this.slaCumplido = slaCumplido;
  }

  async misTickets(userId) {
    const tickets = (await this.ticketRepository.findByOwner(userId))
      .sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
    return {
      tickets: tickets.map(publicTicket),
      resumen: {
        total: tickets.length,
        enAtencion: tickets.filter((ticket) => ESTADOS_ACTIVOS.has(ticket.status)).length,
        slaCumplido: this.slaCumplido,
      },
    };
  }

  async detalle(userId, id) {
    // IDs con formato raro ni siquiera se buscan.
    const ticket = /^[A-Za-z0-9-]{1,40}$/.test(String(id))
      ? await this.ticketRepository.findByIdForOwner(id, userId)
      : null;
    // Ajeno o inexistente: mismo 404, para no revelar qué IDs existen.
    if (!ticket) throw new HttpError(404, 'TICKET_NO_ENCONTRADO', 'No encontramos esa solicitud.');
    return publicTicket(ticket);
  }
}

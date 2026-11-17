import { HttpError } from '../../utils/http-error.js';
import { guardarFoto, quitarMetadatos } from './tickets.fotos.js';

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
    priority: ticket.priority ?? null,
    location: ticket.location,
    createdAt: new Date(ticket.createdAt).toISOString(),
  };
}

export class TicketService {
  // slaCumplido: % de tickets atendidos a tiempo. Lo calculará el backend
  // real; mientras tanto viene de la configuración de la demo (o null).
  // uploadsDir: carpeta donde se guardan las fotos (fuera de lo que se publica).
  constructor(ticketRepository, { slaCumplido = null, uploadsDir = null, auditLogger = console } = {}) {
    this.ticketRepository = ticketRepository;
    this.slaCumplido = slaCumplido;
    this.uploadsDir = uploadsDir;
    this.auditLogger = auditLogger;
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

  // RF-04: crea el ticket en estado Recibido y, si viene, guarda su foto en disco.
  // La foto es opcional (foto = null).
  async crearReporte(userId, { categoria, ubicacion, descripcion }, foto = null) {
    if (foto && !this.uploadsDir) {
      throw new HttpError(503, 'FOTOS_NO_DISPONIBLES', 'El servidor aún no puede recibir fotografías.');
    }
    const limpia = foto ? quitarMetadatos(foto.buffer, foto.tipo) : null;
    if (foto && !limpia) {
      throw new HttpError(415, 'FOTO_DANADA', 'No pudimos leer la foto. Toma otra e inténtalo de nuevo.');
    }

    const ticket = await this.ticketRepository.create({
      ownerId: userId,
      category: categoria,
      location: ubicacion,
      description: descripcion,
    });
    if (limpia) {
      try {
        await guardarFoto(this.uploadsDir, ticket.id, limpia, foto.tipo);
      } catch (error) {
        // Si la foto que mandó no se pudo guardar, se deshace el ticket para no dejarlo a medias.
        await this.ticketRepository.delete(ticket.id);
        throw error;
      }
    }
    this.auditLogger.info?.(JSON.stringify({
      type: 'ticket',
      action: 'ticket_created',
      timestamp: new Date().toISOString(),
      ticketId: ticket.id,
      userId: String(userId),
      category: categoria,
      withPhoto: Boolean(limpia),
    }));
    return publicTicket(ticket);
  }
}

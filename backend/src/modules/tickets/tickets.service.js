import { HttpError } from '../../utils/http-error.js';
import { borrarFotos, guardarFoto, leerFoto, listarFotos, quitarMetadatos } from './tickets.fotos.js';

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
  constructor(ticketRepository, {
    slaCumplido = null,
    uploadsDir = null,
    auditLogger = console,
    photoStorage = {},
  } = {}) {
    this.ticketRepository = ticketRepository;
    this.slaCumplido = slaCumplido;
    this.uploadsDir = uploadsDir;
    this.auditLogger = auditLogger;
    this.photoStorage = {
      save: photoStorage.save ?? guardarFoto,
      remove: photoStorage.remove ?? borrarFotos,
      read: photoStorage.read ?? leerFoto,
      list: photoStorage.list ?? listarFotos,
    };
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

  // RF-04: crea el ticket en estado Recibido y guarda sus fotos localmente.
  async crearReporte(userId, { categoria, ubicacion, descripcion }, fotos = []) {
    const archivos = Array.isArray(fotos) ? fotos : (fotos ? [fotos] : []);
    if (archivos.length > 0 && !this.uploadsDir) {
      throw new HttpError(503, 'FOTOS_NO_DISPONIBLES', 'El servidor aún no puede recibir fotografías.');
    }
    const fotosLimpias = archivos.map((foto) => {
      const buffer = quitarMetadatos(foto.buffer, foto.tipo);
      if (!buffer) throw new HttpError(415, 'FOTO_DANADA', 'No pudimos leer una foto. Toma otra e inténtalo de nuevo.');
      return { buffer, tipo: foto.tipo };
    });

    const ticket = await this.ticketRepository.create({
      ownerId: userId,
      category: categoria,
      location: ubicacion,
      description: descripcion,
    });

    const nombresFotos = [];
    try {
      for (const foto of fotosLimpias) {
        nombresFotos.push(await this.photoStorage.save(this.uploadsDir, ticket.id, foto.buffer, foto.tipo));
      }
    } catch (error) {
      const [fotosEliminadas, ticketEliminado] = await Promise.allSettled([
        this.photoStorage.remove(this.uploadsDir, ticket.id, nombresFotos),
        this.ticketRepository.delete(ticket.id),
      ]);
      if (fotosEliminadas.status === 'rejected' || ticketEliminado.status === 'rejected') {
        this.auditLogger.error?.(JSON.stringify({
          type: 'ticket',
          action: 'ticket_photo_rollback_failed',
          timestamp: new Date().toISOString(),
          ticketId: String(ticket.id),
        }));
      }
      throw error;
    }

    this.auditLogger.info?.(JSON.stringify({
      type: 'ticket',
      action: 'ticket_created',
      timestamp: new Date().toISOString(),
      ticketId: ticket.id,
      userId: String(userId),
      category: categoria,
      photoCount: nombresFotos.length,
    }));
    return {
      ...publicTicket(ticket),
      fotos: nombresFotos.map((nombre, index) => ({
        nombre,
        mime: fotosLimpias[index].tipo.mime,
        url: `/api/tickets/${encodeURIComponent(ticket.id)}/fotos/${encodeURIComponent(nombre)}`,
      })),
    };
  }

  async _ticketConAccesoFotos(ticketId, usuario) {
    const ticket = await this.ticketRepository.findById(ticketId);
    const esAdmin = usuario.role === 'ADMINISTRADOR';
    if (!ticket || (!esAdmin && String(ticket.ownerId) !== String(usuario.id))) {
      throw new HttpError(404, 'TICKET_NO_ENCONTRADO', 'No encontramos esa solicitud.');
    }
    return ticket;
  }

  async fotosDeTicket(ticketId, usuario) {
    const ticket = await this._ticketConAccesoFotos(ticketId, usuario);
    const nombres = await this.photoStorage.list(this.uploadsDir, ticket.id);
    return nombres.map((nombre) => ({
      nombre,
      url: `/api/tickets/${encodeURIComponent(ticket.id)}/fotos/${encodeURIComponent(nombre)}`,
      mime: nombre.endsWith('.png') ? 'image/png' : 'image/jpeg',
    }));
  }

  async fotoDeTicket(ticketId, usuario, nombre) {
    const ticket = await this._ticketConAccesoFotos(ticketId, usuario);
    const foto = await this.photoStorage.read(this.uploadsDir, ticket.id, nombre);
    if (!foto) throw new HttpError(404, 'FOTO_NO_ENCONTRADA', 'No encontramos esa fotografía.');
    return foto;
  }
}

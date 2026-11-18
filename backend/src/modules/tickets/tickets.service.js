// ¿PARA QUÉ SIRVE?
//   Es el "cerebro" de los tickets: aquí están las reglas, no las rutas ni la base.
//
// ¿QUÉ HACE?
//   Arma la lista y el resumen del home, el detalle (con comentarios y motivo de
//   rechazo), entrega la foto solo a su dueño y crea los reportes nuevos.
//
// ¿CÓMO LO CAMBIO?
//   Si cambia una regla (por ejemplo, qué estados cuentan como "en atención"),
//   cámbiala aquí y corre `pnpm test`. Lo que se guarda o se lee de la base va en
//   los repositorios.

import { HttpError } from '../../utils/http-error.js';
import { detectarTipoImagen, quitarMetadatos } from './tickets.fotos.js';

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
  constructor(ticketRepository, { slaCumplido = null, auditLogger = console } = {}) {
    this.ticketRepository = ticketRepository;
    this.slaCumplido = slaCumplido;
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

  // Detalle de un ticket para su dueño (pantalla "Detalle del ticket", T7).
  // Junta lo que la pantalla necesita: los datos básicos, la descripción, si
  // tiene foto, el motivo de rechazo y los comentarios del administrador.
  // Si quieres mostrar un dato nuevo en el detalle, súmalo aquí y en el repositorio.
  async detalle(userId, id) {
    // IDs con formato raro ni siquiera se buscan.
    const ticket = /^[A-Za-z0-9-]{1,40}$/.test(String(id))
      ? await this.ticketRepository.findDetailForOwner(id, userId)
      : null;
    // Ajeno o inexistente responden igual (404): así nadie puede adivinar qué tickets existen.
    if (!ticket) throw new HttpError(404, 'TICKET_NO_ENCONTRADO', 'No encontramos esa solicitud.');

    return {
      ...publicTicket(ticket),
      description: ticket.description ?? ticket.title,
      hasPhoto: Boolean(ticket.hasPhoto),
      // El motivo solo viaja si el ticket está rechazado (RF-07), aunque la base tenga algo escrito.
      rejectionReason: ticket.status === 'RECHAZADO' ? ticket.rejectionReason ?? null : null,
      closedAt: ticket.closedAt ? new Date(ticket.closedAt).toISOString() : null,
      // La consulta ya filtró por este ticket: nunca se mezclan comentarios de otro.
      comments: (ticket.comments ?? []).map((comentario) => ({
        id: String(comentario.id),
        author: comentario.author,
        createdAt: new Date(comentario.createdAt).toISOString(),
        text: comentario.text,
      })),
    };
  }

  // Foto de un ticket propio (columna imagen). Devuelve los bytes y su tipo.
  async foto(userId, id) {
    const resultado = /^[A-Za-z0-9-]{1,40}$/.test(String(id))
      ? await this.ticketRepository.findPhotoForOwner(id, userId)
      : null;
    // Ajeno o inexistente: mismo 404 que el detalle, para no revelar qué IDs existen.
    if (!resultado) throw new HttpError(404, 'TICKET_NO_ENCONTRADO', 'No encontramos esa solicitud.');
    if (!resultado.imagen) throw new HttpError(404, 'FOTO_NO_ENCONTRADA', 'Esta solicitud no tiene fotografía.');

    // El tipo se vuelve a leer de los bytes guardados (ya validados al recibirlos).
    const tipo = detectarTipoImagen(resultado.imagen);
    if (!tipo) throw new HttpError(500, 'FOTO_DANADA', 'No pudimos leer la fotografía guardada.');
    return { buffer: resultado.imagen, mime: tipo.mime };
  }

  // RF-04: crea el ticket en estado Recibido. Si viene foto, se guarda sin
  // metadatos en la columna imagen (BYTEA) del mismo ticket, en una sola
  // operación: no puede quedar un ticket sin su foto ni una foto sin ticket.
  // La foto es opcional (foto = null).
  async crearReporte(userId, { categoria, ubicacion, descripcion }, foto = null) {
    const limpia = foto ? quitarMetadatos(foto.buffer, foto.tipo) : null;
    if (foto && !limpia) {
      throw new HttpError(415, 'FOTO_DANADA', 'No pudimos leer la foto. Toma otra e inténtalo de nuevo.');
    }

    const ticket = await this.ticketRepository.create({
      ownerId: userId,
      category: categoria,
      location: ubicacion,
      description: descripcion,
      imagen: limpia,
    });
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

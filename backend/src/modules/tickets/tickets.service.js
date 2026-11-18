import { HttpError } from '../../utils/http-error.js';
import { detectarTipoImagen, quitarMetadatos } from './tickets.fotos.js';
import { datosParaIA, evaluarFlujoIA } from './tickets.flujoIA.js';

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
  // analizadorIA: motor de IA opcional (módulo de IA). Debe exponer
  // `async analizar({ ticketId, categoria, descripcion, ubicacion })`.
  // Si es null, los tickets Recibidos quedan registrados como pendientes.
  constructor(ticketRepository, { slaCumplido = null, auditLogger = console, analizadorIA = null } = {}) {
    this.ticketRepository = ticketRepository;
    this.slaCumplido = slaCumplido;
    this.auditLogger = auditLogger;
    this.analizadorIA = analizadorIA;
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

    // Sin await: Groq puede tardar hasta GROQ_TIMEOUT_MS y el trabajador no
    // debe esperar ni ver un error si la IA falla; su ticket ya está creado.
    // enrutarTicket nunca lanza, así que no queda una promesa rechazada suelta.
    this.enrutarTicket({ ...ticket, description: descripcion });
    return publicTicket(ticket);
  }

  // Decide el flujo del ticket según su estado (ver tickets.flujoIA.js):
  //  - omitido_ia:   no está en Recibido, no se envía.
  //  - pendiente_ia: está en Recibido pero no hay motor de IA conectado.
  //  - enviado_ia:   se envió al motor y respondió.
  //  - error_ia:     se envió pero el motor falló; el ticket sigue en Recibido.
  // Solo lee el estado: no lo cambia ni guarda el resultado del análisis.
  // TODO (guardar análisis): antes de escribir el resultado, volver a revisar
  // que el ticket siga en Recibido; el trabajador puede cancelarlo (RF-09)
  // mientras la IA lo analiza.
  async enrutarTicket(ticket) {
    try {
      const decision = evaluarFlujoIA(ticket);

      if (!decision.enviar) {
        this.#auditarIA(ticket, 'omitido_ia', { motivo: decision.motivo });
        return { resultado: 'omitido_ia', motivo: decision.motivo };
      }

      if (!this.analizadorIA) {
        this.#auditarIA(ticket, 'pendiente_ia');
        return { resultado: 'pendiente_ia' };
      }

      const analisis = await this.analizadorIA.analizar(datosParaIA(ticket));
      this.#auditarIA(ticket, 'enviado_ia');
      return { resultado: 'enviado_ia', analisis };
    } catch (error) {
      const codigo = error?.code ?? 'DESCONOCIDO';
      this.#auditarIA(ticket, 'error_ia', { codigo });
      return { resultado: 'error_ia', codigo };
    }
  }

  #auditarIA(ticket, action, extra = {}) {
    try {
      this.auditLogger.info?.(JSON.stringify({
        type: 'ticket',
        action,
        timestamp: new Date().toISOString(),
        ticketId: ticket?.id ?? null,
        ...extra,
      }));
    } catch {
      // Un fallo del logger no debe afectar el flujo del ticket.
    }
  }
}

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

import { logger } from '../../config/logger.js';
import { HttpError } from '../../utils/http-error.js';
import { detectarTipoImagen, quitarMetadatos } from './tickets.fotos.js';
import { datosParaIA, evaluarFlujoIA } from './tickets.flujoIA.js';

// Logger por defecto: recibe la misma línea JSON que antes iba a console.info
// y la escribe en logs/ con winston. Las pruebas pueden pasar el suyo.
const auditoriaTickets = {
  info(linea) {
    // timestamp y type se descartan: winston pone su propia hora y el tipo va en `tipo`.
    const { action, timestamp: _t, type: _tipo, ...datos } = typeof linea === 'string' ? JSON.parse(linea) : linea;
    const nivel = action === 'error_ia' ? 'warn' : 'info';
    logger[nivel](action, { tipo: 'ticket', ...datos });
  },
};

// Estados en los que el ticket sigue "en atención" (RF-05).
const ESTADOS_ACTIVOS = new Set(['RECIBIDO', 'EN_REVISION', 'APROBADO', 'EN_PROCESO']);

// MM2: en estos estados el ticket ya terminó y su prioridad no se cambia.
const ESTADOS_SIN_CAMBIO_PRIORIDAD = new Set(['RESUELTO', 'CERRADO', 'RECHAZADO', 'CANCELADO']);

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
  constructor(ticketRepository, { slaCumplido = null, auditLogger = auditoriaTickets, analizadorIA = null } = {}) {
    this.ticketRepository = ticketRepository;
    this.slaCumplido = slaCumplido;
    this.auditLogger = auditLogger;
    this.analizadorIA = analizadorIA;
  }

  async resumen(userId) {
    const tickets = await this.ticketRepository.findByOwner(userId);
    const activos = tickets.filter((ticket) => ESTADOS_ACTIVOS.has(ticket.status));
    return {
      total: tickets.length,
      activos: activos.length,
      enAtencion: activos.length,
      slaCumplido: this.slaCumplido,
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

  // Detalle de un ticket (solo para el dueño o un administrador).
  // Junta lo que la pantalla necesita: los datos básicos, la descripción, si
  // tiene foto, el motivo de rechazo y los comentarios del administrador.
  async detalle(usuarioOId, id) {
    const esAdmin = typeof usuarioOId === 'object' && usuarioOId?.role === 'ADMINISTRADOR';
    const userId = typeof usuarioOId === 'object' ? usuarioOId?.id : usuarioOId;

    // IDs con formato raro ni siquiera se buscan.
    if (!/^[A-Za-z0-9-]{1,40}$/.test(String(id))) {
      throw new HttpError(404, 'TICKET_NO_ENCONTRADO', 'No encontramos esa solicitud.');
    }

    const ticket = esAdmin
      ? (this.ticketRepository.findDetail
          ? await this.ticketRepository.findDetail(id)
          : await this.ticketRepository.findDetailForOwner(id, userId))
      : await this.ticketRepository.findDetailForOwner(id, userId);

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

  // Foto de un ticket (columna imagen). Solo el dueño o un administrador pueden verla.
  async foto(usuarioOId, id) {
    const esAdmin = typeof usuarioOId === 'object' && usuarioOId?.role === 'ADMINISTRADOR';
    const userId = typeof usuarioOId === 'object' ? usuarioOId?.id : usuarioOId;

    if (!/^[A-Za-z0-9-]{1,40}$/.test(String(id))) {
      throw new HttpError(404, 'TICKET_NO_ENCONTRADO', 'No encontramos esa solicitud.');
    }

    const resultado = esAdmin
      ? (this.ticketRepository.findPhoto
          ? await this.ticketRepository.findPhoto(id)
          : await this.ticketRepository.findPhotoForOwner(id, userId))
      : await this.ticketRepository.findPhotoForOwner(id, userId);

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
  //  - enviado_ia:   se envió al motor y respondió; se guarda la prioridad
  //                  inicial (MM2) si el ticket sigue en Recibido.
  //  - error_ia:     se envió pero el motor falló; el ticket sigue en Recibido.
  // No cambia el estado. La prioridad se guarda con una condición en la misma
  // escritura (sigue en Recibido y sin prioridad), porque el trabajador puede
  // cancelarlo (RF-09) mientras la IA lo analiza.
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

      const guardada = analisis?.prioridad && this.ticketRepository.guardarPrioridadInicial
        ? await this.ticketRepository.guardarPrioridadInicial(ticket.id, analisis)
        : false;
      // Sin descripción en el log: solo el resultado y de dónde salió.
      this.#auditarIA(ticket, guardada ? 'prioridad_asignada' : 'prioridad_descartada', {
        prioridad: analisis?.prioridad ?? null,
        origen: analisis?.origen ?? null,
        reglaId: analisis?.reglaId ?? null,
        versionReglas: analisis?.versionReglas ?? null,
        ...(analisis?.guiaId && { guiaId: analisis.guiaId }),
        ...(analisis?.riesgo && { riesgo: analisis.riesgo }),
        ...(analisis?.errorIA && { errorIA: analisis.errorIA }),
        ...(!guardada && { motivo: 'ticket_ya_no_recibido_o_con_prioridad' }),
      });
      return { resultado: 'enviado_ia', analisis, prioridadGuardada: guardada };
    } catch (error) {
      const codigo = error?.code ?? 'DESCONOCIDO';
      this.#auditarIA(ticket, 'error_ia', { codigo });
      return { resultado: 'error_ia', codigo };
    }
  }

  // MM2 · El administrador cambia la prioridad (por ejemplo, escala una baja).
  // Queda registrado quién y cuándo, para medir cuántas veces corrige a la IA.
  async cambiarPrioridad(adminId, id, prioridad) {
    const resultado = /^[A-Za-z0-9-]{1,40}$/.test(String(id))
      ? await this.ticketRepository.cambiarPrioridad(id, { prioridad, adminId, estadosBloqueados: ESTADOS_SIN_CAMBIO_PRIORIDAD })
      : null;
    if (!resultado) throw new HttpError(404, 'TICKET_NO_ENCONTRADO', 'No encontramos esa solicitud.');
    if (resultado.bloqueado) {
      throw new HttpError(409, 'PRIORIDAD_NO_MODIFICABLE', 'Este ticket ya terminó: su prioridad no se puede cambiar.');
    }
    if (resultado.cambiado) {
      this.#auditarIA(resultado.ticket, 'prioridad_cambiada', {
        adminId: String(adminId),
        prioridad,
        prioridadInicial: resultado.ticket.initialPriority,
        origen: resultado.ticket.priorityOrigin,
      });
    }
    return { ...resultado.ticket, changed: resultado.cambiado };
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

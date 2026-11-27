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
import { SOLUCION_AUTOAYUDA, admiteAutoayuda, elegirGuia } from './tickets.guia.js';
import { TRANSICIONES_TICKET, validarTransicion } from './ticket-states.js';

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
const ESTADOS_ACTIVOS = new Set(['RECIBIDO', 'EN_REVISION', 'APROBADO', 'EN_PROCESO', 'AUTOGESTION']);
const ESTADOS_RESUELTOS = new Set(['RESUELTO', 'CERRADO']);

// MM2: en estos estados el ticket ya terminó y su prioridad no se cambia.
const ESTADOS_SIN_CAMBIO_PRIORIDAD = new Set(['RESUELTO', 'CERRADO', 'RECHAZADO', 'CANCELADO']);

// T10 · Resumen del ticket original de un duplicado: sin dueño, foto ni comentarios.
// `mine` solo dice si el original también es tuyo (para cambiar el mensaje).
function publicOriginal(original, userId) {
  return {
    mine: String(original.ownerId) === String(userId),
    id: String(original.id),
    code: original.code,
    category: original.category,
    title: original.title,
    status: original.status,
    location: original.location,
    createdAt: new Date(original.createdAt).toISOString(),
  };
}

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
    // T9: el historial filtra y muestra "Finalizado: ..." con esta fecha.
    closedAt: ticket.closedAt ? new Date(ticket.closedAt).toISOString() : null,
  };
}

function textoNormalizado(texto) {
  return String(texto ?? '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase();
}

function fechaHistorial(ticket) {
  return !ESTADOS_ACTIVOS.has(ticket.status) && ticket.closedAt
    ? new Date(ticket.closedAt)
    : new Date(ticket.createdAt);
}

function coincideEstadoHistorial(ticket, estado) {
  switch (estado) {
    case 'finished':
      return !ESTADOS_ACTIVOS.has(ticket.status);
    case 'active':
      return ESTADOS_ACTIVOS.has(ticket.status);
    case 'resolved':
      return ESTADOS_RESUELTOS.has(ticket.status);
    case 'rejected':
      return ticket.status === 'RECHAZADO';
    case 'cancelled':
      return ticket.status === 'CANCELADO';
    default:
      return true;
  }
}

function dentroDelRango(fecha, rango, ahora) {
  if (rango === 'all') return true;
  if (rango === 'year') return fecha.getFullYear() === ahora.getFullYear();
  const dias = { '7d': 7, '30d': 30, '90d': 90 }[rango];
  const inicio = new Date(ahora.getFullYear(), ahora.getMonth(), ahora.getDate() - dias + 1);
  return fecha >= inicio;
}

export class TicketService {
  // slaCumplido: % de tickets atendidos a tiempo. Lo calculará el backend
  // real; mientras tanto viene de la configuración de la demo (o null).
  // analizadorIA: motor de IA opcional (módulo de IA). Debe exponer
  // `async analizar({ ticketId, categoria, descripcion, ubicacion })`.
  // Si es null, los tickets Recibidos quedan registrados como pendientes.
  // obtenerGuiasVigentes (T10): función que devuelve las guías que cargó el
  // administrador. Si no hay, la guía del colaborador es la simulada.
  constructor(ticketRepository, {
    slaCumplido = null,
    auditLogger = auditoriaTickets,
    analizadorIA = null,
    obtenerGuiasVigentes = async () => [],
    notificaciones = null, // T11: avisa al dueño (push + historial)
  } = {}) {
    this.ticketRepository = ticketRepository;
    this.slaCumplido = slaCumplido;
    this.auditLogger = auditLogger;
    this.analizadorIA = analizadorIA;
    this.obtenerGuiasVigentes = obtenerGuiasVigentes;
    this.notificaciones = notificaciones;
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

  async misTicketsPaginados(userId, { estados = [], pagina = 1, limite = 20 } = {}) {
    const resultado = await this.ticketRepository.findByOwnerPage(userId, {
      estados,
      skip: (pagina - 1) * limite,
      take: limite,
    });
    return {
      tickets: resultado.tickets.map(publicTicket),
      resumen: {
        total: resultado.totalOwner,
        enAtencion: resultado.activos,
        slaCumplido: this.slaCumplido,
      },
      paginacion: {
        pagina,
        limite,
        total: resultado.total,
        paginas: Math.ceil(resultado.total / limite),
      },
    };
  }

  async historial(userId, { q = '', rango = 'all', estado = 'all', categoria = '' } = {}) {
    const tickets = await this.ticketRepository.findByOwner(userId);
    const ahora = new Date();
    const palabras = textoNormalizado(q.replaceAll('#', ' ')).split(/\s+/).filter(Boolean);
    const categoriaNormalizada = textoNormalizado(categoria);

    const filtrados = tickets.filter((ticket) => {
      if (!coincideEstadoHistorial(ticket, estado)) return false;
      if (!dentroDelRango(fechaHistorial(ticket), rango, ahora)) return false;
      if (categoriaNormalizada && textoNormalizado(ticket.category) !== categoriaNormalizada) return false;

      const texto = textoNormalizado([
        ticket.code,
        ticket.id,
        ticket.title,
        ticket.location,
        ticket.category,
        ticket.status,
        ticket.createdAt?.toISOString?.() ?? ticket.createdAt,
        ticket.closedAt?.toISOString?.() ?? ticket.closedAt,
      ].join(' '));
      return palabras.every((palabra) => texto.includes(palabra));
    }).sort((a, b) => fechaHistorial(b) - fechaHistorial(a));

    return {
      tickets: filtrados.map(publicTicket),
      total: filtrados.length,
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

    const timeline = [
      { status: 'RECIBIDO', previousStatus: null, date: ticket.createdAt },
      ...(ticket.timeline ?? []),
    ];
    const estadoActual = String(ticket.status).toUpperCase();
    if (timeline.at(-1)?.status !== estadoActual) {
      timeline.push({
        status: estadoActual,
        previousStatus: timeline.at(-1)?.status ?? null,
        date: ticket.closedAt ?? null,
      });
    }

    return {
      ...publicTicket(ticket),
      description: ticket.description ?? ticket.title,
      hasPhoto: Boolean(ticket.hasPhoto),
      // El motivo solo viaja si el ticket está rechazado (RF-07), aunque la base tenga algo escrito.
      rejectionReason: ticket.status === 'RECHAZADO' ? ticket.rejectionReason ?? null : null,
      closedAt: ticket.closedAt ? new Date(ticket.closedAt).toISOString() : null,
      timeline: timeline.map((evento, index) => ({
        status: String(evento.status).toUpperCase(),
        previousStatus: evento.previousStatus ? String(evento.previousStatus).toUpperCase() : null,
        date: evento.date ? new Date(evento.date).toISOString() : null,
        current: index === timeline.length - 1,
      })),
      // T10: ¿mostrar la guía de autoayuda? (prioridad Baja, Recibido y sin decisión previa)
      selfHelp: admiteAutoayuda(ticket),
      // T10: lo cerró el propio colaborador con la guía (su línea de tiempo es más corta).
      closedBySelfHelp: ticket.solutionType === SOLUCION_AUTOAYUDA,
      // T10: si es un duplicado, el resumen del original (sin datos de su dueño).
      duplicateOf: ticket.original ? publicOriginal(ticket.original, ticket.ownerId) : null,
      // La consulta ya filtró por este ticket: nunca se mezclan comentarios de otro.
      comments: (ticket.comments ?? []).map((comentario) => ({
        id: String(comentario.id),
        author: comentario.author,
        createdAt: new Date(comentario.createdAt).toISOString(),
        text: comentario.text,
      })),
    };
  }

  // T9 · RF-09: el colaborador cancela su ticket, solo mientras está Recibido.
  // El dueño sale de la sesión; el estado se revisa en la misma escritura
  // (ver cancelarSiRecibido), así que el botón oculto en la app no es la única barrera.
  async cancelar(userId, id) {
    if (!/^[A-Za-z0-9-]{1,40}$/.test(String(id))) {
      throw new HttpError(404, 'TICKET_NO_ENCONTRADO', 'No encontramos esa solicitud.');
    }
    validarTransicion('RECIBIDO', 'CANCELADO');
    const resultado = await this.ticketRepository.cancelarSiRecibido(id, userId);
    // Ajeno o inexistente: el mismo 404 de siempre, para no revelar qué IDs existen.
    if (!resultado) throw new HttpError(404, 'TICKET_NO_ENCONTRADO', 'No encontramos esa solicitud.');
    if (!resultado.cancelado) {
      throw new HttpError(
        409,
        'TICKET_NO_CANCELABLE',
        'Solo se puede cancelar un ticket en estado Recibido',
      );
    }
    this.auditLogger.info?.(JSON.stringify({
      type: 'ticket',
      action: 'ticket_cancelado',
      timestamp: new Date().toISOString(),
      ticketId: resultado.ticket.id,
      userId: String(userId),
    }));
    return publicTicket(resultado.ticket);
  }

  // T10 · RF-10: la guía paso a paso de un ticket de prioridad Baja (solo el dueño).
  async guia(userId, id) {
    const ticket = await this.#ticketPropio(userId, id);
    if (ticket.status !== 'AUTOGESTION' || !admiteAutoayuda(ticket)) {
      throw new HttpError(404, 'GUIA_NO_DISPONIBLE', 'Esta solicitud no tiene una guía de autoayuda disponible.');
    }
    let vigentes = [];
    try {
      vigentes = (await this.obtenerGuiasVigentes()) ?? [];
    } catch {
      vigentes = []; // si falla la lectura de guías, se usa la simulada
    }
    return elegirGuia(ticket, vigentes);
  }

  async iniciarAutogestion(userId, id) {
    const ticket = await this.#ticketPropio(userId, id);
    if (!admiteAutoayuda(ticket) || !['RECIBIDO', 'AUTOGESTION'].includes(ticket.status)) {
      throw new HttpError(409, 'AUTOGESTION_NO_DISPONIBLE', 'Esta solicitud no puede iniciar la guía de autoayuda.');
    }
    if (ticket.status === 'AUTOGESTION') return publicTicket(ticket);
    validarTransicion(ticket.status, 'AUTOGESTION');
    const resultado = await this.ticketRepository.iniciarAutogestion(id, userId);
    if (!resultado?.cambiado && resultado?.ticket.status !== 'AUTOGESTION') {
      throw new HttpError(409, 'TICKET_CAMBIO_SIMULTANEO', 'El ticket cambió mientras iniciabas la guía. Vuelve a cargarlo.');
    }
    this.auditLogger.info?.(JSON.stringify({
      type: 'ticket',
      action: 'autogestion_iniciada',
      timestamp: new Date().toISOString(),
      ticketId: resultado.ticket.id,
      userId: String(userId),
    }));
    return publicTicket(resultado.ticket);
  }

  // T10 · RF-11 / RF-12: "Cerrar ticket" (la guía funcionó) o "Reportar a
  // administración" (no funcionó). Solo el dueño y solo mientras la guía aplica.
  async resolverGuia(userId, id, accion) {
    if (accion !== 'cerrar' && accion !== 'escalar') {
      throw new HttpError(400, 'DATOS_INVALIDOS', 'Acción no válida.');
    }
    if (!/^[A-Za-z0-9-]{1,40}$/.test(String(id))) {
      throw new HttpError(404, 'TICKET_NO_ENCONTRADO', 'No encontramos esa solicitud.');
    }
    const destino = accion === 'cerrar' ? 'CERRADO' : 'RECIBIDO';
    validarTransicion('AUTOGESTION', destino);
    const resultado = await this.ticketRepository.resolverConGuia(id, userId, accion);
    if (!resultado) throw new HttpError(404, 'TICKET_NO_ENCONTRADO', 'No encontramos esa solicitud.');
    if (!resultado.aplicado) {
      throw new HttpError(
        409,
        'GUIA_NO_APLICABLE',
        'Esta solicitud ya fue tomada por Servicios Generales o ya registraste una decisión.',
      );
    }
    this.auditLogger.info?.(JSON.stringify({
      type: 'ticket',
      action: accion === 'cerrar' ? 'ticket_cerrado_autoayuda' : 'ticket_escalado_colaborador',
      timestamp: new Date().toISOString(),
      ticketId: resultado.ticket.id,
      userId: String(userId),
    }));
    return publicTicket(resultado.ticket);
  }

  // Busca un ticket del dueño (mismo 404 para ajeno o inexistente).
  async #ticketPropio(userId, id) {
    if (!/^[A-Za-z0-9-]{1,40}$/.test(String(id))) {
      throw new HttpError(404, 'TICKET_NO_ENCONTRADO', 'No encontramos esa solicitud.');
    }
    const ticket = await this.ticketRepository.findByIdForOwner(id, userId);
    if (!ticket) throw new HttpError(404, 'TICKET_NO_ENCONTRADO', 'No encontramos esa solicitud.');
    return ticket;
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

      // T10: si la IA detectó que es un duplicado, se guarda el original
      // (solo si sigue Recibido; nunca se cambia el estado).
      if (analisis?.duplicado?.esDuplicado && analisis.duplicado.ticketOriginalId && this.ticketRepository.marcarDuplicado) {
        const agrupado = await this.ticketRepository.marcarDuplicado(ticket.id, analisis.duplicado.ticketOriginalId);
        this.#auditarIA(ticket, agrupado ? 'duplicado_detectado' : 'duplicado_descartado', {
          ticketOriginalId: String(analisis.duplicado.ticketOriginalId),
          confianza: analisis.duplicado.confianza ?? null,
        });
      }

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

  // T11 · El administrador cambia el estado; el dueño recibe el aviso.
  async cambiarEstado(adminId, id, estado, motivo = null) {
    const actual = /^[A-Za-z0-9-]{1,40}$/.test(String(id)) ? await this.ticketRepository.findById(id) : null;
    if (!actual) throw new HttpError(404, 'TICKET_NO_ENCONTRADO', 'No encontramos esa solicitud.');
    const desde = String(actual.status).toUpperCase();
    const motivoCambio = motivo?.trim() || null;
    validarTransicion(desde, estado, motivoCambio);
    const resultado = await this.ticketRepository.cambiarEstado(id, {
      desde,
      hacia: estado,
      motivo: motivoCambio,
      actorId: adminId,
    });
    if (!resultado?.cambiado) {
      throw new HttpError(409, 'TICKET_CAMBIO_SIMULTANEO', 'El ticket cambió mientras lo editabas. Vuelve a cargarlo.');
    }
    this.auditLogger.info?.(JSON.stringify({
      type: 'ticket', action: 'estado_cambiado', timestamp: new Date().toISOString(),
      ticketId: resultado.ticket.id, adminId: String(adminId), desde, hacia: estado,
    }));
    await this.notificaciones?.avisarCambioEstado(resultado.ticket, estado, motivoCambio);
    return publicTicket(resultado.ticket);
  }

  // T11 · El administrador comenta; el dueño recibe "Nuevo comentario en tu ticket".
  async comentar(adminId, id, texto) {
    const ticket = /^[A-Za-z0-9-]{1,40}$/.test(String(id)) ? await this.ticketRepository.findById(id) : null;
    if (!ticket) throw new HttpError(404, 'TICKET_NO_ENCONTRADO', 'No encontramos esa solicitud.');
    const comentario = await this.ticketRepository.crearComentario(id, { adminId, texto });
    this.auditLogger.info?.(JSON.stringify({
      type: 'ticket', action: 'comentario_admin', timestamp: new Date().toISOString(),
      ticketId: ticket.id, adminId: String(adminId), comentarioId: comentario.id,
    }));
    await this.notificaciones?.avisarComentario(ticket, comentario);
    return {
      id: comentario.id,
      text: comentario.text,
      createdAt: new Date(comentario.createdAt).toISOString(),
    };
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
        prioridadAnterior: resultado.prioridadAnterior ?? null,
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

// ¿PARA QUÉ SIRVE?
//   Guarda tickets "de mentira" en memoria, para probar sin base de datos.
//
// ¿QUÉ HACE?
//   Imita lo que hace PostgreSQL (siempre filtrando por dueño) y trae datos de
//   demostración con un rechazo y comentarios.
//
// ¿CÓMO LO CAMBIO?
//   Si agregas una consulta en el repositorio de PostgreSQL, agrégala también aquí
//   para que las pruebas y el modo demo sigan funcionando.

// Tickets en memoria mientras no exista la tabla en PostgreSQL (T6/T7).
// Las consultas SIEMPRE filtran por dueño: no existe "traer todos".
export class MemoryTicketRepository {
  constructor(tickets = []) {
    this.tickets = tickets.map((ticket) => ({
      ...ticket,
      id: String(ticket.id),
      ownerId: String(ticket.ownerId),
    }));
    this.cambiosPrioridad = []; // igual que la tabla CambioPrioridad
  }

  // MM2 · Igual que en PostgreSQL: solo si sigue en Recibido y sin prioridad.
  async guardarPrioridadInicial(id, { prioridad, origen, reglaId = null, nivelIncidencia = null }) {
    const ticket = this.tickets.find((t) => t.id === String(id));
    if (!ticket || ticket.status !== 'RECIBIDO' || ticket.priority) return false;
    Object.assign(ticket, {
      priority: prioridad,
      initialPriority: prioridad,
      priorityOrigin: origen,
      ruleId: reglaId,
      nivelIncidencia,
    });
    return true;
  }

  // MM2 · Cambio de prioridad del administrador + registro (quién y cuándo).
  async cambiarPrioridad(id, { prioridad, adminId, estadosBloqueados }) {
    const ticket = this.tickets.find((t) => t.id === String(id));
    if (!ticket) return null;
    const vista = () => ({
      id: ticket.id,
      status: ticket.status,
      priority: ticket.priority ?? null,
      initialPriority: ticket.initialPriority ?? null,
      priorityOrigin: ticket.priorityOrigin ?? null,
      ruleId: ticket.ruleId ?? null,
    });
    if (estadosBloqueados.has(ticket.status)) return { ticket: vista(), cambiado: false, bloqueado: true };
    if (ticket.priority === prioridad) return { ticket: vista(), cambiado: false, bloqueado: false };

    this.cambiosPrioridad.push({
      ticketId: ticket.id,
      adminId: String(adminId),
      anterior: ticket.priority ?? null,
      nueva: prioridad,
      fecha: new Date(),
    });
    const prioridadAnterior = ticket.priority ?? null;
    ticket.priority = prioridad;
    return { ticket: vista(), cambiado: true, bloqueado: false, prioridadAnterior };
  }

  // T11 · Igual que en PostgreSQL: solo si sigue en el estado `desde`.
  async cambiarEstado(id, { desde, hacia, motivo = null, revisorId = null }) {
    const ticket = this.tickets.find((t) => t.id === String(id));
    if (!ticket) return null;
    if (ticket.status !== desde) return { ticket, cambiado: false };
    ticket.status = hacia;
    if (hacia === 'RECHAZADO') ticket.rejectionReason = motivo;
    if (['APROBADO', 'RECHAZADO'].includes(hacia) && revisorId) ticket.reviewedBy = String(revisorId);
    if (['RECHAZADO', 'RESUELTO', 'CERRADO'].includes(hacia)) ticket.closedAt = new Date();
    return { ticket, cambiado: true };
  }

  async findById(id) {
    return this.tickets.find((t) => t.id === String(id)) ?? null;
  }

  // T11 · El comentario queda en el ticket (lo muestra el detalle).
  async crearComentario(id, { adminId, texto }) {
    const ticket = this.tickets.find((t) => t.id === String(id));
    if (!ticket) return null;
    ticket.comments ??= [];
    const comentario = {
      id: String(Date.now()) + String(ticket.comments.length),
      author: 'Servicios Generales',
      authorId: String(adminId),
      createdAt: new Date(),
      text: texto,
    };
    ticket.comments.push(comentario);
    return { id: comentario.id, text: texto, createdAt: comentario.createdAt };
  }

  async findByOwner(ownerId) {
    return this.tickets.filter((ticket) => ticket.ownerId === String(ownerId));
  }

  async findActiveCandidates({ category = null, location = null, excludeId = null } = {}) {
    const estadosActivos = new Set(['RECIBIDO', 'EN_REVISION', 'APROBADO', 'EN_PROCESO']);
    const locNorm = location?.toLowerCase().trim();
    const catNorm = category?.toLowerCase().trim();

    return this.tickets.filter((t) => {
      if (excludeId !== null && String(t.id) === String(excludeId)) return false;
      if (!estadosActivos.has(String(t.status).toUpperCase())) return false;

      const c = String(t.category ?? '').toLowerCase().trim();
      const l = String(t.location ?? '').toLowerCase().trim();

      const coincideUbic = locNorm && (l.includes(locNorm) || locNorm.includes(l));
      const coincideCat = catNorm && c === catNorm;
      return coincideUbic || coincideCat;
    });
  }

  async findByIdForOwner(id, ownerId) {
    return this.tickets.find(
      (ticket) => ticket.id === String(id) && ticket.ownerId === String(ownerId),
    ) ?? null;
  }

  // T9 · Igual que en PostgreSQL: solo el dueño, y solo si sigue en Recibido.
  async cancelarSiRecibido(id, ownerId) {
    const ticket = await this.findByIdForOwner(id, ownerId);
    if (!ticket) return null;
    if (ticket.status !== 'RECIBIDO') return { cancelado: false, ticket };
    ticket.status = 'CANCELADO';
    ticket.closedAt = new Date();
    return { cancelado: true, ticket };
  }

  // T10 · Igual que en PostgreSQL: tuyo, Recibido, prioridad Baja y sin decisión previa.
  async resolverConGuia(id, ownerId, accion) {
    const ticket = await this.findByIdForOwner(id, ownerId);
    if (!ticket) return null;
    const aplica = ticket.status === 'RECIBIDO' && String(ticket.priority).toUpperCase() === 'BAJA' && !ticket.solutionType;
    if (!aplica) return { aplicado: false, ticket };
    if (accion === 'cerrar') {
      Object.assign(ticket, { status: 'CERRADO', closedAt: new Date(), solutionType: 'autoayuda_ia' });
    } else {
      Object.assign(ticket, { priority: 'MEDIA', solutionType: 'escalado_colaborador' });
    }
    return { aplicado: true, ticket };
  }

  // T10 · Igual que en PostgreSQL: solo si sigue Recibido y no está agrupado.
  async marcarDuplicado(id, originalId) {
    const ticket = this.tickets.find((t) => t.id === String(id));
    const original = this.tickets.find((t) => t.id === String(originalId));
    if (!ticket || !original || ticket === original || ticket.status !== 'RECIBIDO' || ticket.originalId) return false;
    ticket.originalId = original.id;
    return true;
  }

  // Versión en memoria del detalle (misma forma que en PostgreSQL). Sirve para
  // probar la app sin base de datos y para las pruebas automáticas.
  async findDetail(id, { ownerId = null } = {}) {
    const ticket = this.tickets.find((item) => item.id === String(id)
      && (ownerId === null || item.ownerId === String(ownerId)));
    if (!ticket) return null;
    return {
      ...ticket,
      description: ticket.description ?? ticket.title,
      hasPhoto: Boolean(ticket.imagen),
      original: resumenOriginal(this.tickets.find((t) => t.id === ticket.originalId)),
      comments: [...(ticket.comments ?? [])].sort((a, b) => new Date(a.createdAt) - new Date(b.createdAt)),
    };
  }

  async findDetailForOwner(id, ownerId) {
    return this.findDetail(id, { ownerId });
  }

  async findPhoto(id, { ownerId = null } = {}) {
    const ticket = this.tickets.find((item) => item.id === String(id)
      && (ownerId === null || item.ownerId === String(ownerId)));
    return ticket ? { imagen: ticket.imagen ?? null } : null;
  }

  // Igual que en PostgreSQL: null si no es suyo o no existe; { imagen: null } si no tiene foto.
  async findPhotoForOwner(id, ownerId) {
    return this.findPhoto(id, { ownerId });
  }

  async create({ ownerId, category, location, description, imagen = null }) {
    const numeros = this.tickets.map((t) => Number(String(t.code).replace(/\D/g, '')) || 0);
    const siguiente = Math.max(0, ...numeros) + 1;
    const ticket = {
      id: `t-${siguiente}`,
      code: `REP-${String(siguiente).padStart(4, '0')}`,
      category: CATEGORIA_VISIBLE[category] ?? category,
      title: description,
      status: 'RECIBIDO', // RF-04: todo reporte nuevo parte en Recibido
      priority: null, // la asigna la IA o el administrador
      location,
      createdAt: new Date(),
      ownerId: String(ownerId),
      imagen, // igual que la columna BYTEA de PostgreSQL
    };
    this.tickets.push(ticket);
    return ticket;
  }
}

// T10 · Lo único que se muestra del ticket original (nada de su dueño).
function resumenOriginal(t) {
  if (!t) return null;
  const { id, code, category, title, status, location, createdAt, ownerId } = t;
  return { id, code, category, title: t.description ?? title, status, location, createdAt, ownerId };
}

const CATEGORIA_VISIBLE = {
  ELECTRICA: 'Eléctrica',
  BANOS: 'Baños',
  AIRE_ACONDICIONADO: 'Aire acondicionado',
  INMOBILIARIO: 'Inmobiliario',
};

// Fecha relativa a hoy, para que la demo siempre muestre "Hoy" y "Ayer".
function haceDias(dias, hora, minuto) {
  const fecha = new Date();
  fecha.setDate(fecha.getDate() - dias);
  fecha.setHours(hora, minuto, 0, 0);
  return fecha;
}

// Datos de demostración del colaborador de prueba (mockup home_inicio).
export function ticketsDeDemostracion(ownerId) {
  return [
    // T10: uno de prioridad Baja (muestra la guía) y uno duplicado del REP-0087.
    ['t-0150', 'REP-0150', 'Electricidad', 'Falla en tomacorriente de puesto de trabajo', 'RECIBIDO', 'BAJA', 'Piso 2, Puesto 204', haceDias(0, 8, 50)],
    ['t-0149', 'REP-0149', 'Baños', 'Agua en el piso del baño del piso 2', 'RECIBIDO', null, 'Sector Poniente', haceDias(0, 9, 10)],
    ['t-0142', 'REP-0142', 'Electricidad', 'Enchufe en mal estado', 'EN_PROCESO', 'ALTA', 'Recepción central', haceDias(0, 10, 30)],
    ['t-0087', 'REP-0087', 'Infraestructura', 'Fuga agua en baño piso 2', 'EN_REVISION', 'MEDIA', 'Sector Poniente', haceDias(1, 16, 45)],
    ['t-0139', 'REP-0139', 'Inmobiliario', 'Escritorio en malas condiciones', 'APROBADO', 'BAJA', 'Piso 4', haceDias(6, 9, 15)],
    ['t-0121', 'REP-0121', 'Aire acondicionado', 'Aire acondicionado no enfría', 'RESUELTO', 'MEDIA', 'Sala de reuniones 3', haceDias(9, 11, 5)],
    ['t-0110', 'REP-0110', 'Baños', 'Dispensador de jabón roto', 'CERRADO', 'BAJA', 'Baño piso 1', haceDias(14, 8, 40)],
    ['t-0098', 'REP-0098', 'Electricidad', 'Luz parpadeante en pasillo', 'RECHAZADO', 'BAJA', 'Pasillo piso 3', haceDias(18, 15, 20)],
    ['t-0091', 'REP-0091', 'Inmobiliario', 'Silla con rueda suelta', 'CANCELADO', 'BAJA', 'Piso 4', haceDias(22, 10, 0)],
    ['t-0075', 'REP-0075', 'Baños', 'Llave de lavamanos gotea', 'CERRADO', 'MEDIA', 'Baño piso 2', haceDias(30, 14, 10)],
  ].map(([id, code, category, title, status, priority, location, createdAt]) => ({
    id, code, category, title, status, priority, location, createdAt, ownerId,
    ...EXTRAS_DEMO[id],
  }));
}

// Detalles extra de la demo para ver en el detalle: un rechazo con su motivo
// y comentarios del administrador (el último aparecerá como "NUEVO").
const EXTRAS_DEMO = {
  't-0149': { originalId: 't-0087' },
  't-0142': {
    comments: [
      { id: 1, author: 'Servicios Generales', createdAt: haceDias(0, 11, 5), text: 'Revisamos el enchufe: hay daño por sobrecarga. Ya coordinamos el cambio de placa.' },
      { id: 2, author: 'Servicios Generales', createdAt: haceDias(0, 12, 10), text: 'El técnico va en camino con los repuestos. Por favor no uses ese enchufe mientras tanto.' },
    ],
  },
  't-0098': {
    rejectionReason: 'La luminaria es responsabilidad de la administración del edificio. Ya les avisamos para que la cambien.',
    closedAt: haceDias(17, 9, 20),
  },
};

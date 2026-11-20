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
  }

  async findByOwner(ownerId) {
    return this.tickets.filter((ticket) => ticket.ownerId === String(ownerId));
  }

  async findByIdForOwner(id, ownerId) {
    return this.tickets.find(
      (ticket) => ticket.id === String(id) && ticket.ownerId === String(ownerId),
    ) ?? null;
  }

  // Detalle de un ticket. Si se indica ownerId filtra por dueño; si no (ej. administrador),
  // devuelve el ticket sin importar quién lo creó.
  async findDetail(id, { ownerId = null } = {}) {
    const ticket = this.tickets.find((t) => {
      if (t.id !== String(id)) return false;
      if (ownerId !== null && t.ownerId !== String(ownerId)) return false;
      return true;
    });
    if (!ticket) return null;
    return {
      ...ticket,
      description: ticket.description ?? ticket.title,
      hasPhoto: Boolean(ticket.imagen),
      comments: [...(ticket.comments ?? [])].sort((a, b) => new Date(a.createdAt) - new Date(b.createdAt)),
    };
  }

  // Versión en memoria del detalle (misma forma que en PostgreSQL). Sirve para
  // probar la app sin base de datos y para las pruebas automáticas.
  async findDetailForOwner(id, ownerId) {
    return this.findDetail(id, { ownerId });
  }

  async findPhoto(id, { ownerId = null } = {}) {
    const ticket = this.tickets.find((t) => {
      if (t.id !== String(id)) return false;
      if (ownerId !== null && t.ownerId !== String(ownerId)) return false;
      return true;
    });
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

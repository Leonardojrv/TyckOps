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
}

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
  }));
}

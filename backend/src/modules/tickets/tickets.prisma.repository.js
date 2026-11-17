import { HttpError } from '../../utils/http-error.js';

// Nombres aceptados en la tabla CategoriaReparacion para cada código de la app.
// (El seed guarda "Electrica" sin tilde e "Inmoviliario" con v: se aceptan ambos.)
const NOMBRES_BD = {
  ELECTRICA: ['Electrica', 'Eléctrica'],
  BANOS: ['Baños', 'Banos'],
  AIRE_ACONDICIONADO: ['Aire acondicionado'],
  INMOBILIARIO: ['Inmobiliario', 'Inmoviliario', 'Mobiliario'],
};

// Nombre bonito para mostrar en la app.
const NOMBRE_VISIBLE = {
  electrica: 'Eléctrica',
  inmoviliario: 'Inmobiliario',
  banos: 'Baños',
};

function nombreVisible(nombre = '') {
  return NOMBRE_VISIBLE[nombre.toLowerCase()] ?? nombre;
}

// "recibido" / "en revisión" -> "RECIBIDO" / "EN_REVISION" (formato de la API).
function codigoApi(valor) {
  if (!valor) return null;
  return valor
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .trim()
    .replace(/\s+/g, '_')
    .toUpperCase();
}

// El id llega como string desde el JWT o la URL; en la BD es entero.
function idNumerico(id) {
  const numero = Number(id);
  return Number.isSafeInteger(numero) && numero > 0 ? numero : null;
}

function aTicket(fila) {
  return {
    id: String(fila.ID_Ticket),
    code: `REP-${String(fila.ID_Ticket).padStart(4, '0')}`,
    category: nombreVisible(fila.categoriaReparacion?.nombre),
    title: fila.Descripcion,
    status: codigoApi(fila.Estado),
    priority: codigoApi(fila.Prioridad),
    location: [fila.Ubicacion, fila.Piso].filter(Boolean).join(' · '),
    createdAt: fila.FechaCreacion,
    ownerId: String(fila.ID_user),
  };
}

const incluir = { categoriaReparacion: true };

/** Tickets en PostgreSQL. Igual que el de memoria: todo se filtra por dueño. */
export class PrismaTicketRepository {
  constructor(prisma) {
    if (!prisma.ticket?.findMany) throw new Error('El cliente Prisma no tiene el modelo Ticket esperado.');
    this.prisma = prisma;
  }

  async findByOwner(ownerId) {
    const dueno = idNumerico(ownerId);
    if (dueno === null) return [];
    const filas = await this.prisma.ticket.findMany({
      where: { ID_user: dueno },
      include: incluir,
      orderBy: { FechaCreacion: 'desc' },
    });
    return filas.map(aTicket);
  }

  async findByIdForOwner(id, ownerId) {
    const ticketId = idNumerico(id);
    const dueno = idNumerico(ownerId);
    if (ticketId === null || dueno === null) return null;
    const fila = await this.prisma.ticket.findFirst({
      where: { ID_Ticket: ticketId, ID_user: dueno },
      include: incluir,
    });
    return fila ? aTicket(fila) : null;
  }

  async create({ ownerId, category, location, description }) {
    const dueno = idNumerico(ownerId);
    if (dueno === null) throw new HttpError(401, 'SESION_INVALIDA', 'La sesión ya no es válida. Inicia sesión nuevamente.');

    const categoria = await this.prisma.categoriaReparacion.findFirst({
      where: { OR: (NOMBRES_BD[category] ?? []).map((nombre) => ({ nombre: { equals: nombre, mode: 'insensitive' } })) },
    });
    if (!categoria) {
      throw new HttpError(503, 'CATEGORIA_NO_CONFIGURADA', 'La categoría aún no está disponible. Avisa a Servicios Generales.');
    }

    const fila = await this.prisma.ticket.create({
      data: {
        Descripcion: description,
        Ubicacion: location,
        Estado: 'recibido', // RF-04: todo reporte nuevo parte en Recibido
        ID_user: dueno,
        ID_CateRepa: categoria.ID_CateRepa,
      },
      include: incluir,
    });
    return aTicket(fila);
  }

  // Solo se usa para deshacer un reporte si la foto no se pudo guardar.
  async delete(id) {
    const ticketId = idNumerico(id);
    if (ticketId !== null) await this.prisma.ticket.delete({ where: { ID_Ticket: ticketId } });
  }
}

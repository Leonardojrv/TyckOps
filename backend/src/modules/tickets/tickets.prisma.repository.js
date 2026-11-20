// ¿PARA QUÉ SIRVE?
//   Es quien lee y guarda los tickets en la base de datos real (PostgreSQL).
//
// ¿QUÉ HACE?
//   Traduce entre la base (ID_Ticket, Estado...) y lo que entiende la app (id,
//   status...). TODAS las consultas filtran por el dueño en la misma búsqueda.
//
// ¿CÓMO LO CAMBIO?
//   Si la base cambia un nombre de columna, ajústalo aquí. Si agregas un dato al
//   detalle, súmalo en findDetailForOwner sin quitar el filtro por dueño.

import { HttpError } from '../../utils/http-error.js';

// Nombres aceptados en la tabla CategoriaReparacion para cada código de la app.
// (La BD guarda "Electrica" sin tilde. "Inmoviliario" era un error de tipeo ya corregido
// por migración; se sigue aceptando por si alguna base aún no la aplica.)
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
// La foto (columna imagen, BYTEA) puede pesar varios MB: no se lee al listar
// ni al ver un ticket, solo cuando alguien pida la imagen explícitamente.
const sinImagen = { imagen: true };

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
      omit: sinImagen,
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
      omit: sinImagen,
    });
    return fila ? aTicket(fila) : null;
  }

  async create({ ownerId, category, location, description, imagen = null }) {
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
        imagen, // foto ya validada y sin metadatos (BYTEA), o null si no se adjuntó
      },
      include: incluir,
      omit: sinImagen,
    });
    return aTicket(fila);
  }

  /**
   * Detalle de un ticket (T7). Si se pasa ownerId filtra por dueño (colaborador);
   * si ownerId es null, permite al administrador consultar cualquier ticket.
   */
  async findDetail(id, { ownerId = null } = {}) {
    const ticketId = idNumerico(id);
    if (ticketId === null) return null;
    const dueno = ownerId !== null ? idNumerico(ownerId) : null;
    if (ownerId !== null && dueno === null) return null;

    const where = { ID_Ticket: ticketId };
    if (dueno !== null) {
      where.ID_user = dueno;
    }

    const fila = await this.prisma.ticket.findFirst({
      where,
      include: {
        ...incluir,
        comentarios: {
          orderBy: { FechaCreacion: 'asc' },
          select: {
            ID_Comentario: true,
            Texto: true,
            FechaCreacion: true,
            autor: { select: { name: true, appat: true } },
          },
        },
      },
      omit: sinImagen,
    });
    if (!fila) return null;

    const conFoto = await this.prisma.ticket.count({
      where: { ID_Ticket: ticketId, imagen: { not: null } },
    });

    return {
      ...aTicket(fila),
      description: fila.Descripcion,
      rejectionReason: fila.MotivoRechazo,
      closedAt: fila.FechaCierre,
      hasPhoto: conFoto > 0,
      comments: fila.comentarios.map((c) => ({
        id: c.ID_Comentario,
        author: [c.autor?.name, c.autor?.appat].filter(Boolean).join(' ') || 'Servicios Generales',
        createdAt: c.FechaCreacion,
        text: c.Texto,
      })),
    };
  }

  async findDetailForOwner(id, ownerId) {
    return this.findDetail(id, { ownerId });
  }

  /**
   * Foto de un ticket. Con ownerId para el colaborador, o sin él para el administrador.
   */
  async findPhoto(id, { ownerId = null } = {}) {
    const ticketId = idNumerico(id);
    if (ticketId === null) return null;
    const dueno = ownerId !== null ? idNumerico(ownerId) : null;
    if (ownerId !== null && dueno === null) return null;

    const where = { ID_Ticket: ticketId };
    if (dueno !== null) {
      where.ID_user = dueno;
    }

    const fila = await this.prisma.ticket.findFirst({
      where,
      select: { imagen: true },
    });
    if (!fila) return null;
    return { imagen: fila.imagen ? Buffer.from(fila.imagen) : null };
  }

  async findPhotoForOwner(id, ownerId) {
    return this.findPhoto(id, { ownerId });
  }
}

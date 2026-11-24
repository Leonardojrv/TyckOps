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
    location: fila.Ubicacion,
    createdAt: fila.FechaCreacion,
    closedAt: fila.FechaCierre ?? null, // cuándo terminó (resuelto, rechazado, cancelado...)
    ownerId: String(fila.ID_user),
  };
}

// Datos de prioridad de un ticket (MM2), en formato de la API.
function aPrioridad(fila) {
  return {
    id: String(fila.ID_Ticket),
    status: codigoApi(fila.Estado),
    priority: codigoApi(fila.Prioridad),
    initialPriority: codigoApi(fila.PrioridadInicial),
    priorityOrigin: fila.OrigenPrioridad ?? null,
    ruleId: fila.ID_ReglaAplicada ?? null,
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

  async findActiveCandidates({ category = null, location = null, excludeId = null } = {}) {
    const estadosActivos = ['recibido', 'en_revision', 'en revision', 'aprobado', 'en_proceso', 'en proceso'];
    const idExcluir = idNumerico(excludeId);
    const where = {
      Estado: { in: estadosActivos, mode: 'insensitive' },
      ...(idExcluir && { ID_Ticket: { not: idExcluir } }),
    };

    const OR = [];
    if (location) {
      OR.push({ Ubicacion: { contains: location.trim(), mode: 'insensitive' } });
    }
    if (category) {
      OR.push({ categoriaReparacion: { nombre: { contains: category.trim(), mode: 'insensitive' } } });
    }
    if (OR.length > 0) where.OR = OR;

    const filas = await this.prisma.ticket.findMany({
      where,
      include: incluir,
      omit: sinImagen,
      take: 10,
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
   * T9 · El colaborador cancela SU ticket, y solo si sigue en Recibido (RF-09).
   *
   * La condición (dueño + estado Recibido) va DENTRO de la misma escritura: si
   * el administrador lo pasó a "En revisión" un instante antes, la escritura no
   * cambia nada. Así no hay carrera entre leer el estado y guardarlo.
   *
   * @returns {Promise<null | { cancelado: boolean, ticket }>}
   *   null si no existe o no es suyo; cancelado=false si ya no estaba en Recibido.
   */
  async cancelarSiRecibido(id, ownerId) {
    const ticketId = idNumerico(id);
    const dueno = idNumerico(ownerId);
    if (ticketId === null || dueno === null) return null;

    const { count } = await this.prisma.ticket.updateMany({
      where: { ID_Ticket: ticketId, ID_user: dueno, Estado: { equals: 'recibido', mode: 'insensitive' } },
      data: { Estado: 'cancelado', FechaCierre: new Date() },
    });
    const ticket = await this.findByIdForOwner(ticketId, dueno);
    return ticket ? { cancelado: count > 0, ticket } : null;
  }

  /**
   * Todo lo que necesita la pantalla de detalle (T7) de un ticket del dueño:
   * los datos de siempre, la descripción completa, el motivo de rechazo, la
   * fecha de cierre, si tiene foto y los comentarios del administrador.
   *
   * Ojo con dos cosas si la modificas:
   * - El filtro por dueño (ID_user) va en la MISMA consulta: así es imposible
   *   que alguien vea el detalle o los comentarios de un ticket ajeno.
   * - La foto no se trae aquí (puede pesar MB); solo preguntamos si existe.
   */
  async findDetailForOwner(id, ownerId) {
    const ticketId = idNumerico(id);
    const dueno = idNumerico(ownerId);
    if (ticketId === null || dueno === null) return null;

    const fila = await this.prisma.ticket.findFirst({
      where: { ID_Ticket: ticketId, ID_user: dueno },
      include: {
        ...incluir,
        // Solo los comentarios de este ticket, del más antiguo al más nuevo.
        comentarios: {
          orderBy: { FechaCreacion: 'asc' },
          select: {
            ID_Comentario: true,
            Texto: true,
            FechaCreacion: true,
            // Del autor solo sale el nombre: nada de correo ni datos internos.
            autor: { select: { name: true, appat: true } },
          },
        },
      },
      omit: sinImagen,
    });
    if (!fila) return null;

    // ¿Tiene foto? Lo preguntamos sin descargar los bytes de la imagen.
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

  /**
   * MM2 · Guarda la prioridad inicial que calculó la IA/reglas.
   * Solo escribe si el ticket SIGUE en Recibido y aún no tiene prioridad: así
   * no pisa un ticket que el colaborador canceló mientras la IA lo analizaba
   * (RF-09) ni una prioridad que el administrador ya cambió a mano.
   * @returns {Promise<boolean>} true si se guardó.
   */
  async guardarPrioridadInicial(id, { prioridad, origen, reglaId = null, versionReglas = null, nivelIncidencia = null }) {
    const ticketId = idNumerico(id);
    if (ticketId === null) return false;
    const valor = prioridad.toLowerCase(); // "alta" en la BD, igual que Estado
    const { count } = await this.prisma.ticket.updateMany({
      where: {
        ID_Ticket: ticketId,
        Estado: { equals: 'recibido', mode: 'insensitive' },
        Prioridad: null,
      },
      data: {
        Prioridad: valor,
        PrioridadInicial: valor,
        OrigenPrioridad: origen,
        ID_ReglaAplicada: reglaId,
        ID_VersionReglas: versionReglas,
        NivelIncidencia: nivelIncidencia,
      },
    });
    return count > 0;
  }

  /**
   * MM2 · El administrador cambia la prioridad. En UNA transacción: lee el
   * ticket, lo actualiza y deja el registro en CambioPrioridad (quién y cuándo).
   * @returns {Promise<null | { ticket, cambiado: boolean, bloqueado: boolean }>}
   */
  async cambiarPrioridad(id, { prioridad, adminId, estadosBloqueados }) {
    const ticketId = idNumerico(id);
    const admin = idNumerico(adminId);
    if (ticketId === null || admin === null) return null;

    return this.prisma.$transaction(async (tx) => {
      const fila = await tx.ticket.findUnique({
        where: { ID_Ticket: ticketId },
        select: { ID_Ticket: true, Estado: true, Prioridad: true, PrioridadInicial: true, OrigenPrioridad: true, ID_ReglaAplicada: true },
      });
      if (!fila) return null;

      const ticket = aPrioridad(fila);
      if (estadosBloqueados.has(ticket.status)) return { ticket, cambiado: false, bloqueado: true };
      if (ticket.priority === prioridad) return { ticket, cambiado: false, bloqueado: false };

      await tx.ticket.update({ where: { ID_Ticket: ticketId }, data: { Prioridad: prioridad.toLowerCase() } });
      await tx.cambioPrioridad.create({
        data: {
          ID_Ticket: ticketId,
          ID_admin: admin,
          PrioridadAnterior: fila.Prioridad,
          PrioridadNueva: prioridad.toLowerCase(),
        },
      });
      return { ticket: { ...ticket, priority: prioridad }, cambiado: true, bloqueado: false };
    });
  }

  /**
   * Foto de un ticket del dueño. Solo lee la columna imagen (BYTEA).
   * Devuelve null si el ticket no existe o es de otra persona, y
   * { imagen: null } si el ticket existe pero no tiene foto.
   */
  async findPhotoForOwner(id, ownerId) {
    const ticketId = idNumerico(id);
    const dueno = idNumerico(ownerId);
    if (ticketId === null || dueno === null) return null;
    const fila = await this.prisma.ticket.findFirst({
      where: { ID_Ticket: ticketId, ID_user: dueno },
      select: { imagen: true },
    });
    if (!fila) return null;
    return { imagen: fila.imagen ? Buffer.from(fila.imagen) : null };
  }
}

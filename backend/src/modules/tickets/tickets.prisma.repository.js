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
    solutionType: fila.TipoSolucion ?? null, // T10: autoayuda_ia / escalado_colaborador (uso interno)
    originalId: fila.ID_TicketOriginal ? String(fila.ID_TicketOriginal) : null, // T10: si es duplicado (uso interno)
    ownerId: String(fila.ID_user),
  };
}

async function registrarEstado(tx, { ticketId, desde, hacia, actorId, motivo = null }) {
  const actor = idNumerico(actorId);
  if (actor === null) throw new Error('El actor del cambio de estado no es válido.');
  await tx.historialEstadoTicket.create({
    data: {
      ID_Ticket: ticketId,
      EstadoAnterior: desde.toLowerCase(),
      EstadoNuevo: hacia.toLowerCase(),
      ID_user: actor,
      Motivo: motivo,
    },
  });
}

// T10 · Lo único que el colaborador ve del ticket ORIGINAL cuando el suyo es
// un duplicado: nada del dueño (ni nombre, ni correo, ni foto).
const seleccionOriginal = {
  ID_Ticket: true,
  Descripcion: true,
  Estado: true,
  Ubicacion: true,
  FechaCreacion: true,
  ID_user: true, // solo para saber si el original también es tuyo; nunca sale en la API
  categoriaReparacion: { select: { nombre: true } },
};

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

  async findByOwnerPage(ownerId, { estados = [], skip = 0, take = 20 }) {
    const dueno = idNumerico(ownerId);
    if (dueno === null) return { tickets: [], total: 0, totalOwner: 0, activos: 0 };
    const where = {
      ID_user: dueno,
      ...(estados.length > 0 && {
        Estado: { in: estados.map((estado) => estado.toLowerCase()), mode: 'insensitive' },
      }),
    };
    const activosWhere = {
      ID_user: dueno,
      Estado: {
        in: ['recibido', 'en_revision', 'aprobado', 'en_proceso', 'autogestion'],
        mode: 'insensitive',
      },
    };
    const [filas, total, totalOwner, activos] = await Promise.all([
      this.prisma.ticket.findMany({
        where,
        include: incluir,
        omit: sinImagen,
        orderBy: [{ FechaCreacion: 'desc' }, { ID_Ticket: 'desc' }],
        skip,
        take,
      }),
      this.prisma.ticket.count({ where }),
      this.prisma.ticket.count({ where: { ID_user: dueno } }),
      this.prisma.ticket.count({ where: activosWhere }),
    ]);
    return { tickets: filas.map(aTicket), total, totalOwner, activos };
  }

  async findActiveCandidates({ category = null, location = null, excludeId = null } = {}) {
    const estadosActivos = ['recibido', 'en_revision', 'en revision', 'aprobado', 'en_proceso', 'en proceso', 'autogestion'];
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

    return this.prisma.$transaction(async (tx) => {
      const { count } = await tx.ticket.updateMany({
        where: { ID_Ticket: ticketId, ID_user: dueno, Estado: { equals: 'recibido', mode: 'insensitive' } },
        data: { Estado: 'cancelado', FechaCierre: new Date() },
      });
      if (count > 0) {
        await registrarEstado(tx, {
          ticketId, desde: 'RECIBIDO', hacia: 'CANCELADO', actorId: dueno,
        });
      }
      const fila = await tx.ticket.findFirst({ where: { ID_Ticket: ticketId, ID_user: dueno }, include: incluir, omit: sinImagen });
      return fila ? { cancelado: count > 0, ticket: aTicket(fila) } : null;
    });
  }

  async iniciarAutogestion(id, ownerId) {
    const ticketId = idNumerico(id);
    const dueno = idNumerico(ownerId);
    if (ticketId === null || dueno === null) return null;

    return this.prisma.$transaction(async (tx) => {
      const { count } = await tx.ticket.updateMany({
        where: {
          ID_Ticket: ticketId,
          ID_user: dueno,
          TipoSolucion: null,
          Estado: { equals: 'recibido', mode: 'insensitive' },
          Prioridad: { equals: 'baja', mode: 'insensitive' },
        },
        data: { Estado: 'autogestion' },
      });
      if (count > 0) {
        await registrarEstado(tx, {
          ticketId,
          desde: 'RECIBIDO',
          hacia: 'AUTOGESTION',
          actorId: dueno,
          motivo: 'Inicio de autogestión por guía de autoayuda.',
        });
      }
      const fila = await tx.ticket.findFirst({ where: { ID_Ticket: ticketId, ID_user: dueno }, include: incluir, omit: sinImagen });
      return fila ? { cambiado: count > 0, ticket: aTicket(fila) } : null;
    });
  }

  /**
   * T10 · Finaliza la autogestión en una transacción con su entrada de historial.
   *
   * Las condiciones van DENTRO de la escritura (tuyo, Autogestión, prioridad Baja y
   * sin una decisión previa): si el administrador lo tomó un instante antes, no
   * se cambia nada.
   * @returns {Promise<null | { aplicado: boolean, ticket }>}
   */
  async resolverConGuia(id, ownerId, accion) {
    const ticketId = idNumerico(id);
    const dueno = idNumerico(ownerId);
    if (ticketId === null || dueno === null) return null;

    const desde = 'AUTOGESTION';
    const hacia = accion === 'cerrar' ? 'CERRADO' : 'RECIBIDO';
    const motivo = accion === 'cerrar'
      ? 'Cierre por autogestión: el colaborador indicó que se solucionó.'
      : 'Autogestión no resolvió; ticket reportado a Servicios Generales.';
    return this.prisma.$transaction(async (tx) => {
      const { count } = await tx.ticket.updateMany({
        where: {
          ID_Ticket: ticketId,
          ID_user: dueno,
          TipoSolucion: null,
          Estado: { equals: desde.toLowerCase(), mode: 'insensitive' },
          Prioridad: { equals: 'baja', mode: 'insensitive' },
        },
        data: accion === 'cerrar'
          ? { Estado: hacia.toLowerCase(), FechaCierre: new Date(), TipoSolucion: 'autoayuda_ia' }
          : { Estado: hacia.toLowerCase(), Prioridad: 'media', TipoSolucion: 'escalado_colaborador' },
      });
      if (count > 0) {
        await registrarEstado(tx, { ticketId, desde, hacia, actorId: dueno, motivo });
      }
      const fila = await tx.ticket.findFirst({ where: { ID_Ticket: ticketId, ID_user: dueno }, include: incluir, omit: sinImagen });
      return fila ? { aplicado: count > 0, ticket: aTicket(fila) } : null;
    });
  }

  /**
   * T10 · Guarda que un ticket es duplicado de otro (lo decide la IA al crearlo).
   * Solo si sigue Recibido y aún no está agrupado; nunca consigo mismo.
   * @returns {Promise<boolean>} true si se guardó.
   */
  async marcarDuplicado(id, originalId) {
    const ticketId = idNumerico(id);
    const original = idNumerico(originalId);
    if (ticketId === null || original === null || ticketId === original) return false;
    const { count } = await this.prisma.ticket.updateMany({
      where: {
        ID_Ticket: ticketId,
        ID_TicketOriginal: null,
        Estado: { equals: 'recibido', mode: 'insensitive' },
      },
      data: { ID_TicketOriginal: original },
    });
    return count > 0;
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
  async findDetail(id, { ownerId = null } = {}) {
    const ticketId = idNumerico(id);
    const dueno = ownerId === null ? null : idNumerico(ownerId);
    if (ticketId === null || (ownerId !== null && dueno === null)) return null;

    const where = { ID_Ticket: ticketId };
    if (dueno !== null) where.ID_user = dueno;

    const fila = await this.prisma.ticket.findFirst({
      where,
      include: {
        ...incluir,
        // T10: si es un duplicado, un resumen del original (sin datos de su dueño).
        ticketOriginal: { select: seleccionOriginal },
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
        historialEstados: {
          orderBy: [{ Fecha: 'asc' }, { ID_CambioEstado: 'asc' }],
          select: {
            EstadoAnterior: true,
            EstadoNuevo: true,
            Fecha: true,
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
      original: fila.ticketOriginal
        ? {
            id: String(fila.ticketOriginal.ID_Ticket),
            code: `REP-${String(fila.ticketOriginal.ID_Ticket).padStart(4, '0')}`,
            category: nombreVisible(fila.ticketOriginal.categoriaReparacion?.nombre),
            title: fila.ticketOriginal.Descripcion,
            status: codigoApi(fila.ticketOriginal.Estado),
            location: fila.ticketOriginal.Ubicacion,
            createdAt: fila.ticketOriginal.FechaCreacion,
            ownerId: String(fila.ticketOriginal.ID_user),
          }
        : null,
      comments: fila.comentarios.map((c) => ({
        id: c.ID_Comentario,
        author: [c.autor?.name, c.autor?.appat].filter(Boolean).join(' ') || 'Servicios Generales',
        createdAt: c.FechaCreacion,
        text: c.Texto,
      })),
      timeline: fila.historialEstados.map((cambio) => ({
        status: codigoApi(cambio.EstadoNuevo),
        previousStatus: codigoApi(cambio.EstadoAnterior),
        date: cambio.Fecha,
      })),
    };
  }

  async findDetailForOwner(id, ownerId) {
    return this.findDetail(id, { ownerId });
  }

  /**
   * MM2 · Guarda la prioridad inicial que calculó la IA/reglas.
   * Solo escribe si el ticket SIGUE en Recibido y aún no tiene prioridad: así
   * no pisa un ticket que el colaborador canceló mientras la IA lo analizaba
   * (RF-09) ni una prioridad que el administrador ya cambió a mano.
   * @returns {Promise<boolean>} true si se guardó.
   */
  async guardarPrioridadInicial(id, { prioridad, origen, reglaId = null, nivelIncidencia = null }) {
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
        NivelIncidencia: nivelIncidencia,
      },
    });
    return count > 0;
  }

  /**
   * T11 · El administrador cambia el estado de un ticket (cualquier dueño).
   * La escritura exige que el ticket siga en el estado `desde`: si otro
   * administrador lo movió un instante antes, no se pisa (cambiado: false).
   * @returns {Promise<null | { ticket, cambiado: boolean }>}
   */
  async cambiarEstado(id, { desde, hacia, motivo = null, actorId }) {
    const ticketId = idNumerico(id);
    const actor = idNumerico(actorId);
    if (ticketId === null || actor === null) return null;
    const terminal = ['RECHAZADO', 'RESUELTO', 'CERRADO'].includes(hacia);
    return this.prisma.$transaction(async (tx) => {
      const { count } = await tx.ticket.updateMany({
        where: { ID_Ticket: ticketId, Estado: { equals: desde.toLowerCase(), mode: 'insensitive' } },
        data: {
          Estado: hacia.toLowerCase(),
          ...(hacia === 'RECHAZADO' && { MotivoRechazo: motivo }),
          ...(terminal && { FechaCierre: new Date() }),
        },
      });
      if (count > 0) {
        await registrarEstado(tx, { ticketId, desde, hacia, actorId: actor, motivo });
      }
      const fila = await tx.ticket.findFirst({ where: { ID_Ticket: ticketId }, include: incluir, omit: sinImagen });
      return fila ? { ticket: aTicket(fila), cambiado: count > 0 } : null;
    });
  }

  /** T11 · Cualquier ticket por id (para el administrador). Sin la foto. */
  async findById(id) {
    const ticketId = idNumerico(id);
    if (ticketId === null) return null;
    const fila = await this.prisma.ticket.findFirst({ where: { ID_Ticket: ticketId }, include: incluir, omit: sinImagen });
    return fila ? aTicket(fila) : null;
  }

  /** T11 · El administrador comenta un ticket. Devuelve el comentario creado. */
  async crearComentario(id, { adminId, texto }) {
    const ticketId = idNumerico(id);
    const autor = idNumerico(adminId);
    if (ticketId === null || autor === null) return null;
    const c = await this.prisma.comentarioTicket.create({
      data: { ID_Ticket: ticketId, ID_admin: autor, Texto: texto },
      select: { ID_Comentario: true, Texto: true, FechaCreacion: true },
    });
    return { id: String(c.ID_Comentario), text: c.Texto, createdAt: c.FechaCreacion };
  }

  /**
   * MM2 · El administrador cambia la prioridad. En UNA transacción: lee el
   * ticket, lo actualiza y deja el registro en CambioPrioridad (quién y cuándo).
   * @returns {Promise<null | { ticket, cambiado: boolean, bloqueado: boolean, prioridadAnterior?: string|null }>}
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
      return { ticket: { ...ticket, priority: prioridad }, cambiado: true, bloqueado: false, prioridadAnterior: ticket.priority };
    });
  }

  /**
   * Foto de un ticket del dueño. Solo lee la columna imagen (BYTEA).
   * Devuelve null si el ticket no existe o es de otra persona, y
   * { imagen: null } si el ticket existe pero no tiene foto.
   */
  async findPhoto(id, { ownerId = null } = {}) {
    const ticketId = idNumerico(id);
    const dueno = ownerId === null ? null : idNumerico(ownerId);
    if (ticketId === null || (ownerId !== null && dueno === null)) return null;
    const where = { ID_Ticket: ticketId };
    if (dueno !== null) where.ID_user = dueno;
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

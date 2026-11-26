// ¿PARA QUÉ SIRVE?
//   Lee de la base de datos lo que necesitan el Home del administrador y el
//   "Listado de personal" (T13).
//
// ¿QUÉ HACE?
//   - listar(): cada persona con su nombre, correo, área, rol y un resumen de
//     sus tickets ("2 tickets abiertos", "1 urgente", "3 en proceso"...).
//   - resumen(): los números del Home (pendientes, urgentes, duplicados...).
//   Solo saca lo que se muestra: nunca contraseñas, teléfono ni datos de
//   consentimiento.
//
// ¿CÓMO LO CAMBIO?
//   Si la pantalla necesita un dato más de la persona, agrégalo al `select` y a
//   `aPersona`. Mantén igual la versión en memoria (más abajo) para las pruebas.

// Estados en que un ticket sigue "en atención".
const ESTADOS_ACTIVOS = ['RECIBIDO', 'EN_REVISION', 'APROBADO', 'EN_PROCESO'];
const ESTADOS_PENDIENTES = ['RECIBIDO', 'EN_REVISION']; // esperan una decisión del administrador
const ESTADOS_ACTIVOS_BD = ['recibido', 'en_revision', 'en revision', 'aprobado', 'en_proceso', 'en proceso'];

// "en_proceso" (BD) -> "EN_PROCESO"
function estadoApi(valor) {
  return String(valor ?? '').trim().replace(/\s+/g, '_').toUpperCase();
}

function esUrgente(t) {
  return String(t.Prioridad ?? t.priority ?? '').toUpperCase() === 'ALTA';
}

function mismoDia(a, b) {
  return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
}

/** Resumen de los tickets de una persona para su etiqueta en la lista. */
function resumenTickets(tickets, hoy = new Date()) {
  const activos = tickets.filter((t) => ESTADOS_ACTIVOS.includes(estadoApi(t.Estado ?? t.status)));
  return {
    activos: activos.length,
    urgentes: activos.filter(esUrgente).length,
    enProceso: activos.filter((t) => estadoApi(t.Estado ?? t.status) === 'EN_PROCESO').length,
    resueltosHoy: tickets.filter((t) => {
      const estado = estadoApi(t.Estado ?? t.status);
      const cierre = t.FechaCierre ?? t.closedAt;
      return (estado === 'RESUELTO' || estado === 'CERRADO') && cierre && mismoDia(new Date(cierre), hoy);
    }).length,
  };
}

function rolApi(nombre) {
  return String(nombre ?? '').toLowerCase().startsWith('admin') ? 'ADMINISTRADOR' : 'COLABORADOR';
}

function aPersona(u, tickets) {
  return {
    id: String(u.id),
    nombre: [u.name, u.appat, u.apmat].filter(Boolean).join(' '),
    email: u.email,
    area: u.departamento?.nom_depa ?? null,
    rol: rolApi(u.rol?.NombreRol),
    activo: (u.estado ?? 'activo').toLowerCase() === 'activo',
    tickets: resumenTickets(tickets),
  };
}

export class PrismaPersonalRepository {
  constructor(prisma) {
    this.prisma = prisma;
  }

  async listar() {
    const hoy = new Date();
    const inicioDelDia = new Date(hoy.getFullYear(), hoy.getMonth(), hoy.getDate());
    const [usuarios, tickets] = await Promise.all([
      this.prisma.user.findMany({
        select: {
          id: true,
          name: true,
          appat: true,
          apmat: true,
          email: true,
          estado: true,
          departamento: { select: { nom_depa: true } },
          rol: { select: { NombreRol: true } },
        },
        orderBy: [{ name: 'asc' }, { appat: 'asc' }],
      }),
      // Solo lo necesario para las etiquetas: activos y los cerrados hoy.
      this.prisma.ticket.findMany({
        where: {
          OR: [
            { Estado: { in: ESTADOS_ACTIVOS_BD, mode: 'insensitive' } },
            { FechaCierre: { gte: inicioDelDia } },
          ],
        },
        select: { ID_user: true, Estado: true, Prioridad: true, FechaCierre: true },
      }),
    ]);
    return usuarios.map((u) => aPersona(u, tickets.filter((t) => t.ID_user === u.id)));
  }

  async resumen() {
    const [tickets, personal] = await Promise.all([
      this.prisma.ticket.findMany({
        where: { Estado: { in: ESTADOS_ACTIVOS_BD, mode: 'insensitive' } },
        select: { Estado: true, Prioridad: true, ID_TicketOriginal: true },
      }),
      this.prisma.user.count(),
    ]);
    return {
      pendientes: tickets.filter((t) => ESTADOS_PENDIENTES.includes(estadoApi(t.Estado))).length,
      urgentes: tickets.filter(esUrgente).length,
      duplicados: tickets.filter((t) => t.ID_TicketOriginal !== null).length,
      activos: tickets.length,
      personal,
    };
  }
}

/**
 * Versión en memoria (pruebas y modo sin base de datos).
 * personas: [{ id, name, appat, apmat, email, area, role, estado }]
 * tickets:  los mismos objetos del repositorio de tickets en memoria.
 */
export class MemoryPersonalRepository {
  constructor({ personas = [], tickets = () => [] } = {}) {
    this.personas = personas;
    this.tickets = typeof tickets === 'function' ? tickets : () => tickets;
  }

  async listar() {
    return this.personas
      .map((p) => aPersona(
        { ...p, departamento: { nom_depa: p.area ?? null }, rol: { NombreRol: p.role } },
        this.tickets().filter((t) => String(t.ownerId) === String(p.id)),
      ))
      .sort((a, b) => a.nombre.localeCompare(b.nombre, 'es'));
  }

  async resumen() {
    const activos = this.tickets().filter((t) => ESTADOS_ACTIVOS.includes(estadoApi(t.status)));
    return {
      pendientes: activos.filter((t) => ESTADOS_PENDIENTES.includes(estadoApi(t.status))).length,
      urgentes: activos.filter(esUrgente).length,
      duplicados: activos.filter((t) => t.originalId).length,
      activos: activos.length,
      personal: this.personas.length,
    };
  }
}

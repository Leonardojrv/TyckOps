// ¿PARA QUÉ SIRVE?
//   Guarda los celulares (tokens push) y el historial de notificaciones de cada
//   persona (T11), en PostgreSQL o en memoria (pruebas y modo sin base de datos).
//
// ¿QUÉ HACE?
//   - Registra o mueve un token: un token es de UNA sola persona; si otra inicia
//     sesión en ese celular, el token pasa a ella.
//   - Crea notificaciones, las lista (solo las tuyas) y las marca como leídas.
//   Todas las consultas filtran por el dueño: nadie puede leer ni marcar avisos
//   ajenos aunque adivine un id.
//
// ¿CÓMO LO CAMBIO?
//   Si agregas una consulta en uno de los dos repositorios, agrégala también en
//   el otro para que las pruebas sigan representando a PostgreSQL.

const MAX_LISTA = 50; // la pantalla muestra las 50 más recientes

function idNumerico(id) {
  const n = Number(id);
  return Number.isSafeInteger(n) && n > 0 ? n : null;
}

// "en_proceso" (BD) -> "EN_PROCESO" (API)
function estadoApi(valor) {
  return valor ? String(valor).trim().replace(/\s+/g, '_').toUpperCase() : null;
}

function aNotificacion(fila) {
  return {
    id: String(fila.ID_Notificacion),
    tipo: fila.Tipo,
    titulo: fila.Titulo,
    cuerpo: fila.Cuerpo,
    estado: estadoApi(fila.EstadoTicket),
    leida: fila.Leida,
    creadaEn: fila.FechaCreacion,
    ticketId: String(fila.ID_Ticket),
    codigo: fila.Codigo ?? `REP-${String(fila.ID_Ticket).padStart(4, '0')}`, // en memoria viene guardado
    comentarioId: fila.ID_Comentario ? String(fila.ID_Comentario) : null,
  };
}

export class PrismaNotificacionesRepository {
  constructor(prisma) {
    this.prisma = prisma;
  }

  async registrarToken(userId, token, plataforma) {
    const usuario = idNumerico(userId);
    if (usuario === null) return false;
    await this.prisma.dispositivoPush.upsert({
      where: { Token: token },
      update: { ID_user: usuario, Plataforma: plataforma, FechaUltimoUso: new Date() },
      create: { Token: token, Plataforma: plataforma, ID_user: usuario },
    });
    return true;
  }

  // Solo borra el token si es tuyo (al cerrar sesión).
  async quitarToken(userId, token) {
    const usuario = idNumerico(userId);
    if (usuario === null) return 0;
    const { count } = await this.prisma.dispositivoPush.deleteMany({ where: { Token: token, ID_user: usuario } });
    return count;
  }

  async tokensDe(userId) {
    const usuario = idNumerico(userId);
    if (usuario === null) return [];
    const filas = await this.prisma.dispositivoPush.findMany({ where: { ID_user: usuario }, select: { Token: true } });
    return filas.map((f) => f.Token);
  }

  async borrarTokens(tokens) {
    if (!tokens?.length) return;
    await this.prisma.dispositivoPush.deleteMany({ where: { Token: { in: tokens } } });
  }

  async crear({ userId, ticketId, tipo, titulo, cuerpo, estado = null, comentarioId = null }) {
    const fila = await this.prisma.notificacion.create({
      data: {
        ID_user: idNumerico(userId),
        ID_Ticket: idNumerico(ticketId),
        ID_Comentario: comentarioId ? idNumerico(comentarioId) : null,
        Tipo: tipo,
        Titulo: titulo,
        Cuerpo: cuerpo,
        EstadoTicket: estado ? String(estado).toLowerCase() : null,
      },
    });
    return aNotificacion(fila);
  }

  async listar(userId) {
    const usuario = idNumerico(userId);
    if (usuario === null) return { notificaciones: [], sinLeer: 0 };
    const [filas, sinLeer] = await Promise.all([
      this.prisma.notificacion.findMany({
        where: { ID_user: usuario },
        orderBy: { FechaCreacion: 'desc' },
        take: MAX_LISTA,
      }),
      this.prisma.notificacion.count({ where: { ID_user: usuario, Leida: false } }),
    ]);
    return { notificaciones: filas.map(aNotificacion), sinLeer };
  }

  // id = null marca todas. El filtro por dueño va en la misma escritura.
  async marcarLeidas(userId, id = null) {
    const usuario = idNumerico(userId);
    if (usuario === null) return 0;
    const where = { ID_user: usuario, Leida: false };
    if (id !== null) {
      const n = idNumerico(id);
      if (n === null) return 0;
      where.ID_Notificacion = n;
    }
    const { count } = await this.prisma.notificacion.updateMany({ where, data: { Leida: true } });
    return count;
  }
}

export class MemoryNotificacionesRepository {
  constructor() {
    this.dispositivos = new Map(); // token -> { userId, plataforma }
    this.notificaciones = [];
    this.siguienteId = 1;
  }

  async registrarToken(userId, token, plataforma) {
    this.dispositivos.set(token, { userId: String(userId), plataforma });
    return true;
  }

  async quitarToken(userId, token) {
    if (this.dispositivos.get(token)?.userId !== String(userId)) return 0;
    this.dispositivos.delete(token);
    return 1;
  }

  async tokensDe(userId) {
    return [...this.dispositivos].filter(([, d]) => d.userId === String(userId)).map(([t]) => t);
  }

  async borrarTokens(tokens) {
    for (const t of tokens ?? []) this.dispositivos.delete(t);
  }

  async crear({ userId, ticketId, codigo = null, tipo, titulo, cuerpo, estado = null, comentarioId = null }) {
    const fila = {
      Codigo: codigo,
      ID_Notificacion: this.siguienteId++,
      ID_user: String(userId),
      ID_Ticket: ticketId,
      ID_Comentario: comentarioId,
      Tipo: tipo,
      Titulo: titulo,
      Cuerpo: cuerpo,
      EstadoTicket: estado,
      Leida: false,
      FechaCreacion: new Date(),
    };
    this.notificaciones.push(fila);
    return aNotificacion(fila);
  }

  async listar(userId) {
    const mias = this.notificaciones
      .filter((n) => n.ID_user === String(userId))
      .sort((a, b) => b.FechaCreacion - a.FechaCreacion || b.ID_Notificacion - a.ID_Notificacion);
    return { notificaciones: mias.slice(0, MAX_LISTA).map(aNotificacion), sinLeer: mias.filter((n) => !n.Leida).length };
  }

  async marcarLeidas(userId, id = null) {
    let cambiadas = 0;
    for (const n of this.notificaciones) {
      if (n.ID_user !== String(userId) || n.Leida) continue;
      if (id !== null && String(n.ID_Notificacion) !== String(id)) continue;
      n.Leida = true;
      cambiadas += 1;
    }
    return cambiadas;
  }
}

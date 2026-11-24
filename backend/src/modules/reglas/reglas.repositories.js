// ¿PARA QUÉ SIRVE?
//   Guarda las versiones del .txt de reglas de prioridad (MM2).
//
// ¿QUÉ HACE?
//   Dos versiones con la misma forma:
//   - MemoryReglasRepository: para pruebas y modo demo (sin base de datos).
//   - PrismaReglasRepository: tabla ReglasPrioridad (una fila = una versión).
//   Activar una versión desactiva las demás en la misma operación.
//
// ¿CÓMO LO CAMBIO?
//   Si agregas un método en uno, agrégalo también en el otro.

function idNumerico(id) {
  const numero = Number(id);
  return Number.isSafeInteger(numero) && numero > 0 ? numero : null;
}

export class MemoryReglasRepository {
  constructor() {
    this.versiones = [];
  }

  async guardarVersion({ texto, adminId }) {
    const version = {
      id: this.versiones.length + 1,
      texto,
      activa: false,
      creadaEn: new Date(),
      activadaEn: null,
      adminId: String(adminId),
    };
    this.versiones.push(version);
    return { ...version };
  }

  async activarVersion(id) {
    const version = this.versiones.find((v) => v.id === id);
    if (!version) return null;
    for (const v of this.versiones) v.activa = false;
    version.activa = true;
    version.activadaEn = new Date();
    return { ...version };
  }

  async versionActiva() {
    const activa = this.versiones.find((v) => v.activa);
    return activa ? { ...activa } : null;
  }
}

const aVersion = (fila) => ({
  id: fila.ID_Regla,
  texto: fila.archivo,
  activa: fila.Activa,
  creadaEn: fila.FechaInsercion,
  activadaEn: fila.FechaActivacion,
  adminId: String(fila.ID_user),
});

export class PrismaReglasRepository {
  constructor(prisma) {
    if (!prisma.reglasPrioridad?.findFirst) throw new Error('El cliente Prisma no tiene el modelo ReglasPrioridad esperado.');
    this.prisma = prisma;
  }

  async guardarVersion({ texto, adminId }) {
    const fila = await this.prisma.reglasPrioridad.create({
      data: { archivo: texto, ID_user: idNumerico(adminId), Activa: false },
    });
    return aVersion(fila);
  }

  async activarVersion(id) {
    return this.prisma.$transaction(async (tx) => {
      const existe = await tx.reglasPrioridad.findUnique({ where: { ID_Regla: id }, select: { ID_Regla: true } });
      if (!existe) return null;
      await tx.reglasPrioridad.updateMany({ where: { Activa: true }, data: { Activa: false } });
      const fila = await tx.reglasPrioridad.update({
        where: { ID_Regla: id },
        data: { Activa: true, FechaActivacion: new Date() },
      });
      return aVersion(fila);
    });
  }

  async versionActiva() {
    const fila = await this.prisma.reglasPrioridad.findFirst({ where: { Activa: true } });
    return fila ? aVersion(fila) : null;
  }
}

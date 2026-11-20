// Repositorio en memoria para versiones de Guías de Autoayuda (Scrumban / RF-10 / RF-14).
// Permite versionar los archivos cargados, publicar versiones y consultar las vigentes.

export class MemoryGuiasRepository {
  constructor(versionesIniciales = []) {
    this.versiones = new Map();
    this.contadorVersiones = 0;

    for (const v of versionesIniciales) {
      this.contadorVersiones += 1;
      this.versiones.set(v.version, {
        version: v.version,
        activa: Boolean(v.activa),
        createdAt: v.createdAt ?? new Date(),
        activatedAt: v.activa ? (v.activatedAt ?? new Date()) : null,
        creadoPor: v.creadoPor ?? 'sistema',
        guias: (v.guias ?? []).map((g) => ({ ...g })),
      });
    }
  }

  async guardarVersion({ guias, adminId }) {
    this.contadorVersiones += 1;
    const version = `v${this.contadorVersiones}`;
    const registro = {
      version,
      activa: false,
      createdAt: new Date(),
      activatedAt: null,
      creadoPor: String(adminId),
      guias: guias.map((g) => ({ ...g })),
    };
    this.versiones.set(version, registro);
    return { ...registro, guias: [...registro.guias] };
  }

  async activarVersion(version) {
    const registro = this.versiones.get(version);
    if (!registro) return null;

    // Desactivar todas las versiones anteriores (conservando su historial)
    for (const v of this.versiones.values()) {
      if (v.activa) {
        v.activa = false;
      }
    }

    registro.activa = true;
    registro.activatedAt = new Date();
    return { ...registro, guias: [...registro.guias] };
  }

  async obtenerVersionActiva() {
    for (const v of this.versiones.values()) {
      if (v.activa) {
        return { ...v, guias: [...v.guias] };
      }
    }
    return null;
  }

  async obtenerPorVersion(version) {
    const registro = this.versiones.get(version);
    return registro ? { ...registro, guias: [...registro.guias] } : null;
  }

  async listarVersiones() {
    return Array.from(this.versiones.values()).map((v) => ({
      version: v.version,
      activa: v.activa,
      totalGuias: v.guias.length,
      createdAt: v.createdAt,
      activatedAt: v.activatedAt,
    }));
  }
}

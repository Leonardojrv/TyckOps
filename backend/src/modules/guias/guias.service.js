import { HttpError } from '../../utils/http-error.js';
import { generarPlantillaExcel, procesarArchivoExcel } from './guias.excel.js';

export class GuiasService {
  constructor(guiasRepository) {
    this.guiasRepository = guiasRepository;
  }

  /**
   * Genera el buffer Excel para la plantilla oficial de guías.
   */
  async generarPlantilla() {
    return generarPlantillaExcel();
  }

  /**
   * Procesa, valida celdas y guarda una nueva versión de guías desde el archivo Excel.
   */
  async procesarYGuardarArchivo(buffer, adminId) {
    const resultado = await procesarArchivoExcel(buffer);

    if (!resultado.success) {
      if (resultado.codigo === 'ERRORES_VALIDACION') {
        throw new HttpError(400, 'ERRORES_VALIDACION', resultado.mensaje, resultado.errores);
      }
      throw new HttpError(400, resultado.codigo, resultado.mensaje);
    }

    const versionGuardada = await this.guiasRepository.guardarVersion({
      guias: resultado.guias,
      adminId,
    });

    return {
      version: versionGuardada.version,
      totalGuias: versionGuardada.guias.length,
      mensaje: `Archivo procesado correctamente con ${versionGuardada.guias.length} guías. Versión ${versionGuardada.version} lista para ser activada.`,
      guias: versionGuardada.guias,
    };
  }

  /**
   * Publica la versión indicada como activa/vigente y archiva la anterior.
   */
  async activarVersion(version) {
    const versionActivada = await this.guiasRepository.activarVersion(version);
    if (!versionActivada) {
      throw new HttpError(404, 'VERSION_NO_ENCONTRADA', `No se encontró la versión '${version}'.`);
    }

    return {
      version: versionActivada.version,
      activa: true,
      totalGuias: versionActivada.guias.length,
      mensaje: `Versión ${versionActivada.version} publicada exitosamente. Las guías ya están vigentes.`,
    };
  }

  /**
   * Devuelve las guías vigentes (de la versión activa actual).
   */
  async obtenerVigentes() {
    const activa = await this.guiasRepository.obtenerVersionActiva();
    if (!activa) {
      return {
        version: null,
        total: 0,
        guias: [],
      };
    }

    return {
      version: activa.version,
      total: activa.guias.length,
      guias: activa.guias,
    };
  }
}

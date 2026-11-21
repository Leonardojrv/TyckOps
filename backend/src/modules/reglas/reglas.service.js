// ¿PARA QUÉ SIRVE?
//   Reglas de prioridad del administrador (MM2): subir el .txt, activarlo y leer
//   las vigentes. Funciona igual que las guías: cada archivo es una versión que
//   se sube inactiva y luego se activa (solo una activa a la vez).
//
// ¿QUÉ HACE?
//   Valida el archivo con reglas.parser.js antes de guardarlo. Lo que se guarda
//   es el texto original; al leerlo se vuelve a convertir en reglas.
//
// ¿CÓMO LO CAMBIO?
//   Lo que se guarda o lee de la base va en los repositorios (memoria / Prisma).

import { HttpError } from '../../utils/http-error.js';
import { decodificarTexto, MAX_BYTES_REGLAS, parsearReglas } from './reglas.parser.js';

function publicaVersion(version) {
  return {
    version: version.id,
    activa: Boolean(version.activa),
    subidaEn: new Date(version.creadaEn).toISOString(),
    activadaEn: version.activadaEn ? new Date(version.activadaEn).toISOString() : null,
  };
}

const sinPosicion = ({ linea: _linea, ...regla }) => regla;

export class ReglasService {
  constructor(reglasRepository) {
    this.reglasRepository = reglasRepository;
  }

  async subirArchivo(buffer, adminId) {
    if (!buffer?.length) throw new HttpError(400, 'ARCHIVO_REQUERIDO', 'Adjunta el archivo .txt de reglas en el campo "archivo".');
    if (buffer.length > MAX_BYTES_REGLAS) throw new HttpError(413, 'ARCHIVO_MUY_GRANDE', 'El archivo supera los 200 KB.');

    const texto = decodificarTexto(buffer);
    if (texto === null) throw new HttpError(400, 'FORMATO_INVALIDO', 'El archivo debe ser texto plano (.txt) en UTF-8.');

    const resultado = parsearReglas(texto);
    if (!resultado.ok) {
      throw new HttpError(400, 'ERRORES_VALIDACION', `El archivo tiene ${resultado.errores.length} error(es). Corrígelos y vuelve a subirlo.`, resultado.errores);
    }

    const version = await this.reglasRepository.guardarVersion({ texto, adminId });
    return {
      ...publicaVersion(version),
      totalReglas: resultado.reglas.length,
      mensaje: `Archivo válido con ${resultado.reglas.length} reglas. Versión ${version.id} lista para activarse.`,
      reglas: resultado.reglas.map(sinPosicion),
    };
  }

  async activar(versionTexto) {
    const id = Number(String(versionTexto).replace(/^v/i, ''));
    const version = Number.isSafeInteger(id) && id > 0 ? await this.reglasRepository.activarVersion(id) : null;
    if (!version) throw new HttpError(404, 'VERSION_NO_ENCONTRADA', `No existe la versión ${String(versionTexto).slice(0, 20)}.`);
    return { ...publicaVersion(version), mensaje: `Versión ${version.id} activada: las reglas ya se usan en los tickets nuevos.` };
  }

  /**
   * Reglas de la versión activa, con su número de versión.
   * @returns {Promise<{ version: number|null, reglas: Array<{id, categoria, prioridad, descripcion}> }>}
   */
  async vigentes() {
    const activa = await this.reglasRepository.versionActiva();
    if (!activa) return { version: null, reglas: [] };
    const resultado = parsearReglas(activa.texto);
    // Se validó al subirla; si aun así falla (alguien editó la base a mano), no se usa.
    return resultado.ok
      ? { version: activa.id, reglas: resultado.reglas.map(sinPosicion) }
      : { version: null, reglas: [] };
  }

  async listarVigentes() {
    const activa = await this.reglasRepository.versionActiva();
    const { reglas } = await this.vigentes();
    return {
      version: activa ? publicaVersion(activa) : null,
      total: reglas.length,
      reglas,
    };
  }
}

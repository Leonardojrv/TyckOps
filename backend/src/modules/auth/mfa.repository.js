// ¿PARA QUÉ SIRVE?
//   Guarda en PostgreSQL (tabla "CodigoMFA") los desafíos de la verificación en
//   dos pasos, en vez de tenerlos en la memoria del servidor. Así sobreviven a un
//   reinicio y funcionan con varios servidores.
//
// ¿QUÉ GUARDA?
//   Por cada desafío: a quién pertenece, el HASH del código (Argon2id, nunca el
//   código tal cual), cuándo vence (máximo 3 minutos), intentos y reenvíos.
//
// ¿CÓMO SE USA?
//   const repo = new PrismaMfaRepository(prisma);
//   const d = await repo.crear({ userId, codigo });          // tras contraseña correcta
//   const r = await repo.verificar(d.id, codigoEscrito);     // { estado: 'correcto' | ... }
//   await repo.reemplazarCodigo(d.id, codigoNuevo);          // "Reenviar código"
//   await repo.limpiarVencidos();                             // limpieza periódica
//
//   Las reglas de negocio (espera para reenviar, cuántos reenvíos, mensajes de
//   error, envío del correo) siguen siendo del MfaService (auth.mfa.js).

import { hash, verify } from '@node-rs/argon2';
import { OPCIONES_ARGON2 } from './passwords.js';

/** Vigencia máxima de un código. La BD rechaza (CHECK) cualquier valor mayor. */
export const VIGENCIA_MFA_MS = 3 * 60 * 1000;
export const MAX_INTENTOS_MFA = 5;

const CODIGO_VALIDO = /^\d{6}$/;

/** Cifra el código con Argon2id (sal aleatoria propia, formato PHC). */
export function cifrarCodigoMfa(codigo) {
  if (typeof codigo !== 'string' || !CODIGO_VALIDO.test(codigo)) {
    throw new Error('El código MFA debe tener exactamente 6 dígitos.');
  }
  return hash(codigo, OPCIONES_ARGON2);
}

/** Compara el código escrito con el hash guardado. Nunca lanza: si algo falla, es incorrecto. */
export async function verificarCodigoMfa(codigo, codigoHash) {
  if (typeof codigo !== 'string' || !CODIGO_VALIDO.test(codigo) || typeof codigoHash !== 'string') return false;
  try {
    return await verify(codigoHash, codigo);
  } catch {
    return false;
  }
}

function idNumerico(id) {
  const numero = Number(id);
  if (!Number.isInteger(numero)) throw new Error('userId inválido para el desafío MFA.');
  return numero;
}

// Lo que sale del repositorio: nunca incluye el hash.
function publico(fila) {
  return {
    id: fila.ID_CodigoMFA,
    userId: String(fila.ID_user),
    creado: fila.FechaCreacion,
    ultimoEnvio: fila.UltimoEnvio,
    expira: fila.FechaExpiracion,
    intentos: fila.Intentos,
    reenvios: fila.Reenvios,
  };
}

const esNoEncontrado = (error) => error?.code === 'P2025';

export class PrismaMfaRepository {
  constructor(prisma, { vigenciaMs = VIGENCIA_MFA_MS, maxIntentos = MAX_INTENTOS_MFA, ahora = () => new Date() } = {}) {
    if (!prisma?.codigoMFA?.create) {
      throw new Error('El cliente Prisma no tiene el modelo CodigoMFA (¿falta "pnpm prisma:generate"?).');
    }
    if (!(vigenciaMs > 0 && vigenciaMs <= VIGENCIA_MFA_MS)) {
      throw new Error(`La vigencia del código MFA debe estar entre 1 ms y ${VIGENCIA_MFA_MS} ms (3 minutos).`);
    }
    this.prisma = prisma;
    this.vigenciaMs = vigenciaMs;
    this.maxIntentos = maxIntentos;
    this.ahora = ahora;
  }

  /**
   * Crea un desafío nuevo y anula los anteriores del mismo usuario
   * (solo un código válido por persona a la vez).
   */
  async crear({ userId, codigo }) {
    const ID_user = idNumerico(userId);
    const CodigoHash = await cifrarCodigoMfa(codigo);
    const ahora = this.ahora();
    const [, fila] = await this.prisma.$transaction([
      this.prisma.codigoMFA.deleteMany({ where: { ID_user } }),
      this.prisma.codigoMFA.create({
        data: {
          ID_user,
          CodigoHash,
          FechaCreacion: ahora,
          UltimoEnvio: ahora,
          FechaExpiracion: new Date(ahora.getTime() + this.vigenciaMs),
        },
      }),
    ]);
    return publico(fila);
  }

  /** Datos del desafío (sin el hash) o null si no existe. */
  async buscar(id) {
    const fila = await this.prisma.codigoMFA.findUnique({ where: { ID_CodigoMFA: id } }).catch(() => null);
    return fila ? publico(fila) : null;
  }

  /**
   * Revisa el código. Devuelve { estado, userId?, intentos?, quedan? } donde estado es:
   *  - 'correcto'     -> el desafío se borró (un solo uso). Trae userId.
   *  - 'incorrecto'   -> suma un intento. Trae intentos y quedan.
   *  - 'bloqueado'    -> llegó al máximo de intentos; el desafío se borró.
   *  - 'vencido'      -> pasaron los 3 minutos; el desafío se borró.
   *  - 'inexistente'  -> ya se usó, se anuló o nunca existió.
   */
  async verificar(id, codigo) {
    const fila = await this.prisma.codigoMFA.findUnique({ where: { ID_CodigoMFA: id } }).catch(() => null);
    if (!fila) return { estado: 'inexistente' };

    if (this.ahora() >= fila.FechaExpiracion) {
      await this.eliminar(id);
      return { estado: 'vencido' };
    }

    if (await verificarCodigoMfa(String(codigo), fila.CodigoHash)) {
      // deleteMany + count: si dos peticiones llegan a la vez con el código
      // correcto, solo una lo "consume". La otra queda como inexistente.
      const { count } = await this.prisma.codigoMFA.deleteMany({
        where: { ID_CodigoMFA: id, CodigoHash: fila.CodigoHash },
      });
      return count === 1 ? { estado: 'correcto', userId: String(fila.ID_user) } : { estado: 'inexistente' };
    }

    let intentos;
    try {
      ({ Intentos: intentos } = await this.prisma.codigoMFA.update({
        where: { ID_CodigoMFA: id },
        data: { Intentos: { increment: 1 } },
        select: { Intentos: true },
      }));
    } catch (error) {
      if (esNoEncontrado(error)) return { estado: 'inexistente' };
      throw error;
    }
    if (intentos >= this.maxIntentos) {
      await this.eliminar(id);
      return { estado: 'bloqueado', intentos };
    }
    return { estado: 'incorrecto', intentos, quedan: this.maxIntentos - intentos };
  }

  /**
   * Cambia el código de un desafío ("Reenviar código"): el anterior deja de
   * servir, el plazo de 3 minutos parte de nuevo y los intentos vuelven a 0.
   * Devuelve el desafío actualizado o null si ya no existe.
   */
  async reemplazarCodigo(id, codigo) {
    const CodigoHash = await cifrarCodigoMfa(codigo);
    const ahora = this.ahora();
    try {
      const fila = await this.prisma.codigoMFA.update({
        where: { ID_CodigoMFA: id },
        data: {
          CodigoHash,
          UltimoEnvio: ahora,
          FechaExpiracion: new Date(ahora.getTime() + this.vigenciaMs),
          Intentos: 0,
          Reenvios: { increment: 1 },
        },
      });
      return publico(fila);
    } catch (error) {
      if (esNoEncontrado(error)) return null;
      throw error;
    }
  }

  /** Borra un desafío. Devuelve true si existía. */
  async eliminar(id) {
    const { count } = await this.prisma.codigoMFA.deleteMany({ where: { ID_CodigoMFA: id } });
    return count === 1;
  }

  /** Borra todos los desafíos de un usuario (por ejemplo, al cambiar su contraseña). */
  async eliminarDelUsuario(userId) {
    const { count } = await this.prisma.codigoMFA.deleteMany({ where: { ID_user: idNumerico(userId) } });
    return count;
  }

  /** Borra los desafíos vencidos. Devuelve cuántos borró. Pensado para correr cada pocos minutos. */
  async limpiarVencidos() {
    const { count } = await this.prisma.codigoMFA.deleteMany({ where: { FechaExpiracion: { lte: this.ahora() } } });
    return count;
  }
}

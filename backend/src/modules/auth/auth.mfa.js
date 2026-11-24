// ¿PARA QUÉ SIRVE?
//   Es la "verificación en dos pasos" (MFA): después de la contraseña, la persona
//   debe escribir un código de 6 dígitos que le llega al correo corporativo.
//
// ¿QUÉ HACE?
//   Crea el código, lo guarda solo como una "huella" (nunca el código tal cual),
//   lo envía, lo revisa con un límite de intentos y de tiempo, y lo borra al
//   usarlo (sirve una sola vez). También permite reenviarlo con tiempo de espera.
//
// ¿CÓMO LO CAMBIO?
//   - Minutos de validez, intentos o espera para reenviar: opciones del constructor.
//   - Envío real por correo: pásale una función `enviarCodigo` que mande el email
//     (hoy, en desarrollo, solo se usa un código fijo y se anota en la consola).
//   - Si hay varios servidores, los desafíos deberían guardarse en la base de
//     datos o en Redis en vez de en memoria.

import { createHash, randomInt, randomUUID, timingSafeEqual } from 'node:crypto';
import jwt from 'jsonwebtoken';
import { HttpError } from '../../utils/http-error.js';
import { MAX_INTENTOS_MFA } from './mfa.repository.js';

// La "huella" del código: un resumen que no permite recuperar el código.
// Se mezcla con el id del desafío para que dos códigos iguales no dejen la misma huella.
function huella(desafioId, codigo) {
  return createHash('sha256').update(`${desafioId}:${codigo}`).digest();
}

function codigoAleatorio() {
  // randomInt usa el generador seguro del sistema (no Math.random).
  return String(randomInt(0, 1_000_000)).padStart(6, '0');
}

export class MfaService {
  constructor({
    jwtSecret,
    enviarCodigo = null, // async ({ email, codigo }) => void
    codigoFijo = null, // SOLO desarrollo: código conocido para probar sin correo
    vigenciaMs = 3 * 60 * 1000, // el mockup dice 3 minutos
    esperaReenvioMs = 30 * 1000,
    maxIntentos = MAX_INTENTOS_MFA, // 3: al tercer código incorrecto, el código caduca
    maxReenvios = 5,
    ahora = () => Date.now(),
    auditLogger = { log: () => {} },
  }) {
    if (!enviarCodigo && !codigoFijo) {
      throw new Error('MfaService necesita una forma de enviar el código (o un código fijo en desarrollo).');
    }
    this.jwtSecret = jwtSecret;
    this.enviarCodigo = enviarCodigo;
    this.codigoFijo = codigoFijo;
    this.vigenciaMs = vigenciaMs;
    this.esperaReenvioMs = esperaReenvioMs;
    this.maxIntentos = maxIntentos;
    this.maxReenvios = maxReenvios;
    this.ahora = ahora;
    this.auditLogger = auditLogger;
    this.desafios = new Map(); // desafioId -> { userId, role, email, huella, expira, intentos, reenvios, ultimoEnvio }
  }

  // Limpia los desafíos viejos para que la memoria no crezca sin fin.
  #limpiar() {
    const limite = this.ahora() - 30 * 60 * 1000;
    for (const [id, d] of this.desafios) if (d.ultimoEnvio < limite) this.desafios.delete(id);
  }

  async #enviar(desafioId, desafio) {
    const codigo = this.codigoFijo ?? codigoAleatorio();
    desafio.huella = huella(desafioId, codigo);
    desafio.expira = this.ahora() + this.vigenciaMs;
    desafio.intentos = 0;
    desafio.ultimoEnvio = this.ahora();
    if (this.enviarCodigo) {
      await this.enviarCodigo({ email: desafio.email, codigo });
    }
  }

  /**
   * Empieza una verificación para alguien que ya puso bien su contraseña.
   * Devuelve un "pase de verificación" (mfaToken) que SOLO sirve para enviar el
   * código o pedir otro: no abre ninguna otra parte de la app.
   */
  async iniciar({ userId, role, email }) {
    this.#limpiar();
    const desafioId = randomUUID();
    const desafio = { userId: String(userId), role, email, reenvios: 0 };
    await this.#enviar(desafioId, desafio);
    this.desafios.set(desafioId, desafio);
    this.auditLogger.log({ action: 'mfa_iniciado', userId: String(userId) });

    const mfaToken = jwt.sign({ role, typ: 'mfa' }, this.jwtSecret, {
      subject: String(userId),
      jwtid: desafioId,
      expiresIn: '15m', // tiempo total para terminar la verificación
    });
    return { mfaToken, ...this.#tiempos(desafio) };
  }

  #tiempos(desafio) {
    return {
      expiraEn: new Date(desafio.expira).toISOString(),
      reenviarDesde: new Date(desafio.ultimoEnvio + this.esperaReenvioMs).toISOString(),
    };
  }

  /** Revisa el código. Si es correcto devuelve a quién pertenece; si no, explica por qué. */
  async verificar(desafioId, codigo) {
    const desafio = this.desafios.get(desafioId);
    // Ya se usó o nunca existió: el código de un solo uso no sirve dos veces.
    if (!desafio) {
      throw new HttpError(400, 'MFA_SESION_INVALIDA', 'Este código ya se usó o la verificación terminó. Inicia sesión de nuevo.');
    }
    if (this.ahora() > desafio.expira) {
      throw new HttpError(400, 'MFA_CODIGO_VENCIDO', 'El código venció. Pide uno nuevo con "Reenviar código".');
    }

    // Se compara la huella en tiempo constante: así nadie puede adivinar el
    // código midiendo cuánto tarda el servidor en responder.
    const correcto = timingSafeEqual(huella(desafioId, String(codigo)), desafio.huella);
    if (!correcto) {
      desafio.intentos += 1;
      this.auditLogger.log({ action: 'mfa_fallido', userId: desafio.userId, intentos: desafio.intentos });
      if (desafio.intentos >= this.maxIntentos) {
        this.desafios.delete(desafioId); // se bloquea: hay que iniciar sesión de nuevo
        throw new HttpError(429, 'MFA_DEMASIADOS_INTENTOS', 'Demasiados intentos. Inicia sesión de nuevo para recibir otro código.');
      }
      const quedan = this.maxIntentos - desafio.intentos;
      throw new HttpError(400, 'MFA_CODIGO_INCORRECTO', `Código incorrecto. Te ${quedan === 1 ? 'queda 1 intento' : `quedan ${quedan} intentos`}.`);
    }

    this.desafios.delete(desafioId); // un solo uso
    this.auditLogger.log({ action: 'mfa_verificado', userId: desafio.userId });
    return { userId: desafio.userId, role: desafio.role };
  }

  /** Envía un código nuevo (el anterior deja de servir), respetando la espera. */
  async reenviar(desafioId) {
    const desafio = this.desafios.get(desafioId);
    if (!desafio) {
      throw new HttpError(400, 'MFA_SESION_INVALIDA', 'La verificación terminó. Inicia sesión de nuevo.');
    }
    if (this.ahora() < desafio.ultimoEnvio + this.esperaReenvioMs) {
      throw new HttpError(429, 'MFA_ESPERA_REENVIO', 'Espera un momento antes de pedir otro código.');
    }
    if (desafio.reenvios >= this.maxReenvios) {
      this.desafios.delete(desafioId);
      throw new HttpError(429, 'MFA_DEMASIADOS_INTENTOS', 'Pediste demasiados códigos. Inicia sesión de nuevo.');
    }
    desafio.reenvios += 1;
    await this.#enviar(desafioId, desafio);
    this.auditLogger.log({ action: 'mfa_reenviado', userId: desafio.userId });
    return this.#tiempos(desafio);
  }
}

/**
 * Elige cómo se envía el código según el entorno.
 * - Producción: exige un envío real por correo (si no hay, el servidor no arranca el MFA).
 * - Desarrollo/pruebas: usa un código fijo (por defecto 123456) y lo anota en la
 *   consola para poder probar sin correo. NUNCA en producción.
 */
export function crearMfaService({ env, enviarCodigo = null, auditLogger }) {
  if (env.nodeEnv === 'production') {
    if (!enviarCodigo) throw new Error('En producción el MFA necesita un envío real de correos.');
    return new MfaService({ jwtSecret: env.jwtSecret, enviarCodigo, auditLogger });
  }
  const codigoFijo = env.mfaCodigoDesarrollo ?? '123456';
  return new MfaService({
    jwtSecret: env.jwtSecret,
    codigoFijo,
    auditLogger,
    enviarCodigo: async ({ email }) => {
      console.info(`[MFA solo desarrollo] Código para ${email}: ${codigoFijo}`);
    },
  });
}

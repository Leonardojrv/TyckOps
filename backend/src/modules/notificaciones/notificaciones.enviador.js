// ¿PARA QUÉ SIRVE?
//   Manda las notificaciones push a los celulares (T11) con Firebase Cloud
//   Messaging (FCM), que entrega tanto a Android como a iOS.
//
// ¿QUÉ HACE?
//   - Si existe la clave de servicio de Firebase (FIREBASE_SERVICE_ACCOUNT o el
//     archivo backend/firebase-service-account.json), envía de verdad.
//   - Si no existe, funciona en modo SIMULADO: no envía nada y solo lo anota en
//     el log. Así el resto (historial, pantalla, pruebas) funciona igual.
//   Devuelve qué tokens ya no sirven (app desinstalada, token vencido) para
//   borrarlos.
//
// ¿CÓMO LO CAMBIO?
//   - Sonido, ícono o canal de Android: en `android` dentro de `mensaje`.
//   - La clave NUNCA va a GitHub (está en .gitignore). Cómo obtenerla: Firebase
//     → Configuración del proyecto → Cuentas de servicio → Generar clave.

import fs from 'node:fs';
import path from 'node:path';
import { logger } from '../../config/logger.js';

// Canal de Android donde caen los avisos (la app lo crea con este mismo id).
export const CANAL_ANDROID = 'tickets';

// Errores de FCM que significan "este token ya no existe": se borra.
const TOKEN_INVALIDO = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
  'messaging/invalid-argument',
]);

/** Envía de verdad con Firebase Admin. */
class EnviadorFirebase {
  constructor(messaging) {
    this.messaging = messaging;
    this.simulado = false;
  }

  async enviar(tokens, { titulo, cuerpo, datos }) {
    if (!tokens.length) return { enviados: 0, invalidos: [] };
    const respuesta = await this.messaging.sendEachForMulticast({
      tokens,
      notification: { title: titulo, body: cuerpo },
      // Solo ids y el tipo: la app los usa para abrir el ticket correcto.
      data: datos,
      android: {
        priority: 'high',
        notification: { channelId: CANAL_ANDROID, color: '#D7282F' },
      },
      apns: { payload: { aps: { sound: 'default' } } },
    });
    const invalidos = respuesta.responses
      .map((r, i) => (!r.success && TOKEN_INVALIDO.has(r.error?.code) ? tokens[i] : null))
      .filter(Boolean);
    return { enviados: respuesta.successCount, invalidos };
  }
}

/** No envía nada: solo deja constancia en el log (sin el token completo). */
class EnviadorSimulado {
  constructor() {
    this.simulado = true;
    this.enviadosSimulados = []; // las pruebas revisan lo que "se habría enviado"
  }

  async enviar(tokens, mensaje) {
    this.enviadosSimulados.push({ tokens: [...tokens], ...mensaje });
    logger.info('push_simulado', {
      tipo: 'notificacion',
      dispositivos: tokens.length,
      ticketId: mensaje.datos?.ticketId ?? null,
      clase: mensaje.datos?.tipo ?? null,
    });
    return { enviados: 0, invalidos: [] };
  }
}

/** Lee la clave de servicio: variable con el JSON, variable con la ruta o el archivo por defecto. */
function leerCuentaServicio(env) {
  const valor = env.firebaseServiceAccount;
  if (valor?.trim().startsWith('{')) return JSON.parse(valor);
  const ruta = path.resolve(valor || 'firebase-service-account.json');
  return fs.existsSync(ruta) ? JSON.parse(fs.readFileSync(ruta, 'utf8')) : null;
}

/**
 * Crea el enviador según haya o no clave de Firebase.
 * Nunca hace caer el servidor: si la clave está mala, usa el simulado y avisa.
 */
export async function crearEnviadorPush({ env }) {
  try {
    const cuenta = leerCuentaServicio(env);
    if (!cuenta) {
      logger.info('push_modo_simulado', { motivo: 'sin clave de servicio de Firebase' });
      return new EnviadorSimulado();
    }
    const { initializeApp, cert } = await import('firebase-admin/app');
    const { getMessaging } = await import('firebase-admin/messaging');
    const app = initializeApp({ credential: cert(cuenta) }, 'tyckops-push');
    logger.info('push_firebase_activo', { proyecto: cuenta.project_id ?? null });
    return new EnviadorFirebase(getMessaging(app));
  } catch (error) {
    logger.warn('push_modo_simulado', { motivo: 'clave de Firebase inválida', error: error.message });
    return new EnviadorSimulado();
  }
}

export { EnviadorSimulado };

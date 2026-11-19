import { logger } from '../../config/logger.js';

// Auditoría de accesos (login, primer acceso, términos). El correo se enmascara
// y la contraseña nunca llega aquí; ver src/config/logger.js.
// Los intentos fallidos van en warn: son los que interesa revisar.
const ACCIONES_ALERTA = new Set(['login_failed', 'login_rejected', 'password_change_failed', 'terms_rejected']);

export class AuthAuditLogger {
  log({ action, ...datos }) {
    const nivel = ACCIONES_ALERTA.has(action) ? 'warn' : 'info';
    logger[nivel](action, { tipo: 'auth', ...datos });
  }
}

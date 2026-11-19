import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { HttpError } from '../../utils/http-error.js';
import { AuthAuditLogger } from './auth.audit.js';

// Versión vigente de los Términos. Debe coincidir con termsDocCode de la app.
export const TERMS_VERSION = 'GA-TOS-2026';

const roleMap = new Map([
  ['COLABORADOR', 'COLABORADOR'],
  ['WORKER', 'COLABORADOR'],
  ['ADMINISTRADOR', 'ADMINISTRADOR'],
  ['ADMIN', 'ADMINISTRADOR'],
]);

function publicUser(user, role) {
  return {
    id: String(user.id),
    name: user.name,
    email: user.email,
    role,
    area: user.area ?? null,
    termsAccepted: Boolean(user.termsAccepted),
    isFirstLogin: Boolean(user.isFirstLogin),
  };
}

export class AuthService {
  // mfaService (opcional): si viene, el login exige la verificación en dos pasos
  // (T8). Sin él, el login funciona como antes (así siguen sirviendo las pruebas).
  constructor(userRepository, { jwtSecret, jwtExpiresIn = '1h' }, auditLogger = new AuthAuditLogger(), { mfaService = null } = {}) {
    this.userRepository = userRepository;
    this.jwtSecret = jwtSecret;
    this.jwtExpiresIn = jwtExpiresIn;
    this.auditLogger = auditLogger;
    this.mfa = mfaService;
  }

  // Crea la "llave" de la sesión. `typ` dice qué abre:
  // - 'acceso': la sesión completa (después de verificar el código).
  // - 'primer_acceso': solo deja hacer el primer acceso (contraseña y términos).
  #token(user, role, typ, expiresIn = this.jwtExpiresIn) {
    return jwt.sign({ role, typ }, this.jwtSecret, { subject: String(user.id), expiresIn });
  }

  async login({ email, password }, requestInfo = {}) {
    const user = await this.userRepository.findByEmail(email);
    const passwordMatches = user?.passwordHash
      ? await bcrypt.compare(password, user.passwordHash)
      : false;

    if (!user || !passwordMatches) {
      this.auditLogger.log({ action: 'login_failed', email, ...requestInfo });
      throw new HttpError(401, 'CREDENCIALES_INVALIDAS', 'Correo o contraseña incorrectos.');
    }

    const role = roleMap.get(String(user.role).toUpperCase());
    if (!role) {
      this.auditLogger.log({
        action: 'login_rejected',
        userId: String(user.id),
        email: user.email,
        reason: 'invalid_role',
        ...requestInfo,
      });
      throw new HttpError(403, 'ROL_INVALIDO', 'La cuenta no tiene un rol habilitado.');
    }

    this.auditLogger.log({
      action: 'login_succeeded',
      userId: String(user.id),
      email: user.email,
      role,
      ...requestInfo,
    });

    // Sin MFA activo: sesión completa de inmediato (comportamiento anterior).
    if (!this.mfa) {
      return { token: this.#token(user, role, 'acceso'), user: publicUser(user, role) };
    }

    // Orden pedido para el acceso (T8): la PRIMERA vez va primero el primer
    // acceso (contraseña y términos) con una llave limitada; después la persona
    // vuelve a iniciar sesión y recién ahí se le pide el código.
    if (user.isFirstLogin || !user.termsAccepted) {
      return {
        step: 'PRIMER_ACCESO',
        token: this.#token(user, role, 'primer_acceso', '15m'),
        user: publicUser(user, role),
      };
    }

    // Las demás veces: se envía el código y NO se entrega la sesión todavía.
    const desafio = await this.mfa.iniciar({ userId: user.id, role, email: user.email });
    return {
      step: 'MFA',
      mfaToken: desafio.mfaToken,
      email: user.email, // solo para mostrar a dónde se envió el código
      role, // para mostrar "Sesión de Colaborador en curso"
      expiraEn: desafio.expiraEn,
      reenviarDesde: desafio.reenviarDesde,
    };
  }

  // T8: el código fue correcto (lo revisó MfaService). Ahora sí se entrega la
  // sesión completa. Se vuelve a leer al usuario por si cambió algo entremedio.
  async completeMfa(desafioId, codigo, requestInfo = {}) {
    if (!this.mfa) throw new HttpError(404, 'RUTA_NO_ENCONTRADA', 'La ruta solicitada no existe.');
    const { userId } = await this.mfa.verificar(desafioId, codigo);
    const user = await this.userRepository.findById(userId);
    const role = user ? roleMap.get(String(user.role).toUpperCase()) : null;
    if (!user || !role) {
      throw new HttpError(401, 'SESION_INVALIDA', 'La sesión ya no es válida. Inicia sesión nuevamente.');
    }
    this.auditLogger.log({ action: 'mfa_login_completado', userId: String(user.id), role, ...requestInfo });
    return { token: this.#token(user, role, 'acceso'), user: publicUser(user, role) };
  }

  // RF-02: el usuario cambia su contraseña temporal o decide mantenerla.
  // Sin newPassword = "mantener la actual"; en ambos casos termina el primer acceso.
  async completeFirstAccess(id, { currentPassword, newPassword, acceptTerms, termsVersion }, requestInfo = {}) {
    const user = await this.userRepository.findById(id);
    const role = user ? roleMap.get(String(user.role).toUpperCase()) : null;
    if (!user || !role) {
      throw new HttpError(401, 'SESION_INVALIDA', 'La sesión ya no es válida. Inicia sesión nuevamente.');
    }
    if (!user.isFirstLogin) {
      throw new HttpError(409, 'PRIMER_ACCESO_COMPLETADO', 'La configuración inicial ya fue realizada.');
    }

    // RF-03: sin aceptar la versión vigente no se completa nada (el servidor manda, no la app).
    if (acceptTerms !== true || termsVersion !== TERMS_VERSION) {
      this.auditLogger.log({ action: 'terms_rejected', userId: String(user.id), ...requestInfo });
      throw new HttpError(400, 'TERMINOS_REQUERIDOS', 'Debes aceptar los Términos y Condiciones vigentes.');
    }

    const changes = {
      isFirstLogin: false,
      termsAccepted: true,
      termsVersion: TERMS_VERSION,
      termsAcceptedAt: new Date(), // evidencia del consentimiento (Ley 21.719)
    };
    if (newPassword) {
      // Seguridad: para cambiar la clave hay que demostrar que se conoce la actual.
      const matches = user.passwordHash
        ? await bcrypt.compare(currentPassword, user.passwordHash)
        : false;
      if (!matches) {
        this.auditLogger.log({ action: 'password_change_failed', userId: String(user.id), ...requestInfo });
        // 400 y no 401: un 401 haría que la app cerrara la sesión.
        throw new HttpError(400, 'CONTRASENA_ACTUAL_INCORRECTA', 'La contraseña temporal actual no es correcta.');
      }
      if (await bcrypt.compare(newPassword, user.passwordHash)) {
        throw new HttpError(400, 'CONTRASENA_REPETIDA', 'La nueva contraseña debe ser distinta de la actual.');
      }
      changes.passwordHash = await bcrypt.hash(newPassword, 12); // nunca se guarda en texto plano
    }

    const updated = await this.userRepository.update(user.id, changes);
    this.auditLogger.log({ action: 'terms_accepted', userId: String(user.id), termsVersion: TERMS_VERSION, ...requestInfo });
    this.auditLogger.log({
      action: newPassword ? 'password_changed' : 'password_kept',
      userId: String(user.id),
      ...requestInfo,
    });
    return publicUser(updated, role);
  }

  async getCurrentUser(id) {
    const user = await this.userRepository.findById(id);
    const role = user ? roleMap.get(String(user.role).toUpperCase()) : null;

    if (!user || !role) {
      throw new HttpError(401, 'SESION_INVALIDA', 'La sesión ya no es válida. Inicia sesión nuevamente.');
    }

    return publicUser(user, role);
  }
}
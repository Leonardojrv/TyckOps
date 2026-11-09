import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { HttpError } from '../../utils/http-error.js';
import { AuthAuditLogger } from './auth.audit.js';

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
  constructor(userRepository, { jwtSecret, jwtExpiresIn = '1h' }, auditLogger = new AuthAuditLogger()) {
    this.userRepository = userRepository;
    this.jwtSecret = jwtSecret;
    this.jwtExpiresIn = jwtExpiresIn;
    this.auditLogger = auditLogger;
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

    const token = jwt.sign({ role }, this.jwtSecret, {
      subject: String(user.id),
      expiresIn: this.jwtExpiresIn,
    });

    this.auditLogger.log({
      action: 'login_succeeded',
      userId: String(user.id),
      email: user.email,
      role,
      ...requestInfo,
    });

    return {
      token,
      user: publicUser(user, role),
    };
  }

  // RF-02: el usuario cambia su contraseña temporal o decide mantenerla.
  // Sin newPassword = "mantener la actual"; en ambos casos termina el primer acceso.
  async completeFirstAccess(id, { currentPassword, newPassword }, requestInfo = {}) {
    const user = await this.userRepository.findById(id);
    const role = user ? roleMap.get(String(user.role).toUpperCase()) : null;
    if (!user || !role) {
      throw new HttpError(401, 'SESION_INVALIDA', 'La sesión ya no es válida. Inicia sesión nuevamente.');
    }
    if (!user.isFirstLogin) {
      throw new HttpError(409, 'PRIMER_ACCESO_COMPLETADO', 'La configuración inicial ya fue realizada.');
    }

    const changes = { isFirstLogin: false };
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
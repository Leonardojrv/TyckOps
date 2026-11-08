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

  async getCurrentUser(id) {
    const user = await this.userRepository.findById(id);
    const role = user ? roleMap.get(String(user.role).toUpperCase()) : null;

    if (!user || !role) {
      throw new HttpError(401, 'SESION_INVALIDA', 'La sesión ya no es válida. Inicia sesión nuevamente.');
    }

    return publicUser(user, role);
  }
}
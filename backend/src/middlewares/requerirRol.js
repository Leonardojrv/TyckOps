import { HttpError } from '../utils/http-error.js';

export function requerirRol(...rolesPermitidos) {
  return (req, _res, next) => {
    if (!req.usuario || !rolesPermitidos.includes(req.usuario.role)) {
      const requiereAdministrador = rolesPermitidos.includes('ADMINISTRADOR');
      const code = requiereAdministrador ? 'SIN_ROL_ADMIN' : 'PERMISOS_INSUFICIENTES';
      const message = requiereAdministrador
        ? 'Se requiere el rol de administrador.'
        : 'No tienes permiso para esta acción.';
      return next(new HttpError(403, code, message));
    }
    return next();
  };
}
import { HttpError } from '../utils/http-error.js';

// Va después de autenticar(): corta con 403 a quien no aceptó los Términos.
export function exigirTerminos(authService) {
  return async (req, _res, next) => {
    try {
      // Sin servicio de usuarios no se puede comprobar: se bloquea (falla cerrado).
      if (!authService) {
        throw new HttpError(503, 'AUTENTICACION_NO_DISPONIBLE', 'No se pudo verificar la aceptación de Términos.');
      }
      const user = await authService.getCurrentUser(req.usuario.id);
      if (!user.termsAccepted) {
        throw new HttpError(403, 'TERMINOS_NO_ACEPTADOS', 'Debes aceptar los Términos y Condiciones.');
      }
      next();
    } catch (error) {
      next(error);
    }
  };
}

// ¿PARA QUÉ SIRVE?
//   Es un "guardia" que no deja pasar a quien no aceptó los Términos y Condiciones.
//
// ¿QUÉ HACE?
//   Antes de entrar a una ruta protegida, busca al usuario y, si no aceptó los
//   términos, corta con un error 403. Si no puede revisarlo, también bloquea
//   (prefiere cerrar la puerta antes que dejarla abierta).
//
// ¿CÓMO LO CAMBIO?
//   Para proteger una ruta nueva, agrégalo después de autenticar(), como en
//   tickets.routes.js. No lo quites de las rutas que ya lo tienen.

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

import { Router } from 'express';
import { autenticar } from '../../middlewares/autenticar.js';
import { requerirRol } from '../../middlewares/requerirRol.js';
import { responder } from '../../utils/respuestas.js';

export function crearRutasAdmin({ jwtSecret }) {
  const router = Router();

  router.get(
    '/ejemplo',
    autenticar(jwtSecret),
    requerirRol('ADMINISTRADOR'),
    (req, res) => responder(res, {
      message: 'Acceso de administrador autorizado.',
      userId: req.usuario.id,
      role: req.usuario.role,
    }),
  );

  return router;
}
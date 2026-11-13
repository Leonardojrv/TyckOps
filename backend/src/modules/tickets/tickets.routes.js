import { Router } from 'express';
import { autenticar } from '../../middlewares/autenticar.js';
import { exigirTerminos } from '../../middlewares/exigirTerminos.js';
import { requerirRol } from '../../middlewares/requerirRol.js';
import { HttpError } from '../../utils/http-error.js';
import { responder } from '../../utils/respuestas.js';

// Tickets del colaborador (T5 home, T7 lista y detalle). Solo lectura.
export function crearRutasTickets({ ticketService, authService, jwtSecret }) {
  const router = Router();
  // Toda la ruta exige: sesión válida + rol colaborador + términos aceptados.
  router.use(autenticar(jwtSecret), requerirRol('COLABORADOR'), exigirTerminos(authService));
  router.use((_req, _res, next) => next(ticketService
    ? undefined
    : new HttpError(503, 'TICKETS_NO_DISPONIBLES', 'Los tickets aún no están disponibles.')));

  // El dueño sale del token firmado (req.usuario.id), NUNCA de la URL o del body.
  router.get('/mis-tickets', async (req, res) => {
    responder(res, await ticketService.misTickets(req.usuario.id));
  });

  router.get('/:id', async (req, res) => {
    responder(res, { ticket: await ticketService.detalle(req.usuario.id, req.params.id) });
  });

  return router;
}

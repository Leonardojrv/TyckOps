import { Router } from 'express';
import { z } from 'zod';
import { autenticar } from '../../middlewares/autenticar.js';
import { exigirTerminos } from '../../middlewares/exigirTerminos.js';
import { requerirRol } from '../../middlewares/requerirRol.js';
import { HttpError } from '../../utils/http-error.js';
import { responder } from '../../utils/respuestas.js';

const prioridadSchema = z.object({
  prioridad: z.string({ required_error: 'Indica la prioridad.' })
    .trim()
    .toUpperCase()
    .pipe(z.enum(['BAJA', 'MEDIA', 'ALTA'], { errorMap: () => ({ message: 'La prioridad debe ser baja, media o alta.' }) })),
});

export function crearRutasAdmin({ jwtSecret, authService, ticketService = null }) {
  const router = Router();
  const soloAdmin = [autenticar(jwtSecret), requerirRol('ADMINISTRADOR'), exigirTerminos(authService)];

  router.get(
    '/ejemplo',
    ...soloAdmin,
    (req, res) => responder(res, {
      message: 'Acceso de administrador autorizado.',
      userId: req.usuario.id,
      role: req.usuario.role,
    }),
  );

  // MM2 · El administrador cambia (escala) la prioridad de un ticket.
  // Queda registrado quién y cuándo (tabla CambioPrioridad).
  router.patch('/tickets/:id/prioridad', ...soloAdmin, async (req, res) => {
    if (!ticketService) throw new HttpError(503, 'TICKETS_NO_DISPONIBLES', 'Los tickets aún no están disponibles.');
    const datos = prioridadSchema.safeParse(req.body ?? {});
    if (!datos.success) {
      throw new HttpError(400, 'DATOS_INVALIDOS', datos.error.issues[0]?.message ?? 'Revisa los datos enviados.');
    }
    const ticket = await ticketService.cambiarPrioridad(req.usuario.id, req.params.id, datos.data.prioridad);
    responder(res, { ticket });
  });

  return router;
}

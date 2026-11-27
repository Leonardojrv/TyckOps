import { Router } from 'express';
import { z } from 'zod';
import { autenticar } from '../../middlewares/autenticar.js';
import { exigirTerminos } from '../../middlewares/exigirTerminos.js';
import { requerirRol } from '../../middlewares/requerirRol.js';
import { HttpError } from '../../utils/http-error.js';
import { responder } from '../../utils/respuestas.js';
import { ESTADOS_ADMINISTRADOR } from '../tickets/ticket-states.js';

const prioridadSchema = z.object({
  prioridad: z.string({ required_error: 'Indica la prioridad.' })
    .trim()
    .toUpperCase()
    .pipe(z.enum(['BAJA', 'MEDIA', 'ALTA'], { errorMap: () => ({ message: 'La prioridad debe ser baja, media o alta.' }) })),
});

// T11 · Cambio de estado. Al rechazar, el motivo es obligatorio (RF-17) y la
// base de datos exige al menos 100 caracteres (ck_ticket_motivo_rechazo).
const estadoSchema = z.object({
  estado: z.string({ required_error: 'Indica el estado.' }).trim().toUpperCase()
    .pipe(z.enum(ESTADOS_ADMINISTRADOR, {
      errorMap: () => ({ message: 'Estado no válido.' }),
    })),
  motivo: z.string().trim().max(255, 'El motivo admite hasta 255 caracteres.').optional(),
});

// T11 · Comentario del administrador (0/500 como en el mockup).
const comentarioSchema = z.object({
  texto: z.string({ required_error: 'Escribe el comentario.' }).trim()
    .min(1, 'Escribe el comentario.').max(500, 'El comentario admite hasta 500 caracteres.'),
});

// T13 · personalRepository: listado de personal y números del Home del administrador.
export function crearRutasAdmin({ jwtSecret, authService, ticketService = null, personalRepository = null }) {
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

  // T11 · Cambiar el estado de un ticket: el dueño recibe una notificación push.
  router.patch('/tickets/:id/estado', ...soloAdmin, async (req, res) => {
    if (!ticketService) throw new HttpError(503, 'TICKETS_NO_DISPONIBLES', 'Los tickets aún no están disponibles.');
    const datos = estadoSchema.safeParse(req.body ?? {});
    if (!datos.success) {
      throw new HttpError(400, 'DATOS_INVALIDOS', datos.error.issues[0]?.message ?? 'Revisa los datos enviados.');
    }
    const ticket = await ticketService.cambiarEstado(req.usuario.id, req.params.id, datos.data.estado, datos.data.motivo ?? null);
    responder(res, { ticket });
  });

  // T11 · Comentar un ticket: el dueño recibe "Nuevo comentario en tu ticket".
  router.post('/tickets/:id/comentarios', ...soloAdmin, async (req, res) => {
    if (!ticketService) throw new HttpError(503, 'TICKETS_NO_DISPONIBLES', 'Los tickets aún no están disponibles.');
    const datos = comentarioSchema.safeParse(req.body ?? {});
    if (!datos.success) {
      throw new HttpError(400, 'DATOS_INVALIDOS', datos.error.issues[0]?.message ?? 'Revisa los datos enviados.');
    }
    const comentario = await ticketService.comentar(req.usuario.id, req.params.id, datos.data.texto);
    responder(res, { comentario }, 201);
  });

  // T13 · Home del administrador: pendientes, urgentes, duplicados, activos y personal.
  router.get('/resumen', ...soloAdmin, async (_req, res) => {
    if (!personalRepository) throw new HttpError(503, 'PERSONAL_NO_DISPONIBLE', 'El resumen aún no está disponible.');
    responder(res, await personalRepository.resumen());
  });

  // T13 · Listado de personal (nombre, correo, área, rol y resumen de tickets).
  // Solo para administradores: nunca se entregan contraseñas ni teléfonos.
  router.get('/personal', ...soloAdmin, async (_req, res) => {
    if (!personalRepository) throw new HttpError(503, 'PERSONAL_NO_DISPONIBLE', 'El listado aún no está disponible.');
    responder(res, { personal: await personalRepository.listar() });
  });

  return router;
}

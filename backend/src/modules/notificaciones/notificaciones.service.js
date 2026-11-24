// ¿PARA QUÉ SIRVE?
//   Es el "cerebro" de las notificaciones push (T11): qué se avisa, con qué
//   texto y a qué celulares.
//
// ¿QUÉ HACE?
//   - Registra y quita los celulares (tokens) de cada persona.
//   - Avisa al dueño del ticket cuando el administrador cambia el estado o
//     escribe un comentario: guarda el aviso (para la pantalla Notificaciones)
//     y lo manda por push a todos sus celulares.
//   - Lista los avisos y los marca como leídos.
//   Un error al avisar NUNCA hace fallar la acción del administrador: el
//   cambio de estado o el comentario ya quedaron guardados.
//
// ¿CÓMO LO CAMBIO?
//   Los textos de cada aviso están en `textoEstado` y `textoComentario`. Por
//   el push viajan solo ids y el tipo (nada de datos personales).

import { logger } from '../../config/logger.js';

const NOMBRE_ESTADO = {
  RECIBIDO: 'Recibido',
  EN_REVISION: 'En revisión',
  APROBADO: 'Aprobado',
  RECHAZADO: 'Rechazado',
  EN_PROCESO: 'En proceso',
  RESUELTO: 'Resuelto',
  CERRADO: 'Cerrado',
  CANCELADO: 'Cancelado',
};

// Lo que el colaborador entiende de cada estado (segunda línea del aviso).
const DETALLE_ESTADO = {
  EN_REVISION: 'Servicios Generales está evaluando tu solicitud.',
  APROBADO: 'Tu solicitud fue aprobada y pronto se asignará un técnico.',
  EN_PROCESO: 'El equipo técnico está trabajando en la reparación.',
  RESUELTO: 'La reparación terminó. Revisa que todo funcione bien.',
  CERRADO: 'La solicitud fue cerrada por Servicios Generales.',
};

function recortar(texto, max) {
  const t = String(texto ?? '').replace(/\s+/g, ' ').trim();
  return t.length > max ? `${t.slice(0, max - 1)}…` : t;
}

/** Texto del aviso "Actualización de estado". */
export function textoEstado(codigo, estado, motivo = null) {
  const nombre = NOMBRE_ESTADO[estado] ?? estado;
  const detalle = estado === 'RECHAZADO' && motivo
    ? `Motivo: ${recortar(motivo, 120)}`
    : DETALLE_ESTADO[estado] ?? '';
  return {
    titulo: `Ticket #${codigo} pasó a "${nombre}"`,
    cuerpo: recortar(`Tu ticket #${codigo} cambió a "${nombre}". ${detalle}`, 300),
  };
}

/** Texto del aviso "Nuevo comentario en tu ticket". */
export function textoComentario(codigo, comentario) {
  return {
    titulo: 'Nuevo comentario en tu ticket',
    cuerpo: recortar(`#${codigo}: ${comentario}`, 300),
  };
}

export class NotificacionesService {
  constructor(repo, enviador) {
    this.repo = repo;
    this.enviador = enviador;
  }

  registrarDispositivo(userId, token, plataforma) {
    return this.repo.registrarToken(userId, token, plataforma);
  }

  quitarDispositivo(userId, token) {
    return this.repo.quitarToken(userId, token);
  }

  listar(userId) {
    return this.repo.listar(userId);
  }

  marcarLeidas(userId, id = null) {
    return this.repo.marcarLeidas(userId, id);
  }

  /** El administrador cambió el estado del ticket. */
  avisarCambioEstado(ticket, estado, motivo = null) {
    return this.#notificar({
      userId: ticket.ownerId,
      ticket,
      tipo: 'estado',
      estado,
      texto: textoEstado(ticket.code, estado, motivo),
    });
  }

  /** El administrador escribió un comentario en el ticket. */
  avisarComentario(ticket, comentario) {
    return this.#notificar({
      userId: ticket.ownerId,
      ticket,
      tipo: 'comentario',
      comentarioId: comentario.id,
      texto: textoComentario(ticket.code, comentario.text),
    });
  }

  async #notificar({ userId, ticket, tipo, estado = null, comentarioId = null, texto }) {
    try {
      // 1) Queda guardado para la pantalla "Notificaciones" (aunque el push falle).
      const notificacion = await this.repo.crear({
        userId,
        ticketId: ticket.id,
        codigo: ticket.code,
        tipo,
        estado,
        comentarioId,
        ...texto,
      });
      // 2) Push a todos los celulares del dueño. Solo viajan ids y el tipo.
      const tokens = await this.repo.tokensDe(userId);
      const { invalidos } = await this.enviador.enviar(tokens, {
        titulo: texto.titulo,
        cuerpo: texto.cuerpo,
        datos: {
          tipo,
          ticketId: String(ticket.id),
          notificacionId: notificacion.id,
          ...(comentarioId && { comentarioId: String(comentarioId) }),
        },
      });
      await this.repo.borrarTokens(invalidos); // apps desinstaladas o tokens vencidos
      return notificacion;
    } catch (error) {
      logger.warn('notificacion_fallida', { tipo: 'notificacion', ticketId: String(ticket.id), clase: tipo, error: error.message });
      return null;
    }
  }
}

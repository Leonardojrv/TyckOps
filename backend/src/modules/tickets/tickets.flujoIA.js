// Regla de negocio: qué tickets se envían al motor de IA para su análisis.
//
// Solo se analizan los tickets en estado Recibido: todavía nadie los ha
// tomado. Si el administrador ya lo pasó a En revisión (o más adelante) o el
// trabajador lo canceló, analizarlo gastaría cuota de Groq sin sentido y
// podría pisar lo que ya decidió el administrador.
//
// Esta regla SOLO LEE el estado: nunca lo cambia. Los estados los cambian el
// Sistema (al crear), el Administrador y el Trabajador (ver
// docs/requerimientos/requerimientos-funcionales.md).

const ESTADO_ANALIZABLE = 'RECIBIDO';

// "recibido" (BD) o "RECIBIDO" (API) -> "RECIBIDO", para comparar sin importar
// de qué repositorio venga el ticket.
function normalizarEstado(estado) {
  return String(estado ?? '').trim().replace(/\s+/g, '_').toUpperCase();
}

/**
 * Decide si un ticket debe ir al motor de IA.
 * @returns {{ enviar: true } | { enviar: false, motivo: string }}
 */
export function evaluarFlujoIA(ticket) {
  const estado = normalizarEstado(ticket?.status);
  if (estado !== ESTADO_ANALIZABLE) {
    return { enviar: false, motivo: `estado_${estado.toLowerCase() || 'desconocido'}` };
  }
  return { enviar: true };
}

/**
 * Datos mínimos que se mandan al motor de IA (servicio externo).
 * Sin ownerId, nombre ni foto: solo lo necesario para clasificar la falla.
 */
export function datosParaIA(ticket) {
  return {
    ticketId: String(ticket.id),
    categoria: ticket.category,
    descripcion: ticket.description ?? ticket.title,
    ubicacion: ticket.location,
  };
}

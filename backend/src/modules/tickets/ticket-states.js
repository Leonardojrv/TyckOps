import { HttpError } from '../../utils/http-error.js';

export const TRANSICIONES_TICKET = Object.freeze({
  RECIBIDO: Object.freeze(['EN_REVISION', 'CANCELADO', 'AUTOGESTION']),
  EN_REVISION: Object.freeze(['APROBADO', 'RECHAZADO']),
  APROBADO: Object.freeze(['EN_PROCESO']),
  EN_PROCESO: Object.freeze(['RESUELTO']),
  RESUELTO: Object.freeze(['CERRADO']),
  AUTOGESTION: Object.freeze(['CERRADO', 'RECIBIDO']),
  RECHAZADO: Object.freeze([]),
  CERRADO: Object.freeze([]),
  CANCELADO: Object.freeze([]),
});

export const ESTADOS_ADMINISTRADOR = Object.freeze([
  'EN_REVISION',
  'APROBADO',
  'RECHAZADO',
  'EN_PROCESO',
  'RESUELTO',
  'CERRADO',
]);

export function validarTransicion(estadoAnterior, estadoNuevo, motivo = null) {
  if (!TRANSICIONES_TICKET[estadoAnterior]?.includes(estadoNuevo)) {
    throw new HttpError(
      409,
      'TRANSICION_NO_PERMITIDA',
      `Un ticket "${estadoAnterior}" no puede pasar a "${estadoNuevo}".`,
    );
  }
  if (estadoNuevo === 'RECHAZADO' && (typeof motivo !== 'string' || motivo.trim().length < 100)) {
    throw new HttpError(400, 'MOTIVO_RECHAZO_INVALIDO', 'Al rechazar, explica el motivo (mínimo 100 caracteres).');
  }
  if (motivo !== null && String(motivo).trim().length > 255) {
    throw new HttpError(400, 'MOTIVO_INVALIDO', 'El motivo admite hasta 255 caracteres.');
  }
}

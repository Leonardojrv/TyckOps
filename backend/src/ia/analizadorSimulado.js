// ¿PARA QUÉ SIRVE?
//   Reemplaza a la IA (Groq) mientras el servidor no tenga GROQ_API_KEY
//   (T10: "mientras tanto usa una respuesta simulada"). Así la detección de
//   duplicados y la guía de autoayuda funcionan igual en desarrollo.
//
// ¿QUÉ HACE?
//   - Duplicados: un ticket nuevo es duplicado si hay otro ACTIVO en la misma
//     ubicación con una descripción parecida ("no prende" ≈ "no quiere
//     prender"). El original es el más antiguo. Puede ser tuyo o de otra persona.
//   - Guía: si la descripción calza con una falla simple conocida (ver
//     tickets.guia.js), el analizador de prioridad la deja en Baja con su guía.
//     Las palabras de riesgo (humo, chispa...) las revisa antes ese analizador.
//   Todo con reglas fijas: no se envía nada a servicios externos.
//
// ¿CÓMO LO CAMBIO?
//   - Más o menos estricto con los duplicados: cambia UMBRAL_SIMILITUD (0 a 1).
//   - Palabras que no cuentan al comparar: PALABRAS_VACIAS.
//   - En cuanto exista GROQ_API_KEY, server.js usa la IA real y esto se deja de usar.

import { buscarProblemaSimple, textoPlano } from '../modules/tickets/tickets.guia.js';

/** Qué tan parecidas deben ser dos descripciones (0 a 1) para ser la misma falla. */
export const UMBRAL_SIMILITUD = 0.5;

// Palabras que no ayudan a distinguir una falla de otra.
const PALABRAS_VACIAS = new Set([
  'el', 'la', 'los', 'las', 'un', 'una', 'unos', 'unas', 'de', 'del', 'en', 'y', 'o', 'a', 'al', 'mi', 'mis',
  'se', 'que', 'por', 'con', 'para', 'es', 'esta', 'este', 'esto', 'muy', 'ya', 'quiere', 'puede', 'hay',
  'su', 'sus', 'lo', 'le', 'me', 'nos',
]);

// "prender" y "prende" comparten raíz: se comparan los primeros 5 caracteres.
function raices(texto) {
  return new Set(
    textoPlano(texto)
      .split(' ')
      .filter((p) => p.length > 1 && !PALABRAS_VACIAS.has(p))
      .map((p) => p.slice(0, 5)),
  );
}

/** Parecido entre dos descripciones: palabras en común / palabras distintas (0 a 1). */
export function similitud(a, b) {
  const x = raices(a);
  const y = raices(b);
  if (!x.size || !y.size) return 0;
  let comunes = 0;
  for (const r of x) if (y.has(r)) comunes += 1;
  return comunes / (x.size + y.size - comunes);
}

/** Misma ubicación sin importar mayúsculas, tildes, comas ni espacios. */
export function mismaUbicacion(a, b) {
  const x = textoPlano(a).replace(/\s/g, '');
  const y = textoPlano(b).replace(/\s/g, '');
  return Boolean(x) && x === y;
}

/** Reemplazo de AnalizadorTicket (duplicados + guía) sin IA. */
export class AnalizadorSimulado {
  constructor({ ticketRepository = null } = {}) {
    this.ticketRepository = ticketRepository;
  }

  async analizar(ticket) {
    const ticketId = String(ticket.ticketId ?? ticket.id ?? '');
    const descripcion = ticket.descripcion ?? ticket.description ?? ticket.title ?? '';
    const ubicacion = ticket.ubicacion ?? ticket.location ?? '';

    let candidatos = [];
    if (this.ticketRepository?.findActiveCandidates) {
      candidatos = await this.ticketRepository.findActiveCandidates({ location: ubicacion, excludeId: ticketId });
    }

    // El más antiguo de los parecidos es el original. Si ese ya era un duplicado,
    // se agrupa con SU original (nunca se arman cadenas de duplicados).
    const original = candidatos
      .filter((c) => String(c.id) !== ticketId)
      .filter((c) => mismaUbicacion(c.location, ubicacion) && similitud(c.title, descripcion) >= UMBRAL_SIMILITUD)
      .sort((a, b) => new Date(a.createdAt) - new Date(b.createdAt))[0];

    return {
      ticketId,
      duplicado: original
        ? {
            esDuplicado: true,
            ticketOriginalId: String(original.originalId ?? original.id),
            confianza: Number(similitud(original.title, descripcion).toFixed(2)),
            instruccionesEnTexto: false,
            motivo: 'Respuesta simulada: misma ubicación y descripción parecida.',
          }
        : {
            esDuplicado: false,
            ticketOriginalId: null,
            confianza: 1,
            instruccionesEnTexto: false,
            motivo: 'Respuesta simulada: no hay tickets activos parecidos en la misma ubicación.',
          },
      // La guía la decide el analizador de prioridad con buscadorGuiasSimulado.
      guia: { aplicable: false, guia: null, desviadoPorRiesgo: false, palabraRiesgo: null, motivo: 'simulado' },
    };
  }
}

/**
 * "Buscador de guías" para AnalizadorPrioridad: si el texto calza con una falla
 * simple, devuelve su id (y el ticket queda en prioridad Baja con guía).
 */
export const buscadorGuiasSimulado = {
  async buscar(datos) {
    const problema = buscarProblemaSimple(datos?.descripcion ?? datos?.description ?? '');
    return problema ? { id: problema.id } : null;
  },
};

// ¿PARA QUÉ SIRVE?
//   Palabras de RIESGO para la prioridad inicial (MM2, regla de seguridad).
//
// ¿QUÉ HACE?
//   Si la descripción o la ubicación tienen una de estas palabras (chispas,
//   humo, olor a quemado, fuga...), el ticket NUNCA queda en baja ni se le
//   ofrecen pasos de autoayuda: la prioridad sale de las reglas, o media.
//
// ¿CÓMO LO CAMBIO?
//   Agrega o quita palabras en RIESGO y corre `pnpm test`. Escríbelas en
//   minúsculas y sin tildes: el texto se normaliza antes de comparar.

const RIESGO = [
  ['chispas', /\bchispa/],
  ['humo', /\bhumo\b/],
  ['olor a quemado', /\bolor a quemad|\bhuele a quemad/],
  ['fuego', /\b(fuego|incendio|llamas?)\b/],
  ['fuga', /\bfuga/],
  ['olor a gas', /\b(olor a gas|huele a gas)\b/],
  ['cortocircuito', /\bcorto ?circuito/],
  ['descarga electrica', /\b(descarga electrica|electrocut|me dio la corriente|da la corriente)/],
  ['cable expuesto', /\bcables? (expuest|pelad|colgand)/],
  ['inundacion', /\b(inund|anegad)/],
];

// "Sacó CHISPAS el enchufe" -> "saco chispas el enchufe"
export function normalizarTexto(texto) {
  return String(texto ?? '')
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/\s+/g, ' ')
    .trim();
}

/** Nombre de la primera palabra de riesgo encontrada, o null. */
export function detectarRiesgo({ descripcion, ubicacion } = {}) {
  const texto = normalizarTexto(`${descripcion ?? ''} ${ubicacion ?? ''}`);
  const hallazgo = RIESGO.find(([, patron]) => patron.test(texto));
  return hallazgo ? hallazgo[0] : null;
}

// Filtro de seguridad (Safety Check) para desviar fallas críticas
// antes de cualquier consulta a la IA o asistencia de autoayuda.
// Palabras y expresiones clave que implican peligro físico, estructural o eléctrico.

export const PALABRAS_RIESGO = [
  'chispas',
  'chispa',
  'humo',
  'olor a quemado',
  'quemado',
  'fuga',
  'fugas',
  'inundacion',
  'inundaciones',
  'fuego',
  'llamas',
  'cortocircuito',
  'corto circuito',
  'electrocut',
];

/**
 * Normaliza un texto para búsqueda (minúsculas, sin tildes, sin caracteres raros).
 */
function normalizarTexto(texto) {
  if (!texto || typeof texto !== 'string') return '';
  return texto
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/\s+/g, ' ')
    .trim();
}

/**
 * Revisa si el texto de la falla contiene alguna palabra o frase de riesgo.
 * Si se detecta riesgo, el ticket se desvía inmediatamente a atención técnica sin pasar por la IA.
 * 
 * @param {string} texto - Descripción o título de la falla
 * @returns {{ tieneRiesgo: boolean, palabra: string | null }}
 */
export function detectarRiesgo(texto) {
  const norm = normalizarTexto(texto);
  if (!norm) return { tieneRiesgo: false, palabra: null };

  for (const palabra of PALABRAS_RIESGO) {
    const palabraNorm = normalizarTexto(palabra);
    // Búsqueda de palabra completa o frase exacta dentro del texto
    const regex = new RegExp(`(^|[^a-z0-9])${palabraNorm}([^a-z0-9]|$)`, 'i');
    if (regex.test(norm)) {
      return { tieneRiesgo: true, palabra };
    }
  }

  return { tieneRiesgo: false, palabra: null };
}

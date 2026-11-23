// Sanitización y normalización de textos para guías de autoayuda

export const CATEGORIAS_VALIDAS = {
  ELECTRICA: 'Eléctrica',
  BANOS: 'Baños',
  AIRE_ACONDICIONADO: 'Aire acondicionado',
  INMOBILIARIO: 'Inmobiliario',
};

const ALIAS_CATEGORIA = {
  electrica: 'ELECTRICA',
  electricidad: 'ELECTRICA',
  banos: 'BANOS',
  bano: 'BANOS',
  aire_acondicionado: 'AIRE_ACONDICIONADO',
  aireacondicionado: 'AIRE_ACONDICIONADO',
  clima: 'AIRE_ACONDICIONADO',
  climatizacion: 'AIRE_ACONDICIONADO',
  inmobiliario: 'INMOBILIARIO',
  mobiliario: 'INMOBILIARIO',
  muebles: 'INMOBILIARIO',
};

/**
 * Quita cualquier etiqueta HTML (<script>, <b>, <p>, etc.) y decodifica entidades comunes.
 * También elimina el contenido completo de bloques <script>...</script> y <style>...</style>.
 */
export function quitarHtml(valor) {
  if (valor === null || valor === undefined) return '';
  return String(valor)
    .replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, '') // Contenido de scripts
    .replace(/<style\b[^<]*(?:(?!<\/style>)<[^<]*)*<\/style>/gi, '') // Contenido de styles
    .replace(/<[^>]*>/g, '') // Elimina etiquetas HTML restantes
    .replace(/&nbsp;/gi, ' ')
    .replace(/&amp;/gi, '&')
    .replace(/&lt;/gi, '<')
    .replace(/&gt;/gi, '>')
    .replace(/&quot;/gi, '"')
    .replace(/&#39;/gi, "'")
    .replace(/[\u0000-\u0009\u000B-\u001F\u007F]/g, ' ') // Caracteres de control
    .trim();
}

/**
 * Normaliza y valida una categoría contra las 4 del sistema.
 * @returns {string|null} Código normalizado (ej: 'ELECTRICA') o null si no es válida.
 */
export function normalizarCategoria(valor) {
  if (!valor) return null;
  const textoLimpio = quitarHtml(valor)
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .trim()
    .toLowerCase()
    .replace(/[\s-]+/g, '_');

  return ALIAS_CATEGORIA[textoLimpio] ?? (CATEGORIAS_VALIDAS[textoLimpio.toUpperCase()] ? textoLimpio.toUpperCase() : null);
}

/**
 * Interpreta un valor como booleano para autogestionable (SI/NO, true/false, 1/0).
 * @returns {boolean|null} true/false o null si el valor no es reconocible.
 */
export function normalizarBooleano(valor) {
  if (typeof valor === 'boolean') return valor;
  if (typeof valor === 'number') {
    if (valor === 1) return true;
    if (valor === 0) return false;
    return null;
  }
  if (!valor) return null;
  const texto = String(valor)
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .trim()
    .toLowerCase();

  if (['si', 's', 'true', 'verdadero', '1', 'yes', 'y'].includes(texto)) return true;
  if (['no', 'n', 'false', 'falso', '0'].includes(texto)) return false;
  return null;
}

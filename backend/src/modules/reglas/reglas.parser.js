// ¿PARA QUÉ SIRVE?
//   Lee y valida el archivo .txt de reglas de prioridad que sube el administrador (MM2).
//
// ¿QUÉ HACE?
//   Una regla por línea, cuatro campos separados por "|":
//
//       id | categoria | prioridad | descripcion
//       ELE-01 | Electrica | alta | Enchufe o tablero que saca chispas o huele a quemado
//       BAN-02 | Banos | media | Fuga de agua que no se puede cortar con la llave de paso
//
//   - Las líneas vacías y las que empiezan con "#" se ignoran (comentarios).
//   - La línea de encabezado "id | categoria | prioridad | descripcion" es opcional.
//   - categoria: Electrica, Banos, Aire acondicionado o Inmobiliario (con o sin tildes).
//   - prioridad: solo "alta" o "media". La "baja" la da una guía de autoayuda, no una regla.
//   - id: único en el archivo, letras, números, "-" o "_" (máx. 30).
//   Devuelve TODOS los errores juntos, cada uno con su número de línea.
//
// ¿CÓMO LO CAMBIO?
//   Si Servicios Generales entrega otro formato, ajusta `leerLinea` y los tests
//   de test/reglas.test.js.

export const CATEGORIAS = ['ELECTRICA', 'BANOS', 'AIRE_ACONDICIONADO', 'INMOBILIARIO'];
export const PRIORIDADES_REGLA = ['ALTA', 'MEDIA'];

export const MAX_BYTES_REGLAS = 200 * 1024;
const MAX_REGLAS = 500;
const MAX_DESCRIPCION = 300;
const ID_VALIDO = /^[A-Za-z0-9_-]{1,30}$/;

// Nombres que puede escribir el administrador -> código de la app.
const ALIAS_CATEGORIA = {
  ELECTRICA: 'ELECTRICA',
  ELECTRICIDAD: 'ELECTRICA',
  BANOS: 'BANOS',
  BANO: 'BANOS',
  AIRE_ACONDICIONADO: 'AIRE_ACONDICIONADO',
  INMOBILIARIO: 'INMOBILIARIO',
  MOBILIARIO: 'INMOBILIARIO',
  INMOVILIARIO: 'INMOBILIARIO',
};

// "Baños" / "aire  acondicionado" -> "BANOS" / "AIRE_ACONDICIONADO"
function codigo(texto) {
  return String(texto ?? '')
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .trim()
    .replace(/\s+/g, '_')
    .toUpperCase();
}

/** Código de categoría de la app a partir de un nombre (o null si no es válida). */
export function codigoCategoria(nombre) {
  return ALIAS_CATEGORIA[codigo(nombre)] ?? null;
}

function esEncabezado(campos) {
  return campos.length >= 3 && codigo(campos[0]) === 'ID' && codigo(campos[1]) === 'CATEGORIA';
}

/**
 * Convierte el texto del .txt en reglas validadas.
 * @param {string} texto
 * @returns {{ ok: true, reglas: Array<{id, categoria, prioridad, descripcion, linea}> }
 *         | { ok: false, errores: Array<{ linea: number|null, campo: string|null, mensaje: string }> }}
 */
export function parsearReglas(texto) {
  const errores = [];
  const reglas = [];
  const vistos = new Map(); // id en mayúsculas -> línea donde apareció
  const lineas = String(texto ?? '').replace(/^﻿/, '').split(/\r?\n/);
  let encabezadoRevisado = false;

  lineas.forEach((original, indice) => {
    const linea = indice + 1;
    const contenido = original.trim();
    if (!contenido || contenido.startsWith('#')) return;

    // La descripción puede traer "|": todo lo que sigue al tercer separador es descripción.
    const partes = contenido.split('|').map((parte) => parte.trim());
    if (!encabezadoRevisado) {
      encabezadoRevisado = true;
      if (esEncabezado(partes)) return;
    }

    if (partes.length < 4) {
      errores.push({ linea, campo: null, mensaje: 'Faltan campos: se esperan 4 separados por "|" (id | categoria | prioridad | descripcion).' });
      return;
    }
    const [id, categoriaTexto, prioridadTexto, ...resto] = partes;
    const descripcion = resto.join(' | ').trim();
    const erroresLinea = [];

    if (!id) erroresLinea.push({ campo: 'id', mensaje: 'El id es obligatorio.' });
    else if (!ID_VALIDO.test(id)) erroresLinea.push({ campo: 'id', mensaje: `El id "${id.slice(0, 40)}" solo puede tener letras, números, "-" o "_" (máx. 30).` });
    else if (vistos.has(id.toUpperCase())) erroresLinea.push({ campo: 'id', mensaje: `El id "${id}" ya se usó en la línea ${vistos.get(id.toUpperCase())}.` });

    const categoria = codigoCategoria(categoriaTexto);
    if (!categoriaTexto) erroresLinea.push({ campo: 'categoria', mensaje: 'La categoría es obligatoria.' });
    else if (!categoria) erroresLinea.push({ campo: 'categoria', mensaje: `Categoría "${categoriaTexto.slice(0, 40)}" no válida. Usa: Electrica, Banos, Aire acondicionado o Inmobiliario.` });

    const prioridad = codigo(prioridadTexto);
    if (!prioridadTexto) erroresLinea.push({ campo: 'prioridad', mensaje: 'La prioridad es obligatoria.' });
    else if (prioridad === 'BAJA') erroresLinea.push({ campo: 'prioridad', mensaje: 'Una regla no puede ser "baja": la prioridad baja la da una guía de autoayuda. Usa "alta" o "media".' });
    else if (!PRIORIDADES_REGLA.includes(prioridad)) erroresLinea.push({ campo: 'prioridad', mensaje: `Prioridad "${prioridadTexto.slice(0, 20)}" no válida. Usa "alta" o "media".` });

    if (!descripcion) erroresLinea.push({ campo: 'descripcion', mensaje: 'La descripción es obligatoria: es lo que lee la IA para elegir la regla.' });
    else if (descripcion.length > MAX_DESCRIPCION) erroresLinea.push({ campo: 'descripcion', mensaje: `La descripción supera los ${MAX_DESCRIPCION} caracteres.` });

    if (erroresLinea.length) {
      errores.push(...erroresLinea.map((error) => ({ linea, ...error })));
      return;
    }
    vistos.set(id.toUpperCase(), linea);
    reglas.push({ id, categoria, prioridad, descripcion, linea });
  });

  if (!errores.length && reglas.length === 0) {
    errores.push({ linea: null, campo: null, mensaje: 'El archivo no tiene reglas.' });
  }
  if (reglas.length > MAX_REGLAS) {
    errores.push({ linea: null, campo: null, mensaje: `El archivo tiene ${reglas.length} reglas; el máximo es ${MAX_REGLAS}.` });
  }
  return errores.length ? { ok: false, errores } : { ok: true, reglas };
}

/** Bytes del archivo -> texto. Rechaza lo que no sea UTF-8 válido (p. ej. un binario renombrado). */
export function decodificarTexto(buffer) {
  try {
    const texto = new TextDecoder('utf-8', { fatal: true }).decode(buffer);
    return texto.includes('\u0000') ? null : texto;
  } catch {
    return null;
  }
}

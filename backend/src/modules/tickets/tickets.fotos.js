import { randomUUID } from 'node:crypto';
import { mkdir, readFile, readdir, rm, writeFile } from 'node:fs/promises';
import path from 'node:path';

// RF-04: hasta tres fotos por reporte, JPG o PNG, máximo 5 MB cada una.
export const MAX_FOTO_BYTES = 5 * 1024 * 1024;
export const MAX_FOTOS = 3;

const FIRMA_JPG = [0xff, 0xd8, 0xff];
const FIRMA_PNG = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];

function empiezaCon(buffer, firma) {
  return buffer.length > firma.length && firma.every((byte, i) => buffer[i] === byte);
}

// El tipo se decide por los primeros bytes del archivo (su "firma"), no por el
// nombre ni por el Content-Type que manda el cliente: esos se pueden falsificar.
export function detectarTipoImagen(buffer) {
  if (!Buffer.isBuffer(buffer)) return null;
  if (empiezaCon(buffer, FIRMA_JPG)) return { ext: 'jpg', mime: 'image/jpeg' };
  if (empiezaCon(buffer, FIRMA_PNG)) return { ext: 'png', mime: 'image/png' };
  return null;
}

// Privacidad: las fotos del celular traen metadatos EXIF (modelo, fecha y a veces
// la ubicación GPS de quien la tomó). Se borran antes de guardar.
// JPG: se quitan los segmentos APP1 (EXIF/XMP), APP13 (IPTC) y comentarios.
function limpiarJpg(buffer) {
  const partes = [buffer.subarray(0, 2)]; // FFD8 (inicio de imagen)
  let i = 2;
  while (i + 4 <= buffer.length) {
    if (buffer[i] !== 0xff) return null; // estructura inválida
    const marcador = buffer[i + 1];
    if (marcador === 0xff) {
      i += 1; // byte de relleno permitido por el formato
      continue;
    }
    if (marcador === 0xda) {
      // Inicio de los datos de la imagen: desde aquí se copia todo tal cual.
      partes.push(buffer.subarray(i));
      return Buffer.concat(partes);
    }
    const largo = buffer.readUInt16BE(i + 2);
    if (largo < 2 || i + 2 + largo > buffer.length) return null;
    const esMetadato = marcador === 0xe1 || marcador === 0xed || marcador === 0xfe;
    if (!esMetadato) partes.push(buffer.subarray(i, i + 2 + largo));
    i += 2 + largo;
  }
  return null;
}

// PNG: se quitan los bloques de texto y EXIF (tEXt, zTXt, iTXt, eXIf).
const BLOQUES_PNG_METADATOS = new Set(['tEXt', 'zTXt', 'iTXt', 'eXIf']);

function limpiarPng(buffer) {
  const partes = [buffer.subarray(0, 8)];
  let i = 8;
  while (i + 12 <= buffer.length) {
    const largo = buffer.readUInt32BE(i);
    const tipo = buffer.toString('latin1', i + 4, i + 8);
    const fin = i + 12 + largo;
    if (fin > buffer.length) return null;
    if (!BLOQUES_PNG_METADATOS.has(tipo)) partes.push(buffer.subarray(i, fin));
    i = fin;
    if (tipo === 'IEND') return Buffer.concat(partes);
  }
  return null;
}

/** Devuelve la imagen sin metadatos, o null si el archivo está dañado. */
export function quitarMetadatos(buffer, tipo) {
  return tipo.ext === 'jpg' ? limpiarJpg(buffer) : limpiarPng(buffer);
}

/**
 * Guarda la foto en disco con un nombre que decide el servidor (nunca el del
 * cliente), sin sobrescribir nada y con permisos solo para el dueño.
 */
export async function guardarFoto(directorio, ticketId, buffer, tipo) {
  if (!/^[A-Za-z0-9-]{1,40}$/.test(String(ticketId))) throw new Error('Id de ticket inválido');
  await mkdir(directorio, { recursive: true });
  const nombre = `ticket-${ticketId}-${randomUUID()}.${tipo.ext}`;
  const destino = path.join(directorio, nombre);
  try {
    await writeFile(destino, buffer, { flag: 'wx', mode: 0o600 });
  } catch (error) {
    await rm(destino, { force: true }).catch(() => {});
    throw error;
  }
  return nombre;
}

function nombreFotoValido(ticketId, nombre) {
  if (!/^[A-Za-z0-9-]{1,40}$/.test(String(ticketId))) return false;
  const idEscapado = String(ticketId).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  return new RegExp(`^ticket-${idEscapado}-[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}\\.(?:jpg|png)$`).test(nombre);
}

/** Borra solo nombres de foto generados para ese ticket. */
export async function borrarFotos(directorio, ticketId, nombres) {
  if (!directorio || !Array.isArray(nombres)) return;
  await Promise.all(nombres
    .filter((nombre) => nombreFotoValido(ticketId, nombre))
    .map((nombre) => rm(path.join(directorio, nombre), { force: true })));
}

/** Lista nombres generados para un ticket sin exponer rutas del sistema. */
export async function listarFotos(directorio, ticketId) {
  if (!directorio || !/^[A-Za-z0-9-]{1,40}$/.test(String(ticketId))) return [];
  try {
    const nombres = await readdir(directorio);
    return nombres.filter((nombre) => nombreFotoValido(ticketId, nombre)).sort();
  } catch (error) {
    if (error.code === 'ENOENT') return [];
    throw error;
  }
}

/** Lee solo una foto generada para el ticket; nunca acepta rutas del cliente. */
export async function leerFoto(directorio, ticketId, nombre) {
  if (!directorio || !nombreFotoValido(ticketId, nombre)) return null;
  try {
    return {
      buffer: await readFile(path.join(directorio, nombre)),
      mime: nombre.endsWith('.png') ? 'image/png' : 'image/jpeg',
    };
  } catch (error) {
    if (error.code === 'ENOENT') return null;
    throw error;
  }
}

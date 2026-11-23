// Cifrado de contraseñas (hash). Todo el backend pasa por aquí.
//
// Algoritmo: Argon2id, el recomendado por OWASP (Password Storage Cheat Sheet)
// con sus parámetros mínimos: 19 MiB de memoria, 2 iteraciones, paralelismo 1.
// El hash queda en formato PHC ("$argon2id$v=19$m=19456,t=2,p=1$sal$hash"),
// que guarda el algoritmo y los parámetros junto al hash.
//
// Compatibilidad: las contraseñas que se guardaron antes con bcrypt ("$2b$...")
// se siguen aceptando. En el siguiente login correcto se vuelven a cifrar con
// Argon2id (ver necesitaRecifrar), así nadie tiene que resetear su clave.

import { hash, verify } from '@node-rs/argon2';
import bcrypt from 'bcryptjs';

// Algorithm.Argon2id = 2 (en @node-rs/argon2 el enum solo existe en los tipos).
const ARGON2ID = 2;

export const OPCIONES_ARGON2 = Object.freeze({
  algorithm: ARGON2ID,
  memoryCost: 19456, // KiB = 19 MiB
  timeCost: 2,
  parallelism: 1,
});

const PREFIJO_ARGON2ID = '$argon2id$';
const ES_BCRYPT = /^\$2[aby]\$\d{2}\$/;

/** Cifra una contraseña nueva con Argon2id. */
export function cifrarContrasena(contrasena) {
  return hash(contrasena, OPCIONES_ARGON2);
}

/**
 * Compara una contraseña con el hash guardado, sea Argon2id o bcrypt (heredado).
 * Devuelve false (nunca lanza) si el hash falta o tiene un formato desconocido.
 */
export async function verificarContrasena(contrasena, hashGuardado) {
  if (typeof contrasena !== 'string' || typeof hashGuardado !== 'string') return false;
  try {
    if (hashGuardado.startsWith(PREFIJO_ARGON2ID)) return await verify(hashGuardado, contrasena);
    if (ES_BCRYPT.test(hashGuardado)) return await bcrypt.compare(contrasena, hashGuardado);
  } catch {
    return false; // hash dañado: se trata como contraseña incorrecta
  }
  return false;
}

/**
 * true si el hash no es Argon2id con los parámetros vigentes (por ejemplo, un
 * bcrypt antiguo o un Argon2id con menos memoria). Se usa para recifrar en el login.
 */
export function necesitaRecifrar(hashGuardado) {
  if (typeof hashGuardado !== 'string' || !hashGuardado.startsWith(PREFIJO_ARGON2ID)) return true;
  const parametros = hashGuardado.match(/\$m=(\d+),t=(\d+),p=(\d+)\$/);
  if (!parametros) return true;
  const [, m, t, p] = parametros.map(Number);
  return m < OPCIONES_ARGON2.memoryCost || t < OPCIONES_ARGON2.timeCost || p !== OPCIONES_ARGON2.parallelism;
}

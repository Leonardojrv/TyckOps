// ¿PARA QUÉ SIRVE?
//   Prueba qué correos pueden iniciar sesión (colaborador y administrador).
//
// ¿QUÉ HACE?
//   Revisa que entren @gamaitaly.cl, @outlook.com y @gmail.com (con mayúsculas
//   o espacios), y que se rechacen otros dominios y los "parecidos" que
//   intentan engañar (por ejemplo gmail.com.falso.cl).
//
// ¿CÓMO LO CAMBIO?
//   Si se agrega o quita un dominio en DOMINIOS_PERMITIDOS (auth.schema.js),
//   ajusta las listas de abajo y corre `pnpm test`.

import assert from 'node:assert/strict';
import { test } from 'node:test';
import { loginSchema } from '../src/modules/auth/auth.schema.js';

const valido = (email) => loginSchema.safeParse({ email, password: 'x' }).success;

test('login acepta los tres dominios permitidos', () => {
  for (const email of ['ana@gamaitaly.cl', 'ana@outlook.com', 'ana@gmail.com', '  ANA@Gmail.COM ']) {
    assert.ok(valido(email), email);
  }
});

test('login rechaza otros dominios y los parecidos', () => {
  for (const email of [
    'ana@example.com',
    'ana@hotmail.com',
    'ana@gmail.com.falso.cl',
    'ana@falso-gmail.com',
    'ana@sub.outlook.com',
    'ana@gamaitaly.cl.evil.com',
  ]) {
    assert.ok(!valido(email), email);
  }
  const { error } = loginSchema.safeParse({ email: 'ana@example.com', password: 'x' });
  assert.equal(error.issues[0].message, 'Usa un correo @gamaitaly.cl, @outlook.com o @gmail.com.');
});

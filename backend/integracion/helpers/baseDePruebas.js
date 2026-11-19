// Base de datos EXCLUSIVA para pruebas (BDTyckOps_pruebas), en el mismo
// PostgreSQL del Docker. Nunca se toca la base real (BDTyckOps).
//
// - prepararBase(): crea la base si no existe y le aplica todas las migraciones
//   de database/BaseDatos (las mismas que usa la base real).
// - reiniciarDatos(): vacía las tablas y carga un set de datos conocido.

import { execSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import dotenv from 'dotenv';
import bcrypt from 'bcryptjs';
import { PrismaClient } from '@prisma/client';
import { conSslObligatorio } from '../../src/config/env.js';
import { USUARIOS, ROLES, DEPARTAMENTOS, CATEGORIAS } from './usuarios.js';

const aqui = path.dirname(fileURLToPath(import.meta.url));
export const RAIZ_BACKEND = path.resolve(aqui, '../..');
const SCHEMA = path.resolve(RAIZ_BACKEND, '../database/BaseDatos/prisma/schema.prisma');

export const NOMBRE_BASE_PRUEBAS = 'BDTyckOps_pruebas';

dotenv.config({ path: path.join(RAIZ_BACKEND, '.env'), quiet: true });

function urlConBase(nombreBase) {
  const original = process.env.DATABASE_URL_REAL ?? process.env.DATABASE_URL;
  if (!original) throw new Error('Falta DATABASE_URL en backend/.env');
  const url = new URL(original);
  url.pathname = `/${nombreBase}`;
  // Igual que el backend: la base solo acepta conexiones cifradas.
  return conSslObligatorio(url.toString());
}

// Se guarda la URL real una sola vez, antes de que algo la reemplace.
if (!process.env.DATABASE_URL_REAL && process.env.DATABASE_URL) {
  process.env.DATABASE_URL_REAL = process.env.DATABASE_URL;
}

export const urlPruebas = () => urlConBase(NOMBRE_BASE_PRUEBAS);
export const urlReal = () => conSslObligatorio(process.env.DATABASE_URL_REAL);
export const nombreBaseReal = () => new URL(urlReal()).pathname.slice(1);

export async function prepararBase() {
  const admin = new PrismaClient({ datasources: { db: { url: urlConBase('postgres') } } });
  try {
    const existe = await admin.$queryRaw`SELECT 1 FROM pg_database WHERE datname = ${NOMBRE_BASE_PRUEBAS}`;
    if (existe.length === 0) {
      await admin.$executeRawUnsafe(`CREATE DATABASE "${NOMBRE_BASE_PRUEBAS}"`);
    }
  } finally {
    await admin.$disconnect();
  }

  execSync(`npx prisma migrate deploy --schema "${SCHEMA}"`, {
    cwd: RAIZ_BACKEND,
    env: { ...process.env, DATABASE_URL: urlPruebas() },
    stdio: 'pipe',
  });
}

export function crearClientePruebas() {
  return new PrismaClient({ datasources: { db: { url: urlPruebas() } } });
}

/** Vacía las tablas y carga roles, departamentos, categorías y usuarios conocidos. */
export async function reiniciarDatos(prisma) {
  await prisma.$executeRawUnsafe(
    'TRUNCATE "Ticket", "Informe", "ReglasPrioridad", "GuiaAutoayuda", "Usuario", "Roles", "Departamento", "CategoriaReparacion" RESTART IDENTITY CASCADE',
  );

  const roles = {};
  for (const nombre of ROLES) {
    roles[nombre] = await prisma.roles.create({ data: { NombreRol: nombre } });
  }
  const depas = {};
  for (const nombre of DEPARTAMENTOS) {
    depas[nombre] = await prisma.departamento.create({ data: { nom_depa: nombre } });
  }
  for (const nombre of CATEGORIAS) {
    await prisma.categoriaReparacion.create({ data: { nombre } });
  }

  const creados = {};
  for (const [clave, u] of Object.entries(USUARIOS)) {
    creados[clave] = await prisma.user.create({
      data: {
        name: u.name,
        appat: u.appat,
        apmat: u.apmat,
        email: u.email,
        passwordHash: await bcrypt.hash(u.password, 10),
        ID_Rol: roles[u.rol].ID_Rol,
        ID_depa: depas[u.depa].ID_depa,
        isFirstLogin: u.isFirstLogin,
        termsAccepted: u.termsAccepted,
        termsVersion: u.termsAccepted ? 'GA-TOS-2026' : null,
        termsAcceptedAt: u.termsAccepted ? new Date() : null,
      },
    });
  }
  return creados;
}

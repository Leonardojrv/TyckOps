// ¿PARA QUÉ SIRVE?
//   Revisa que el formulario de "Reportar falla" venga bien antes de guardarlo.
//
// ¿QUÉ HACE?
//   Acepta solo las 4 categorías, limpia caracteres raros y exige largos mínimos y
//   máximos para la ubicación y la descripción.
//
// ¿CÓMO LO CAMBIO?
//   Si cambias un límite (por ejemplo, descripción de 300 caracteres), cámbialo
//   también en la app (fault_category.dart) para que coincidan.

import { z } from 'zod';

// Códigos que manda la app (RF-04). El nombre en la BD lo resuelve el repositorio.
export const CATEGORIAS = {
  ELECTRICA: 'Eléctrica',
  BANOS: 'Baños',
  AIRE_ACONDICIONADO: 'Aire acondicionado',
  INMOBILIARIO: 'Inmobiliario',
};

const ALIAS_CATEGORIA = {
  electrica: 'ELECTRICA',
  banos: 'BANOS',
  aire_acondicionado: 'AIRE_ACONDICIONADO',
  inmobiliario: 'INMOBILIARIO',
  mobiliario: 'INMOBILIARIO',
};

function normalizarCategoria(valor) {
  if (typeof valor !== 'string') return valor;
  const clave = valor
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .trim()
    .toLowerCase()
    .replace(/[\s-]+/g, '_');
  return ALIAS_CATEGORIA[clave] ?? valor;
}

const categoriaSchema = z.preprocess(
  normalizarCategoria,
  z.enum(Object.keys(CATEGORIAS), { errorMap: () => ({ message: 'Elige el tipo de avería.' }) }),
);

// Quita caracteres de control (deja los saltos de línea de la descripción).
const sinControl = (texto) => texto.replace(/[\u0000-\u0009\u000B-\u001F\u007F]/g, ' ');

export const reporteSchema = z
  .object({
    categoria: categoriaSchema,
    ubicacion: z
      .string()
      .transform(sinControl)
      .pipe(z.string().trim().min(3, 'Indica la ubicación de la falla.').max(150, 'La ubicación es muy larga.')),
    descripcion: z
      .string()
      .transform(sinControl)
      .pipe(z.string().trim().min(10, 'Describe la falla con al menos 10 caracteres.').max(250, 'La descripción admite hasta 250 caracteres.')),
  })
  .strict();

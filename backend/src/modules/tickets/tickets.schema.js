import { z } from 'zod';

// Códigos que manda la app (RF-04). El nombre en la BD lo resuelve el repositorio.
export const CATEGORIAS = {
  ELECTRICA: 'Eléctrica',
  BANOS: 'Baños',
  AIRE_ACONDICIONADO: 'Aire acondicionado',
  INMOBILIARIO: 'Inmobiliario',
};

// Quita caracteres de control (deja los saltos de línea de la descripción).
const sinControl = (texto) => texto.replace(/[\u0000-\u0009\u000B-\u001F\u007F]/g, ' ');

export const reporteSchema = z
  .object({
    categoria: z.enum(Object.keys(CATEGORIAS), {
      errorMap: () => ({ message: 'Elige el tipo de avería.' }),
    }),
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

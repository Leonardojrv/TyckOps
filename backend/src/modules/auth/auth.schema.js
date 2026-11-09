import { z } from 'zod';

export const loginSchema = z.object({
  email: z
    .string()
    .trim()
    .email()
    .toLowerCase()
    .refine((email) => email.endsWith('@gamaitaly.cl'), 'Usa tu correo corporativo @gamaitaly.cl.'),
  password: z.string().min(1).max(128),
});

// RF-02: sin newPassword se mantiene la contraseña actual.
export const primerAccesoSchema = z
  .object({
    currentPassword: z.string().min(1).max(128).optional(),
    newPassword: z
      .string()
      .min(8, 'La nueva contraseña debe tener al menos 8 caracteres.')
      .max(128)
      .regex(/[A-Za-z]/, 'La nueva contraseña debe incluir letras.')
      .regex(/\d/, 'La nueva contraseña debe incluir números.')
      .optional(),
  })
  .strict()
  .refine((data) => !data.newPassword || data.currentPassword, {
    path: ['currentPassword'],
    message: 'Ingresa tu contraseña temporal actual para cambiarla.',
  });
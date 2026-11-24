import { z } from 'zod';

// Dominios de correo con los que se puede iniciar sesión (ambos perfiles).
// Para agregar o quitar uno, cámbialo aquí Y en la app (mobile/lib/core/validators.dart).
export const DOMINIOS_PERMITIDOS = ['gamaitaly.cl', 'outlook.com', 'gmail.com'];

export const loginSchema = z.object({
  email: z
    .string()
    .trim()
    .email()
    .toLowerCase()
    // Se compara el dominio EXACTO (lo que va después de la @), no "termina en":
    // así "x@falso-gmail.com" o "x@gmail.com.evil.cl" no pasan.
    .refine(
      (email) => DOMINIOS_PERMITIDOS.includes(email.split('@')[1]),
      'Usa un correo @gamaitaly.cl, @outlook.com o @gmail.com.',
    ),
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
    acceptTerms: z.boolean(),
    termsVersion: z.string().min(1).max(32),
  })
  .strict()
  .refine((data) => !data.newPassword || data.currentPassword, {
    path: ['currentPassword'],
    message: 'Ingresa tu contraseña temporal actual para cambiarla.',
  });
// T8: el código de la verificación en dos pasos son exactamente 6 números.
export const mfaSchema = z
  .object({
    codigo: z.string().trim().regex(/^\d{6}$/, 'El código tiene 6 números.'),
  })
  .strict();

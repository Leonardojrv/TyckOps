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
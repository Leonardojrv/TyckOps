import dotenv from 'dotenv';
import { z } from 'zod';

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().int().min(1).max(65535).default(3000),
  DATABASE_URL: z.string().url().optional(),
  JWT_SECRET: z.string().min(32, 'JWT_SECRET debe tener al menos 32 caracteres.'),
  JWT_EXPIRES_IN: z.string().default('1h'),
  CORS_ORIGIN: z.string().default('*'),
  DEMO_WORKER_EMAIL: z.string().email().default('colaborador@gamaitaly.cl'),
  DEMO_WORKER_PASSWORD: z.string().min(12).default('DemoWorker2026!'),
  DEMO_ADMIN_EMAIL: z.string().email().default('admin@gamaitaly.cl'),
  DEMO_ADMIN_PASSWORD: z.string().min(12).default('DemoAdmin2026!'),
});

export function loadEnv(source = process.env) {
  dotenv.config();
  const result = envSchema.safeParse(source);

  if (!result.success) {
    const details = result.error.issues
      .map((issue) => `${issue.path.join('.')}: ${issue.message}`)
      .join('; ');
    throw new Error(`Configuración de entorno inválida: ${details}`);
  }

  return {
    nodeEnv: result.data.NODE_ENV,
    port: result.data.PORT,
    databaseUrl: result.data.DATABASE_URL,
    jwtSecret: result.data.JWT_SECRET,
    jwtExpiresIn: result.data.JWT_EXPIRES_IN,
    corsOrigin: result.data.CORS_ORIGIN,
    demoWorkerEmail: result.data.DEMO_WORKER_EMAIL.toLowerCase(),
    demoWorkerPassword: result.data.DEMO_WORKER_PASSWORD,
    demoAdminEmail: result.data.DEMO_ADMIN_EMAIL.toLowerCase(),
    demoAdminPassword: result.data.DEMO_ADMIN_PASSWORD,
  };
}
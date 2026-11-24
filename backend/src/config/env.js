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
  GROQ_API_KEY: z.string().trim().optional(),
  GROQ_MODEL: z.string().trim().min(1).default('openai/gpt-oss-20b'),
  GROQ_REASONING_EFFORT: z.enum(['low', 'medium', 'high']).default('low'),
  GROQ_TIMEOUT_MS: z.coerce.number().int().min(500).max(120000).default(20000),
  // T8: código fijo de la verificación en dos pasos, SOLO para desarrollo (6 números).
  // En producción se ignora: ahí el código siempre es aleatorio y va por correo.
  MFA_CODIGO_DESARROLLO: z.string().regex(/^\d{6}$/).optional(),
  // T11: clave de servicio de Firebase (ruta al .json o el JSON completo).
  // Si no está, se usa backend/firebase-service-account.json; si tampoco
  // existe, las notificaciones push quedan en modo simulado.
  FIREBASE_SERVICE_ACCOUNT: z.string().trim().optional(),
});

// Cifrado backend → PostgreSQL. La base de datos (Docker local y producción) solo
// acepta conexiones cifradas, así que la URL siempre debe llevar sslmode=require:
//  - si no trae sslmode, se agrega aquí (los .env de cada uno no están en git);
//  - si trae otro valor (disable, prefer...), es un error: Prisma podría
//    conectarse sin cifrar sin avisar.
// Ver database/CIFRADO.md.
export function conSslObligatorio(databaseUrl) {
  if (!databaseUrl) return databaseUrl;
  const url = new URL(databaseUrl);
  const sslmode = url.searchParams.get('sslmode');
  if (sslmode === null) url.searchParams.set('sslmode', 'require');
  else if (sslmode !== 'require') {
    throw new Error(
      `Configuración de entorno inválida: DATABASE_URL usa sslmode=${sslmode}. `
      + 'La conexión a PostgreSQL debe ir cifrada: usa sslmode=require o quita el parámetro.',
    );
  }
  return url.toString();
}

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
    databaseUrl: conSslObligatorio(result.data.DATABASE_URL),
    jwtSecret: result.data.JWT_SECRET,
    jwtExpiresIn: result.data.JWT_EXPIRES_IN,
    corsOrigin: result.data.CORS_ORIGIN,
    demoWorkerEmail: result.data.DEMO_WORKER_EMAIL.toLowerCase(),
    demoWorkerPassword: result.data.DEMO_WORKER_PASSWORD,
    demoAdminEmail: result.data.DEMO_ADMIN_EMAIL.toLowerCase(),
    demoAdminPassword: result.data.DEMO_ADMIN_PASSWORD,
    groqApiKey: result.data.GROQ_API_KEY || null,
    groqModel: result.data.GROQ_MODEL,
    groqReasoningEffort: result.data.GROQ_REASONING_EFFORT,
    groqTimeoutMs: result.data.GROQ_TIMEOUT_MS,
    mfaCodigoDesarrollo: result.data.MFA_CODIGO_DESARROLLO ?? null,
    firebaseServiceAccount: result.data.FIREBASE_SERVICE_ACCOUNT || null,
  };
}
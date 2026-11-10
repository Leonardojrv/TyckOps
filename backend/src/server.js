import { crearApp } from './app.js';
import { loadEnv } from './config/env.js';
import { connectPrisma } from './config/prisma.js';
import { crearRepositorioEnMemoria } from './modules/auth/auth.memory.repository.js';

const env = loadEnv();
let prisma = null;
let databaseStatus = env.databaseUrl ? 'disconnected' : 'not_configured';

if (env.databaseUrl) {
  try {
    prisma = await connectPrisma(env.databaseUrl);
    databaseStatus = 'connected';
  } catch (error) {
    console.error('No fue posible conectar con PostgreSQL:', error.message);
  }
}

if (!prisma && env.nodeEnv === 'production') {
  throw new Error('En producción se requiere una conexión a PostgreSQL; no se usarán usuarios de demostración.');
}

// Con PostgreSQL conectado, app.js crea el PrismaUserRepository. Antes se
// pasaba el cliente Prisma directo como repositorio y el login fallaba.
const userRepository = prisma ? null : await crearRepositorioEnMemoria([
  {
    id: 'demo-worker',
    name: 'Colaborador de prueba',
    email: env.demoWorkerEmail,
    password: env.demoWorkerPassword,
    role: 'COLABORADOR',
    termsAccepted: false, // debe aceptar los Términos en el primer acceso (RF-03)
    isFirstLogin: true, // muestra la pantalla de primer acceso (RF-02)
  },
  {
    id: 'demo-admin',
    name: 'Administrador de prueba',
    email: env.demoAdminEmail,
    password: env.demoAdminPassword,
    role: 'ADMINISTRADOR',
    termsAccepted: true,
    isFirstLogin: false,
  },
]);

const app = crearApp({ env, prisma, userRepository, databaseStatus });
const server = app.listen(env.port, () => {
  console.log(`TyckOps API escuchando en http://localhost:${env.port}`);
});

async function shutdown() {
  server.close(async () => {
    await prisma?.$disconnect();
    process.exit(0);
  });
}

process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);
import { crearApp } from './app.js';
import { loadEnv } from './config/env.js';
import { logger } from './config/logger.js';
import { connectPrisma } from './config/prisma.js';
import { ClienteGroq } from './ia/clienteGroq.js';
import { crearRepositorioEnMemoria } from './modules/auth/auth.memory.repository.js';
import { MemoryTicketRepository, ticketsDeDemostracion } from './modules/tickets/tickets.memory.repository.js';
import { PrismaTicketRepository } from './modules/tickets/tickets.prisma.repository.js';
import { TicketService } from './modules/tickets/tickets.service.js';

const env = loadEnv();
const groqClient = new ClienteGroq({
  apiKey: env.groqApiKey,
  model: env.groqModel,
  reasoningEffort: env.groqReasoningEffort,
  timeoutMs: env.groqTimeoutMs,
});
let prisma = null;
let databaseStatus = env.databaseUrl ? 'disconnected' : 'not_configured';

if (env.databaseUrl) {
  try {
    prisma = await connectPrisma(env.databaseUrl);
    databaseStatus = 'connected';
  } catch (error) {
    // Pista para el caso típico tras activar el cifrado: el contenedor sigue
    // con la configuración antigua (sin SSL).
    const esTls = /tls|ssl|encrypt/i.test(error.message);
    logger.error('db_conexion_fallida', {
      error: error.message,
      ...(esTls && {
        pista: 'La base de datos no aceptó la conexión cifrada. Ejecuta `docker compose up -d` en database/ (ver database/CIFRADO.md).',
      }),
    });
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
    // Nombre neutro mientras no haya datos reales: el saludo muestra
    // el nombre de cada cuenta, así que aquí no va una persona inventada.
    name: 'Colaborador GA.MA',
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

// Tickets: en PostgreSQL si hay base de datos; si no, datos de demostración en memoria.
// La foto de cada reporte se guarda en la columna imagen (BYTEA) del propio ticket.
const ticketService = new TicketService(
  prisma
    ? new PrismaTicketRepository(prisma)
    : new MemoryTicketRepository(ticketsDeDemostracion('demo-worker')),
  {
    slaCumplido: prisma ? null : 98.4,
    // Motor de IA (módulo de Moisés): cuando exista su analizador con
    // `analizar({ ticketId, categoria, descripcion, ubicacion })`, se conecta
    // aquí. Mientras sea null, los tickets Recibidos quedan como pendiente_ia.
    analizadorIA: null,
  },
);

const app = crearApp({ env, prisma, userRepository, ticketService, groqClient, databaseStatus });
const server = app.listen(env.port, () => {
  // Aviso para quien levanta el servidor (y las pruebas de integración lo esperan en stdout).
  console.log(`TyckOps API escuchando en http://localhost:${env.port}`);
  logger.info('servidor_iniciado',{ puerto: env.port, entorno: env.nodeEnv, baseDatos: databaseStatus });
});

async function shutdown(senal) {
  logger.info('servidor_detenido', { senal });
  server.close(async () => {
    await prisma?.$disconnect();
    await logger.cerrar(); // escribe lo pendiente antes de salir
    process.exit(0);
  });
}

process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));
// Lo que se escape de todo manejo queda registrado antes de caer.
process.on('unhandledRejection', (error) => logger.error('promesa_no_manejada', { error }));
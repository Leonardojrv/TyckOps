import cors from 'cors';
import express from 'express';
import helmet from 'helmet';
import { exigirHttps } from './middlewares/exigirHttps.js';
import { manejarErrores, rutaNoEncontrada } from './middlewares/manejarErrores.js';
import { registrarSolicitud } from './middlewares/registrarSolicitud.js';
import { crearRutasAdmin } from './modules/admin/admin.routes.js';
import { PrismaUserRepository } from './modules/auth/auth.repository.js';
import { crearRutasAuth } from './modules/auth/auth.routes.js';
import { AuthService } from './modules/auth/auth.service.js';
import { crearRutasTickets } from './modules/tickets/tickets.routes.js';
import { responder } from './utils/respuestas.js';

export function crearApp({
  env,
  prisma = null,
  userRepository,
  authService,
  ticketService = null,
  groqClient = null,
  auditLogger,
  databaseStatus,
} = {}) {
  const app = express();
  app.locals.groqClient = groqClient;
  const repository = userRepository ?? (prisma ? new PrismaUserRepository(prisma) : null);
  const service = authService ?? (repository
    ? new AuthService(repository, env, auditLogger)
    : null);
  const dbStatus = databaseStatus ?? (prisma ? 'connected' : 'not_configured');
  const allowedOrigins = env.corsOrigin === '*'
    ? '*'
    : env.corsOrigin.split(',').map((origin) => origin.trim());

  app.disable('x-powered-by');
  app.use(registrarSolicitud);
  if (env.nodeEnv === 'production') {
    // Confía en UN proxy delante (el del hosting) para saber si la conexión
    // original fue https y cuál es la IP real del cliente.
    app.set('trust proxy', 1);
    app.use(exigirHttps);
  }
  app.use(helmet());
  app.use(cors({ origin: allowedOrigins }));
  app.use(express.json({ limit: '1mb' }));

  app.get('/salud', (_req, res) => {
    responder(res, { status: 'ok', database: dbStatus });
  });
  app.use('/api/auth', crearRutasAuth({ authService: service, jwtSecret: env.jwtSecret }));
  app.use('/api/tickets', crearRutasTickets({ ticketService, authService: service, jwtSecret: env.jwtSecret }));
  app.use('/api/admin', crearRutasAdmin({ jwtSecret: env.jwtSecret, authService: service }));
  app.use(rutaNoEncontrada);
  app.use(manejarErrores);

  return app;
}
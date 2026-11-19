// ¿PARA QUÉ SIRVE?
//   Registro de transacciones del backend (winston). Cada línea es un JSON con
//   lo que pasó, quién lo hizo y cuándo: sirve para auditar y para investigar
//   un problema sin tener que reproducirlo.
//
// ¿DÓNDE QUEDAN?
//   En backend/logs/ (o LOG_DIR), un archivo por día:
//     - transacciones-AAAA-MM-DD.log  → todo desde LOG_LEVEL (info por defecto)
//     - errores-AAAA-MM-DD.log        → solo errores
//   Se borran solos después de LOG_RETENCION_DIAS (30 por defecto): guardar
//   datos personales más tiempo del necesario también es un riesgo (Ley 21.719).
//
// ¿QUÉ NUNCA DEBE IR?
//   Contraseñas, tokens, hashes, llaves de API, fotos ni el cuerpo completo de
//   una solicitud. `ocultarSensibles` lo tapa por si acaso, pero la regla es no
//   mandarlo: registra IDs y resultados, no contenido.
//
// ¿CÓMO LO USO?
//   import { logger } from '../config/logger.js';
//   logger.info('ticket_creado', { ticketId, userId });
//   logger.warn('login_fallido', { email, ip });
//   logger.error('error_interno', { requestId, error });

import path from 'node:path';
import { fileURLToPath } from 'node:url';
import winston from 'winston';
import DailyRotateFile from 'winston-daily-rotate-file';

const CARPETA_POR_DEFECTO = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../logs');

// Claves que jamás se escriben tal cual (se comparan sin mayúsculas ni _ o -).
const CLAVES_SECRETAS = new Set([
  'password', 'currentpassword', 'newpassword', 'passwordhash', 'contrasena',
  'token', 'accesstoken', 'refreshtoken', 'authorization', 'cookie',
  'jwtsecret', 'apikey', 'groqapikey', 'secret', 'databaseurl',
]);
// Contenido binario o texto libre largo: se reemplaza por su tamaño.
const CLAVES_CONTENIDO = new Set(['imagen', 'foto', 'buffer', 'body']);

function normalizar(clave) {
  return String(clave).toLowerCase().replace(/[_-]/g, '');
}

// "camila@gamaitaly.cl" → "ca***@gamaitaly.cl": se puede seguir un patrón
// (muchos intentos al mismo correo) sin dejar el correo completo en el archivo.
export function enmascararCorreo(correo) {
  if (typeof correo !== 'string' || !correo.includes('@')) return correo;
  const [usuario, dominio] = correo.split('@');
  return `${usuario.slice(0, 2)}***@${dominio}`;
}

function serializarError(error) {
  return {
    name: error.name,
    message: error.message,
    code: error.code,
    // El stack solo fuera de producción: puede incluir rutas internas.
    ...(process.env.NODE_ENV !== 'production' && { stack: error.stack }),
  };
}

export function ocultarSensibles(valor, profundidad = 0) {
  if (profundidad > 5 || valor === null || typeof valor !== 'object') return valor;
  if (valor instanceof Error) return serializarError(valor);
  if (Buffer.isBuffer(valor)) return `[binario ${valor.length} bytes]`;
  if (Array.isArray(valor)) return valor.map((item) => ocultarSensibles(item, profundidad + 1));

  const limpio = {};
  for (const [clave, contenido] of Object.entries(valor)) {
    const nombre = normalizar(clave);
    if (CLAVES_SECRETAS.has(nombre)) limpio[clave] = '[OCULTO]';
    else if (CLAVES_CONTENIDO.has(nombre)) limpio[clave] = contenido == null ? contenido : '[OMITIDO]';
    else if (nombre === 'email' || nombre === 'correo') limpio[clave] = enmascararCorreo(contenido);
    else limpio[clave] = ocultarSensibles(contenido, profundidad + 1);
  }
  return limpio;
}

const formatoSeguro = winston.format((info) => {
  const limpio = ocultarSensibles({ ...info });
  // winston guarda el nivel en símbolos internos: se conservan tal cual.
  for (const simbolo of Object.getOwnPropertySymbols(info)) limpio[simbolo] = info[simbolo];
  return limpio;
});

// En pruebas (node --test, jest o NODE_ENV=test) no se escribe nada a disco.
function enPruebas() {
  return process.env.NODE_ENV === 'test'
    || Boolean(process.env.NODE_TEST_CONTEXT)
    || Boolean(process.env.JEST_WORKER_ID);
}

function crearLogger() {
  const carpeta = process.env.LOG_DIR || CARPETA_POR_DEFECTO;
  const retencion = `${Number(process.env.LOG_RETENCION_DIAS) || 30}d`;
  const formatoArchivo = winston.format.combine(
    formatoSeguro(),
    winston.format.timestamp(),
    winston.format.json(),
  );
  const archivo = (nombre, nivel) => new DailyRotateFile({
    dirname: carpeta,
    filename: `${nombre}-%DATE%.log`,
    datePattern: 'YYYY-MM-DD',
    maxSize: '20m',
    maxFiles: retencion,
    level: nivel,
    format: formatoArchivo,
  });

  const transportes = [archivo('transacciones'), archivo('errores', 'error')];
  if (process.env.NODE_ENV !== 'production') {
    transportes.push(new winston.transports.Console({
      format: winston.format.combine(
        formatoSeguro(),
        winston.format.colorize(),
        winston.format.timestamp({ format: 'HH:mm:ss' }),
        winston.format.printf(({ level, message, timestamp, ...resto }) => {
          const extra = Object.keys(resto).length ? ` ${JSON.stringify(resto)}` : '';
          return `${timestamp} ${level} ${message}${extra}`;
        }),
      ),
    }));
  }

  return winston.createLogger({
    level: process.env.LOG_LEVEL || 'info',
    defaultMeta: { servicio: 'tyckops-api' },
    transports: transportes,
    exitOnError: false,
  });
}

// Se crea en el primer uso (no al importar): así ya se leyó el .env y las
// pruebas no abren archivos.
let instancia = null;
function obtener() {
  if (!instancia) {
    instancia = enPruebas()
      ? winston.createLogger({ silent: true, transports: [new winston.transports.Console()] })
      : crearLogger();
  }
  return instancia;
}

export const logger = {
  info: (mensaje, datos) => obtener().info(mensaje, datos),
  warn: (mensaje, datos) => obtener().warn(mensaje, datos),
  error: (mensaje, datos) => obtener().error(mensaje, datos),
  debug: (mensaje, datos) => obtener().debug(mensaje, datos),
  // Espera a que se escriba lo pendiente antes de apagar el servidor.
  cerrar: () => new Promise((resolve) => {
    if (!instancia) return resolve();
    instancia.on('finish', resolve);
    instancia.end();
  }),
};

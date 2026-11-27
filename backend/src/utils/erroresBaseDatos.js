// Traduce los errores de PostgreSQL (vía Prisma) a respuestas HTTP claras.
//
// Se reconocen por su nombre de clase y su código, sin importar @prisma/client,
// para que este archivo funcione aunque el cliente de Prisma no esté generado
// (por ejemplo, en las pruebas que usan repositorios en memoria).
//
// Seguridad: al cliente NUNCA se le envía el mensaje original de la base de
// datos (trae nombres de tablas, columnas y hasta la fila completa con sus
// datos). Solo viaja un código y un mensaje pensado para el usuario.

import { HttpError } from './http-error.js';

// Errores de conexión: la base no responde, se cayó o no hay conexiones libres.
//   P1000 credenciales rechazadas      P1001 no se puede llegar al servidor
//   P1002 el servidor no respondió     P1008 la operación superó el tiempo
//   P1017 el servidor cerró la conexión P2024 se agotó el pool de conexiones
const CODIGOS_CONEXION = new Set(['P1000', 'P1001', 'P1002', 'P1008', 'P1017', 'P2024']);

// Mensajes para las restricciones CHECK del modelo relacional (tabla Ticket).
const MENSAJES_CHECK = {
  ck_ticket_estado: 'El estado del ticket no es válido.',
  ck_ticket_motivo_rechazo: 'Para rechazar un ticket, el motivo debe tener al menos 100 caracteres.',
  ck_ticket_revisor: 'Quien aprueba o rechaza un ticket no puede ser quien lo creó.',
  ck_ticket_fecha_cierre: 'La fecha de cierre no puede ser anterior a la fecha de creación.',
};

const noDisponible = () => new HttpError(
  503,
  'BASE_DATOS_NO_DISPONIBLE',
  'El servicio no está disponible por un problema con la base de datos. Intenta en unos minutos.',
);

/** ¿Es un error lanzado por el cliente de Prisma? */
export function esErrorDeBaseDatos(error) {
  return typeof error?.name === 'string' && error.name.startsWith('PrismaClient');
}

/**
 * Devuelve { httpError, registro } para un error de Prisma, o null si no lo es.
 * - httpError: lo que se responde al cliente.
 * - registro: resumen corto para el log del servidor (sin datos de usuarios).
 */
export function traducirErrorBaseDatos(error) {
  if (!esErrorDeBaseDatos(error)) return null;
  const codigo = error.code ?? error.errorCode ?? null;
  const modelo = error.meta?.modelName ?? null;
  const registro = { tipo: error.name, codigo, modelo };

  // 1) No se pudo conectar al iniciar, o el motor de Prisma falló.
  if (error.name === 'PrismaClientInitializationError' || error.name === 'PrismaClientRustPanicError') {
    return { httpError: noDisponible(), registro };
  }

  // 2) Errores conocidos, con código P1xxx / P2xxx.
  if (error.name === 'PrismaClientKnownRequestError') {
    if (CODIGOS_CONEXION.has(codigo)) return { httpError: noDisponible(), registro };

    switch (codigo) {
      case 'P2002': // UNIQUE: el valor ya existe (ej. un correo repetido)
        return {
          httpError: new HttpError(409, 'REGISTRO_DUPLICADO', 'Ya existe un registro con esos datos.'),
          registro: { ...registro, campos: error.meta?.target ?? null },
        };
      case 'P2003': // FOREIGN KEY: apunta a un registro que no existe (o que está en uso)
        return {
          httpError: new HttpError(400, 'REFERENCIA_INVALIDA', 'Uno de los datos hace referencia a un registro que no existe.'),
          registro: { ...registro, restriccion: error.meta?.constraint ?? error.meta?.field_name ?? null },
        };
      case 'P2025': // el registro a actualizar o borrar no existe
        return {
          httpError: new HttpError(404, 'REGISTRO_NO_ENCONTRADO', 'No encontramos el registro solicitado.'),
          registro,
        };
      case 'P2000': // el valor supera el largo de la columna (VARCHAR)
        return {
          httpError: new HttpError(400, 'DATOS_INVALIDOS', 'Uno de los datos supera el largo permitido.'),
          registro,
        };
      case 'P2011': // NOT NULL
      case 'P2012': // falta un valor obligatorio
        return {
          httpError: new HttpError(400, 'DATOS_INVALIDOS', 'Falta un dato obligatorio.'),
          registro,
        };
      case 'P2034': // conflicto entre transacciones simultáneas
        return {
          httpError: new HttpError(409, 'CONFLICTO_CONCURRENCIA', 'Otra operación modificó los mismos datos. Intenta nuevamente.'),
          registro,
        };
      default:
        return null; // otro código: lo maneja el 500 genérico (y queda en el log completo)
    }
  }

  // 3) Errores sin código de Prisma: se reconocen por el código de PostgreSQL.
  if (error.name === 'PrismaClientUnknownRequestError') {
    const mensaje = String(error.message ?? '');

    // 23514 = violación de una restricción CHECK (ej. ck_ticket_estado).
    if (mensaje.includes('23514') || mensaje.includes('violates check constraint')) {
      const restriccion = mensaje.match(/check constraint \\?"([a-z0-9_]+)\\?"/i)?.[1] ?? null;
      return {
        httpError: new HttpError(
          400,
          'RESTRICCION_INCUMPLIDA',
          MENSAJES_CHECK[restriccion] ?? 'Uno de los datos no cumple las reglas de la base de datos.',
        ),
        registro: { ...registro, codigo: '23514', restriccion },
      };
    }

    // La conexión se cortó a mitad de una consulta.
    if (/connection (refused|reset|closed)|server has closed the connection|ECONNREFUSED|ECONNRESET|timed out/i.test(mensaje)) {
      return { httpError: noDisponible(), registro };
    }
  }

  return null;
}

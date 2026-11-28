// Datos iniciales: roles, departamentos, categorías, usuarios y tickets de prueba.
// Se ejecuta con `npx prisma db seed`.
// Es idempotente: si un dato ya existe no lo duplica ni lo modifica.
// Las contraseñas de prueba se leen de .env (SEED_*_PASSWORD); nunca se escriben aquí.

require("dotenv/config");
const { hash } = require("@node-rs/argon2");

// Mismo cifrado que el backend (backend/src/modules/auth/passwords.js):
// Argon2id con los parámetros mínimos de OWASP (19 MiB, 2 iteraciones, paralelismo 1).
const OPCIONES_ARGON2 = { algorithm: 2 /* Argon2id */, memoryCost: 19456, timeCost: 2, parallelism: 1 };
const { PrismaClient } = require("@prisma/client");

const prisma = new PrismaClient();

const ROLES = ["colaborador", "administrador"];
const DEPARTAMENTOS = ["RRHH", "Administracion", "Servicios generales"];
const CATEGORIAS = ["Inmobiliario", "Electrica", "Baños", "Aire acondicionado"];

function requerirEnv(nombre) {
  const valor = process.env[nombre];
  if (!valor || valor.length < 8) {
    throw new Error(`Falta ${nombre} en database/BaseDatos/.env (mínimo 8 caracteres).`);
  }
  return valor;
}

// Roles, Departamento y CategoriaReparacion no tienen columna única por nombre,
// así que se busca antes de crear.
async function asegurar(modelo, campo, valor) {
  const existente = await prisma[modelo].findFirst({ where: { [campo]: valor } });
  return existente ?? prisma[modelo].create({ data: { [campo]: valor } });
}

async function asegurarUsuario({ email, password, name, appat, apmat, rol, depa }) {
  const existente = await prisma.user.findUnique({ where: { email } });
  if (existente) return { user: existente, creado: false };
  const user = await prisma.user.create({
    data: {
      email,
      name,
      appat,
      apmat,
      passwordHash: await hash(password, OPCIONES_ARGON2),
      ID_Rol: rol.ID_Rol,
      ID_depa: depa.ID_depa,
      estado: "activo",
      telefono: "9 1111 1111", // teléfono de prueba
      // primerAcceso = true y terminosAceptados = false por defecto:
      // cada usuario acepta los Términos en su primer inicio de sesión.
    },
  });
  return { user, creado: true };
}

async function main() {
  const passwordColaborador = requerirEnv("SEED_COLABORADOR_PASSWORD");
  const passwordAdmin = requerirEnv("SEED_ADMIN_PASSWORD");

  const roles = {};
  for (const nombre of ROLES) roles[nombre] = await asegurar("roles", "NombreRol", nombre);

  const depas = {};
  for (const nombre of DEPARTAMENTOS) depas[nombre] = await asegurar("departamento", "nom_depa", nombre);

  const categorias = {};
  for (const nombre of CATEGORIAS) {
    categorias[nombre] = await asegurar("categoriaReparacion", "nombre", nombre);
  }

  const usuarios = [
    {
      email: "colaborador@gamaitaly.cl",
      password: passwordColaborador,
      name: "Colaborador",
      appat: "Prueba",
      apmat: "TyckOps",
      rol: roles.colaborador,
      depa: depas.RRHH,
    },
    {
      email: "admin@gamaitaly.cl",
      password: passwordAdmin,
      name: "Administrador",
      appat: "Prueba",
      apmat: "TyckOps",
      rol: roles.administrador,
      depa: depas.Administracion,
    },
  ];

  const usuariosSeed = {};
  for (const datos of usuarios) {
    const { user, creado } = await asegurarUsuario(datos);
    usuariosSeed[datos.email] = user;
    console.log(`${datos.email}: ${creado ? "creado" : "ya existía, no se modificó"}`);
  }

  await asegurarTicketsDemostracion(
    usuariosSeed["colaborador@gamaitaly.cl"],
    usuariosSeed["admin@gamaitaly.cl"],
    categorias,
  );
  console.log("Seed completado.");
}

async function asegurarTicketsDemostracion(colaborador, administrador, categorias) {
  const ejemplos = [
    { estado: "recibido", prioridad: "baja", categoria: "Electrica" },
    { estado: "en_revision", prioridad: "media", categoria: "Baños" },
    { estado: "aprobado", prioridad: "media", categoria: "Inmobiliario" },
    { estado: "en_proceso", prioridad: "alta", categoria: "Aire acondicionado" },
    { estado: "resuelto", prioridad: "media", categoria: "Electrica" },
    { estado: "cerrado", prioridad: "baja", categoria: "Baños", solucion: "autoayuda_ia" },
    { estado: "rechazado", prioridad: "media", categoria: "Inmobiliario", motivo: "El trabajo solicitado corresponde a un proveedor externo autorizado y requiere coordinación con la administración del edificio." },
    { estado: "cancelado", prioridad: "media", categoria: "Aire acondicionado" },
    { estado: "autogestion", prioridad: "baja", categoria: "Electrica" },
  ];

  for (const ejemplo of ejemplos) {
    const descripcion = `Ticket de prueba seed: ${ejemplo.estado}`;
    const existente = await prisma.ticket.findFirst({
      where: { ID_user: colaborador.id, Descripcion: descripcion },
    });
    if (existente) continue;

    const finalizado = ["resuelto", "cerrado", "rechazado", "cancelado"].includes(ejemplo.estado);
    await prisma.ticket.create({
      data: {
        Descripcion: descripcion,
        Estado: ejemplo.estado,
        Ubicacion: "Sector de pruebas",
        Prioridad: ejemplo.prioridad,
        ...(finalizado && { FechaCierre: new Date() }),
        ...(ejemplo.solucion && { TipoSolucion: ejemplo.solucion }),
        ...(ejemplo.motivo && { MotivoRechazo: ejemplo.motivo }),
        ...(["aprobado", "en_proceso", "resuelto", "cerrado"].includes(ejemplo.estado)
          && { ID_admin_aprobador: administrador.id }),
        ID_user: colaborador.id,
        ID_CateRepa: categorias[ejemplo.categoria].ID_CateRepa,
      },
    });
  }
}

main()
  .catch((error) => {
    console.error(error.message);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());

// Datos iniciales para una base nueva: roles, departamentos, categorías y dos
// usuarios de prueba. Se ejecuta con `npx prisma db seed`.
// Es idempotente: si un dato ya existe no lo duplica ni lo modifica.
// Las contraseñas de prueba se leen de .env (SEED_*_PASSWORD); nunca se escriben aquí.

require("dotenv/config");
const bcrypt = require("bcryptjs");
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
      passwordHash: await bcrypt.hash(password, 12),
      ID_Rol: rol.ID_Rol,
      ID_depa: depa.ID_depa,
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

  for (const nombre of CATEGORIAS) await asegurar("categoriaReparacion", "nombre", nombre);

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

  for (const datos of usuarios) {
    const { creado } = await asegurarUsuario(datos);
    console.log(`${datos.email}: ${creado ? "creado" : "ya existía, no se modificó"}`);
  }
  console.log("Seed completado.");
}

main()
  .catch((error) => {
    console.error(error.message);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());

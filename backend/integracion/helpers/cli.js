// Uso desde otras herramientas (por ejemplo, las pruebas de Flutter):
//   node integracion/helpers/cli.js preparar   -> crea la base de pruebas y aplica migraciones
//   node integracion/helpers/cli.js reiniciar  -> recarga los datos de prueba
//   node integracion/helpers/cli.js url        -> imprime la URL de la base de pruebas
//   node integracion/helpers/cli.js usuario <correo> -> imprime la fila del usuario en JSON

import { prepararBase, reiniciarDatos, crearClientePruebas, urlPruebas } from './baseDePruebas.js';

const accion = process.argv[2];

if (accion === 'url') {
  console.log(urlPruebas());
} else if (accion === 'usuario') {
  // Imprime en JSON la fila de un usuario (para verificar desde otras pruebas).
  const prisma = crearClientePruebas();
  try {
    const user = await prisma.user.findUnique({ where: { email: process.argv[3] }, include: { rol: true } });
    console.log(JSON.stringify(user));
  } finally {
    await prisma.$disconnect();
  }
} else if (accion === 'preparar' || accion === 'reiniciar') {
  if (accion === 'preparar') await prepararBase();
  const prisma = crearClientePruebas();
  try {
    await reiniciarDatos(prisma);
    console.log('OK');
  } finally {
    await prisma.$disconnect();
  }
} else {
  console.error('Acción desconocida. Usa: preparar | reiniciar | url');
  process.exitCode = 1;
}

import { prepararBase } from './helpers/baseDePruebas.js';

// Se ejecuta UNA vez antes de todas las suites: crea BDTyckOps_pruebas
// (si no existe) y le aplica las migraciones de database/BaseDatos.
export default async function globalSetup() {
  await prepararBase();
}

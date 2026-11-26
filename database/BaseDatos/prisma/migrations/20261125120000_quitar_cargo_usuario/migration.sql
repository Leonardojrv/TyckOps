-- Se quita Usuario.Cargo: ningún archivo del backend ni de la app la lee o escribe.
-- Al 25-11-2026 la columna estaba vacía en todos los usuarios: no se pierden datos.

-- AlterTable
ALTER TABLE "Usuario" DROP COLUMN "Cargo";

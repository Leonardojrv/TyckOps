-- Se quita Ticket.Piso: el piso ya se escribe dentro de "Ubicacion"
-- (ej. "Piso 2, Sala B") y la app nunca llenó esta columna por separado.
-- Al 23-11-2026 la columna estaba vacía en todos los tickets: no se pierden datos.

-- AlterTable
ALTER TABLE "Ticket" DROP COLUMN "Piso";

-- Quita la relación Ticket -> ReglasPrioridad (versión del .txt de reglas que
-- se usó al asignar la prioridad). No se acordó con el equipo y nadie la leía.
-- La regla aplicada sigue en Ticket.ID_ReglaAplicada.

ALTER TABLE "Ticket" DROP CONSTRAINT IF EXISTS "Ticket_ReglasPrioridad_FK";
ALTER TABLE "Ticket" DROP COLUMN IF EXISTS "ID_VersionReglas";

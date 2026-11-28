-- Flujo transaccional de los tickets: todo ticket operativo (falla real que
-- gestiona Servicios Generales) tiene prioridad.
--  - Un ticket nace en "recibido" y puede estar sin prioridad unos segundos,
--    mientras la IA la calcula. Si la IA no está o falla, el backend le pone
--    "media" (OrigenPrioridad 'defecto' o 'falla_ia').
--  - Desde "en_revision" el administrador ya lo gestiona: la prioridad es
--    obligatoria. "cancelado", "rechazado" y "cerrado" no se exigen (un ticket
--    puede cancelarse antes de tener prioridad).
-- Al 26-11-2026 ningún ticket incumplía estas reglas: no se modifican datos.

-- Solo los 3 valores del sistema (en minúscula, igual que Estado).
ALTER TABLE "Ticket" ADD CONSTRAINT "ck_ticket_prioridad"
    CHECK ("Prioridad" IS NULL OR "Prioridad" IN ('baja', 'media', 'alta'));

-- Un ticket en gestión siempre tiene prioridad.
ALTER TABLE "Ticket" ADD CONSTRAINT "ck_ticket_operativo_prioridad"
    CHECK ("Estado" NOT IN ('en_revision', 'aprobado', 'en_proceso', 'resuelto') OR "Prioridad" IS NOT NULL);

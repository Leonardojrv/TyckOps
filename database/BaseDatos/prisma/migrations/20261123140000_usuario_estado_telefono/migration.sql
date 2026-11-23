-- Migración de datos (no cambia la estructura).
-- Completa los usuarios que tienen estado o teléfono vacíos:
--  - estado   -> 'activo'
--  - telefono -> '9 1111 1111' (teléfono de prueba, mientras no haya uno real)
-- Solo toca los NULL: si alguien ya tiene un valor, se respeta.

UPDATE "Usuario" SET "estado" = 'activo' WHERE "estado" IS NULL;
UPDATE "Usuario" SET "telefono" = '9 1111 1111' WHERE "telefono" IS NULL;

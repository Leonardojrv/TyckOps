-- MM2 · Prioridad inicial con IA y reglas.
--  - ReglasPrioridad: cada fila es una VERSIÓN del .txt de reglas; se sube
--    inactiva y el administrador la activa (solo una activa a la vez).
--  - Ticket: guarda la prioridad que decidió el sistema al crearlo, de dónde
--    salió (guía, regla, defecto o falla de la IA), qué regla y qué versión.
--  - CambioPrioridad: cada cambio que hace un administrador (quién y cuándo).
-- Todas las columnas nuevas son opcionales: los tickets existentes no cambian.

-- AlterTable
ALTER TABLE "ReglasPrioridad"
    ADD COLUMN "Activa" BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN "FechaActivacion" TIMESTAMP(6);

-- Solo una versión activa a la vez.
CREATE UNIQUE INDEX "ReglasPrioridad_unaActiva_UK" ON "ReglasPrioridad"("Activa") WHERE "Activa";

-- AlterTable
ALTER TABLE "Ticket"
    ADD COLUMN "PrioridadInicial" VARCHAR(20),
    ADD COLUMN "OrigenPrioridad" VARCHAR(20),
    ADD COLUMN "ID_ReglaAplicada" VARCHAR(30),
    ADD COLUMN "ID_VersionReglas" INTEGER,
    ADD CONSTRAINT "ck_ticket_prioridad_inicial" CHECK ("PrioridadInicial" IS NULL OR "PrioridadInicial" IN ('baja', 'media', 'alta')),
    ADD CONSTRAINT "ck_ticket_origen_prioridad" CHECK ("OrigenPrioridad" IS NULL OR "OrigenPrioridad" IN ('guia', 'regla', 'defecto', 'falla_ia'));

-- AddForeignKey
ALTER TABLE "Ticket" ADD CONSTRAINT "Ticket_ReglasPrioridad_FK" FOREIGN KEY ("ID_VersionReglas") REFERENCES "ReglasPrioridad"("ID_Regla") ON DELETE SET NULL ON UPDATE CASCADE;

-- CreateTable
CREATE TABLE "CambioPrioridad" (
    "ID_Cambio" SERIAL NOT NULL,
    "PrioridadAnterior" VARCHAR(20),
    "PrioridadNueva" VARCHAR(20) NOT NULL,
    "Fecha" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "ID_Ticket" INTEGER NOT NULL,
    "ID_admin" INTEGER NOT NULL,

    CONSTRAINT "CambioPrioridad_PK" PRIMARY KEY ("ID_Cambio"),
    CONSTRAINT "ck_cambio_prioridad_nueva" CHECK ("PrioridadNueva" IN ('baja', 'media', 'alta'))
);

-- CreateIndex
CREATE INDEX "CambioPrioridad_Ticket_IDX" ON "CambioPrioridad"("ID_Ticket");

-- AddForeignKey
ALTER TABLE "CambioPrioridad" ADD CONSTRAINT "CambioPrioridad_Ticket_FK" FOREIGN KEY ("ID_Ticket") REFERENCES "Ticket"("ID_Ticket") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CambioPrioridad" ADD CONSTRAINT "CambioPrioridad_Usuario_FK" FOREIGN KEY ("ID_admin") REFERENCES "Usuario"("ID_user") ON DELETE RESTRICT ON UPDATE CASCADE;

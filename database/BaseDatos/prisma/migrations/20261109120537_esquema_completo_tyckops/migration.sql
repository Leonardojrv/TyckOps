/*
  Warnings:

  - You are about to drop the `Usuario` table. If the table is not empty, all the data it contains will be lost.

*/
-- DropTable
DROP TABLE "Usuario";

-- CreateTable
CREATE TABLE "departamento" (
    "id_depa" SERIAL NOT NULL,
    "nom_depa" VARCHAR(50) NOT NULL,

    CONSTRAINT "departamento_pkey" PRIMARY KEY ("id_depa")
);

-- CreateTable
CREATE TABLE "CargaReglas" (
    "id_regla" SERIAL NOT NULL,
    "archivo" BYTEA,
    "fechaInscripcion" DATE,

    CONSTRAINT "CargaReglas_pkey" PRIMARY KEY ("id_regla")
);

-- CreateTable
CREATE TABLE "CategoriaReparacion" (
    "id_caterepa" SERIAL NOT NULL,
    "nombre" VARCHAR(150) NOT NULL,

    CONSTRAINT "CategoriaReparacion_pkey" PRIMARY KEY ("id_caterepa")
);

-- CreateTable
CREATE TABLE "usuario" (
    "id_user" SERIAL NOT NULL,
    "nombre" VARCHAR(50) NOT NULL,
    "appat" VARCHAR(50) NOT NULL,
    "apmat" VARCHAR(50) NOT NULL,
    "correo" VARCHAR(100) NOT NULL,
    "password" VARCHAR(50) NOT NULL,
    "tipoUsuario" CHAR(1) NOT NULL,
    "id_depa" INTEGER NOT NULL,
    "id_regla" INTEGER,

    CONSTRAINT "usuario_pkey" PRIMARY KEY ("id_user")
);

-- CreateTable
CREATE TABLE "Ticket" (
    "id_ticket" SERIAL NOT NULL,
    "descripcion" VARCHAR(500) NOT NULL,
    "estado" VARCHAR(50) NOT NULL,
    "ubicacion" VARCHAR(150) NOT NULL,
    "piso" VARCHAR(50) NOT NULL,
    "urgencia" VARCHAR(150),
    "nivelComplejidad" VARCHAR(150),
    "tipoSolucion" VARCHAR(150),
    "fechaCreacion" DATE,
    "id_user" INTEGER NOT NULL,
    "id_caterepa" INTEGER NOT NULL,
    "id_ticketOriginal" INTEGER,

    CONSTRAINT "Ticket_pkey" PRIMARY KEY ("id_ticket")
);

-- CreateTable
CREATE TABLE "UsuariosEliminados" (
    "id_userelim" SERIAL NOT NULL,
    "nombre" VARCHAR(50) NOT NULL,
    "appat" VARCHAR(50) NOT NULL,
    "apmat" VARCHAR(50) NOT NULL,
    "correo" VARCHAR(100) NOT NULL,
    "fechaEliminado" TIMESTAMP(6),
    "id_user" INTEGER NOT NULL,

    CONSTRAINT "UsuariosEliminados_pkey" PRIMARY KEY ("id_userelim")
);

-- CreateTable
CREATE TABLE "TicketsEliminados" (
    "id_ticketelimi" SERIAL NOT NULL,
    "descripcion" VARCHAR(500) NOT NULL,
    "estado" VARCHAR(50) NOT NULL,
    "ubicacion" VARCHAR(150) NOT NULL,
    "piso" VARCHAR(50) NOT NULL,
    "urgencia" VARCHAR(150),
    "nivelComplejidad" VARCHAR(150),
    "fechaCreacion" DATE,
    "fechaEliminacion" TIMESTAMP(6),
    "id_ticket" INTEGER NOT NULL,
    "id_user" INTEGER NOT NULL,

    CONSTRAINT "TicketsEliminados_pkey" PRIMARY KEY ("id_ticketelimi")
);

-- CreateIndex
CREATE UNIQUE INDEX "UsuariosEliminados_id_user_key" ON "UsuariosEliminados"("id_user");

-- AddForeignKey
ALTER TABLE "usuario" ADD CONSTRAINT "usuario_id_depa_fkey" FOREIGN KEY ("id_depa") REFERENCES "departamento"("id_depa") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "usuario" ADD CONSTRAINT "usuario_id_regla_fkey" FOREIGN KEY ("id_regla") REFERENCES "CargaReglas"("id_regla") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Ticket" ADD CONSTRAINT "Ticket_id_user_fkey" FOREIGN KEY ("id_user") REFERENCES "usuario"("id_user") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Ticket" ADD CONSTRAINT "Ticket_id_caterepa_fkey" FOREIGN KEY ("id_caterepa") REFERENCES "CategoriaReparacion"("id_caterepa") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Ticket" ADD CONSTRAINT "Ticket_id_ticketOriginal_fkey" FOREIGN KEY ("id_ticketOriginal") REFERENCES "Ticket"("id_ticket") ON DELETE SET NULL ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "UsuariosEliminados" ADD CONSTRAINT "UsuariosEliminados_id_user_fkey" FOREIGN KEY ("id_user") REFERENCES "usuario"("id_user") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TicketsEliminados" ADD CONSTRAINT "TicketsEliminados_id_ticket_fkey" FOREIGN KEY ("id_ticket") REFERENCES "Ticket"("id_ticket") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TicketsEliminados" ADD CONSTRAINT "TicketsEliminados_id_user_fkey" FOREIGN KEY ("id_user") REFERENCES "usuario"("id_user") ON DELETE RESTRICT ON UPDATE CASCADE;

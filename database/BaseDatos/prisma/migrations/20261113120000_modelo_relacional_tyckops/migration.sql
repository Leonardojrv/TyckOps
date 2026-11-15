-- Alinea la base con el "Modelo relacional TyckOps (PostgreSQL)".
-- Escrita a mano: renombra tablas/columnas en vez de recrearlas, para conservar
-- los datos de Roles, Departamento, Usuario y CategoriaReparacion.
-- Las tablas que se eliminan o recrean (Ticket, CargaReglas, UsuariosEliminados,
-- TicketsEliminados) estaban vacías.

-- ============================================================
-- 1. Quitar FKs y tablas que salen del modelo
-- ============================================================
ALTER TABLE "usuario" DROP CONSTRAINT "usuario_id_rol_fkey";
ALTER TABLE "usuario" DROP CONSTRAINT "usuario_id_depa_fkey";
ALTER TABLE "usuario" DROP CONSTRAINT "usuario_id_regla_fkey";

DROP TABLE "TicketsEliminados";
DROP TABLE "UsuariosEliminados";
DROP TABLE "Ticket";
DROP TABLE "CargaReglas";

-- ============================================================
-- 2. Roles
-- ============================================================
ALTER TABLE "Roles" RENAME COLUMN "id_rol" TO "ID_Rol";
ALTER TABLE "Roles" RENAME COLUMN "nombreRol" TO "NombreRol";
ALTER TABLE "Roles" ALTER COLUMN "NombreRol" TYPE VARCHAR(100);
ALTER TABLE "Roles" RENAME CONSTRAINT "Roles_pkey" TO "Roles_PK";
ALTER SEQUENCE "Roles_id_rol_seq" RENAME TO "Roles_ID_Rol_seq";

-- ============================================================
-- 3. Departamento
-- ============================================================
ALTER TABLE "departamento" RENAME TO "Departamento";
ALTER TABLE "Departamento" RENAME COLUMN "id_depa" TO "ID_depa";
ALTER TABLE "Departamento" RENAME CONSTRAINT "departamento_pkey" TO "Departamento_PK";
ALTER SEQUENCE "departamento_id_depa_seq" RENAME TO "Departamento_ID_depa_seq";

-- ============================================================
-- 4. CategoriaReparacion
-- ============================================================
ALTER TABLE "CategoriaReparacion" RENAME COLUMN "id_caterepa" TO "ID_CateRepa";
ALTER TABLE "CategoriaReparacion" RENAME CONSTRAINT "CategoriaReparacion_pkey" TO "CategoriaReparacion_PK";
ALTER SEQUENCE "CategoriaReparacion_id_caterepa_seq" RENAME TO "CategoriaReparacion_ID_CateRepa_seq";

-- ============================================================
-- 5. Usuario
-- ============================================================
ALTER TABLE "usuario" RENAME TO "Usuario";
ALTER TABLE "Usuario" RENAME COLUMN "id_user" TO "ID_user";
ALTER TABLE "Usuario" RENAME COLUMN "id_depa" TO "ID_depa";
ALTER TABLE "Usuario" RENAME COLUMN "id_rol" TO "ID_Rol";
ALTER TABLE "Usuario" DROP COLUMN "id_regla";
ALTER TABLE "Usuario" ALTER COLUMN "password" TYPE VARCHAR(255);
ALTER TABLE "Usuario"
    ADD COLUMN "estado"   VARCHAR(50),
    ADD COLUMN "Cargo"    VARCHAR(150),
    ADD COLUMN "telefono" VARCHAR(50);
ALTER TABLE "Usuario" RENAME CONSTRAINT "usuario_pkey" TO "Usuario_PK";
ALTER SEQUENCE "usuario_id_user_seq" RENAME TO "Usuario_ID_user_seq";

-- Nota: ID_depa / ID_Rol quedan antes que estado/Cargo/telefono en el orden
-- físico (moverlas exigiría recrear la tabla); no afecta a Prisma ni a las consultas.

CREATE UNIQUE INDEX "Usuario_correo_UK" ON "Usuario"("correo");

ALTER TABLE "Usuario" ADD CONSTRAINT "Usuario_Departamento_FK"
    FOREIGN KEY ("ID_depa") REFERENCES "Departamento"("ID_depa") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "Usuario" ADD CONSTRAINT "Usuario_Roles_FK"
    FOREIGN KEY ("ID_Rol") REFERENCES "Roles"("ID_Rol") ON DELETE RESTRICT ON UPDATE CASCADE;

-- ============================================================
-- 6. Ticket (recreada: estaba vacía y cambia casi entera)
-- ============================================================
CREATE TABLE "Ticket" (
    "ID_Ticket"          SERIAL NOT NULL,
    "Descripcion"        VARCHAR(500) NOT NULL,
    "Estado"             VARCHAR(50) NOT NULL DEFAULT 'recibido',
    "Ubicacion"          VARCHAR(150) NOT NULL,
    "Piso"               VARCHAR(50),
    "Prioridad"          VARCHAR(150),
    "imagen"             BYTEA,
    "NivelIncidencia"    VARCHAR(150),
    "TipoSolucion"       VARCHAR(150),
    "FechaCreacion"      TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "FechaCierre"        TIMESTAMP(6),
    "MotivoRechazo"      VARCHAR(255),
    "ID_TicketOriginal"  INTEGER,
    "ID_user"            INTEGER NOT NULL,
    "ID_CateRepa"        INTEGER NOT NULL,
    "ID_admin_aprobador" INTEGER,

    CONSTRAINT "Ticket_PK" PRIMARY KEY ("ID_Ticket"),

    CONSTRAINT "ck_ticket_estado" CHECK ("Estado" IN
        ('recibido','en_revision','aprobado','rechazado','en_proceso','resuelto','cerrado','cancelado')),
    CONSTRAINT "ck_ticket_motivo_rechazo" CHECK ("Estado" <> 'rechazado' OR char_length("MotivoRechazo") >= 100),
    CONSTRAINT "ck_ticket_aprobador" CHECK ("ID_admin_aprobador" IS NULL OR "ID_admin_aprobador" <> "ID_user"),
    CONSTRAINT "ck_ticket_fecha_cierre" CHECK ("FechaCierre" IS NULL OR "FechaCierre" >= "FechaCreacion")
);

ALTER TABLE "Ticket" ADD CONSTRAINT "Ticket_Ticket_FK"
    FOREIGN KEY ("ID_TicketOriginal") REFERENCES "Ticket"("ID_Ticket") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "Ticket" ADD CONSTRAINT "Ticket_Usuario_FK"
    FOREIGN KEY ("ID_user") REFERENCES "Usuario"("ID_user") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "Ticket" ADD CONSTRAINT "Ticket_CategoriaReparacion_FK"
    FOREIGN KEY ("ID_CateRepa") REFERENCES "CategoriaReparacion"("ID_CateRepa") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "Ticket" ADD CONSTRAINT "Ticket_Aprobador_FK"
    FOREIGN KEY ("ID_admin_aprobador") REFERENCES "Usuario"("ID_user") ON DELETE SET NULL ON UPDATE CASCADE;

-- ============================================================
-- 7. Tablas nuevas: Informe, ReglasPrioridad, GuiaAutoayuda
-- ============================================================
CREATE TABLE "Informe" (
    "ID_informe"      SERIAL NOT NULL,
    "Archivo"         BYTEA NOT NULL,
    "FechaGeneracion" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "ID_user"         INTEGER NOT NULL,

    CONSTRAINT "Informe_PK" PRIMARY KEY ("ID_informe")
);

CREATE TABLE "ReglasPrioridad" (
    "ID_Regla"       SERIAL NOT NULL,
    "archivo"        TEXT NOT NULL,
    "FechaInsercion" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "ID_user"        INTEGER NOT NULL,

    CONSTRAINT "ReglasPrioridad_PK" PRIMARY KEY ("ID_Regla")
);

CREATE TABLE "GuiaAutoayuda" (
    "ID_Guia"        SERIAL NOT NULL,
    "archivo"        TEXT NOT NULL,
    "FechaInsercion" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "ID_user"        INTEGER NOT NULL,

    CONSTRAINT "GuiaAutoayuda_PK" PRIMARY KEY ("ID_Guia")
);

ALTER TABLE "Informe" ADD CONSTRAINT "Informe_Usuario_FK"
    FOREIGN KEY ("ID_user") REFERENCES "Usuario"("ID_user") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "ReglasPrioridad" ADD CONSTRAINT "ReglasPrioridad_Usuario_FK"
    FOREIGN KEY ("ID_user") REFERENCES "Usuario"("ID_user") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "GuiaAutoayuda" ADD CONSTRAINT "GuiaAutoayuda_Usuario_FK"
    FOREIGN KEY ("ID_user") REFERENCES "Usuario"("ID_user") ON DELETE RESTRICT ON UPDATE CASCADE;

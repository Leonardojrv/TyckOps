-- T11 · Notificaciones push.
--  - DispositivoPush: el token de Firebase de cada celular del usuario.
--    Un token pertenece a una sola persona (UNIQUE): si otra inicia sesión en
--    el mismo celular, el token se reasigna y nadie recibe avisos ajenos.
--  - Notificacion: el historial que ve el colaborador en "Notificaciones"
--    (cambios de estado y "Nuevo comentario en tu ticket").
-- Tablas nuevas: no modifica datos existentes.

-- CreateTable
CREATE TABLE "DispositivoPush" (
    "ID_Dispositivo" SERIAL NOT NULL,
    "Token" VARCHAR(512) NOT NULL,
    "Plataforma" VARCHAR(10) NOT NULL,
    "FechaRegistro" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "FechaUltimoUso" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "ID_user" INTEGER NOT NULL,

    CONSTRAINT "DispositivoPush_PK" PRIMARY KEY ("ID_Dispositivo"),
    CONSTRAINT "ck_dispositivo_plataforma" CHECK ("Plataforma" IN ('android', 'ios')),
    -- Los tokens de Firebase solo traen letras, números y : _ - (entre 20 y 512).
    -- El largo va aparte: PostgreSQL no acepta repeticiones {20,512} (máximo 255).
    CONSTRAINT "ck_dispositivo_token" CHECK ("Token" ~ '^[A-Za-z0-9:_-]+$' AND char_length("Token") BETWEEN 20 AND 512)
);

-- CreateTable
CREATE TABLE "Notificacion" (
    "ID_Notificacion" SERIAL NOT NULL,
    "Tipo" VARCHAR(20) NOT NULL,
    "Titulo" VARCHAR(120) NOT NULL,
    "Cuerpo" VARCHAR(300) NOT NULL,
    "EstadoTicket" VARCHAR(50),
    "Leida" BOOLEAN NOT NULL DEFAULT false,
    "FechaCreacion" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "ID_user" INTEGER NOT NULL,
    "ID_Ticket" INTEGER NOT NULL,
    "ID_Comentario" INTEGER,

    CONSTRAINT "Notificacion_PK" PRIMARY KEY ("ID_Notificacion"),
    CONSTRAINT "ck_notificacion_tipo" CHECK ("Tipo" IN ('estado', 'comentario')),
    -- Un aviso de comentario siempre dice qué comentario es.
    CONSTRAINT "ck_notificacion_comentario" CHECK ("Tipo" <> 'comentario' OR "ID_Comentario" IS NOT NULL)
);

-- CreateIndex
CREATE UNIQUE INDEX "DispositivoPush_Token_UK" ON "DispositivoPush"("Token");

-- CreateIndex
CREATE INDEX "DispositivoPush_Usuario_IDX" ON "DispositivoPush"("ID_user");

-- CreateIndex (la pantalla lista por usuario, de la más nueva a la más antigua)
CREATE INDEX "Notificacion_Usuario_Fecha_IDX" ON "Notificacion"("ID_user", "FechaCreacion");

-- AddForeignKey
ALTER TABLE "DispositivoPush" ADD CONSTRAINT "DispositivoPush_Usuario_FK" FOREIGN KEY ("ID_user") REFERENCES "Usuario"("ID_user") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Notificacion" ADD CONSTRAINT "Notificacion_Usuario_FK" FOREIGN KEY ("ID_user") REFERENCES "Usuario"("ID_user") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Notificacion" ADD CONSTRAINT "Notificacion_Ticket_FK" FOREIGN KEY ("ID_Ticket") REFERENCES "Ticket"("ID_Ticket") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Notificacion" ADD CONSTRAINT "Notificacion_Comentario_FK" FOREIGN KEY ("ID_Comentario") REFERENCES "ComentarioTicket"("ID_Comentario") ON DELETE SET NULL ON UPDATE CASCADE;

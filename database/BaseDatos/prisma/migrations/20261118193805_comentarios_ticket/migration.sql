-- Tabla de comentarios del administrador sobre un ticket (T7 los muestra, T13 los escribe).
-- Cada comentario pertenece a UN ticket y a UN administrador. Si se borra el ticket,
-- sus comentarios se borran con él. No es un chat: el colaborador solo los lee.

-- CreateTable
CREATE TABLE "ComentarioTicket" (
    "ID_Comentario" SERIAL NOT NULL,
    "Texto" VARCHAR(500) NOT NULL,
    "FechaCreacion" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "ID_Ticket" INTEGER NOT NULL,
    "ID_admin" INTEGER NOT NULL,

    CONSTRAINT "ComentarioTicket_PK" PRIMARY KEY ("ID_Comentario")
);

-- CreateIndex
CREATE INDEX "ComentarioTicket_Ticket_IDX" ON "ComentarioTicket"("ID_Ticket");

-- AddForeignKey
ALTER TABLE "ComentarioTicket" ADD CONSTRAINT "ComentarioTicket_Ticket_FK" FOREIGN KEY ("ID_Ticket") REFERENCES "Ticket"("ID_Ticket") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ComentarioTicket" ADD CONSTRAINT "ComentarioTicket_Usuario_FK" FOREIGN KEY ("ID_admin") REFERENCES "Usuario"("ID_user") ON DELETE RESTRICT ON UPDATE CASCADE;

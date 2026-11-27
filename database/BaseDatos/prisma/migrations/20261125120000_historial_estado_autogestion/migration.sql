ALTER TABLE "Ticket" DROP CONSTRAINT "ck_ticket_estado";
ALTER TABLE "Ticket" ADD CONSTRAINT "ck_ticket_estado" CHECK ("Estado" IN
    ('recibido','en_revision','aprobado','rechazado','en_proceso','resuelto','cerrado','cancelado','autogestion'));
ALTER TABLE "Ticket" DROP CONSTRAINT "ck_ticket_motivo_rechazo";
ALTER TABLE "Ticket" ADD CONSTRAINT "ck_ticket_motivo_rechazo" CHECK
    ("Estado" <> 'rechazado' OR ("MotivoRechazo" IS NOT NULL AND char_length("MotivoRechazo") >= 100));

CREATE TABLE "HistorialEstadoTicket" (
    "ID_CambioEstado" SERIAL NOT NULL,
    "EstadoAnterior"  VARCHAR(50),
    "EstadoNuevo"     VARCHAR(50) NOT NULL,
    "Fecha"           TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "Motivo"          VARCHAR(255),
    "ID_Ticket"       INTEGER NOT NULL,
    "ID_user"         INTEGER NOT NULL,

    CONSTRAINT "HistorialEstadoTicket_PK" PRIMARY KEY ("ID_CambioEstado"),
    CONSTRAINT "ck_historial_estado_rechazo" CHECK
        ("EstadoNuevo" <> 'rechazado' OR ("Motivo" IS NOT NULL AND char_length("Motivo") >= 100))
);

CREATE INDEX "HistorialEstadoTicket_Ticket_Fecha_IDX"
    ON "HistorialEstadoTicket"("ID_Ticket", "Fecha");
CREATE INDEX "HistorialEstadoTicket_Usuario_IDX"
    ON "HistorialEstadoTicket"("ID_user");

ALTER TABLE "HistorialEstadoTicket" ADD CONSTRAINT "HistorialEstadoTicket_Ticket_FK"
    FOREIGN KEY ("ID_Ticket") REFERENCES "Ticket"("ID_Ticket") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "HistorialEstadoTicket" ADD CONSTRAINT "HistorialEstadoTicket_Usuario_FK"
    FOREIGN KEY ("ID_user") REFERENCES "Usuario"("ID_user") ON DELETE RESTRICT ON UPDATE CASCADE;

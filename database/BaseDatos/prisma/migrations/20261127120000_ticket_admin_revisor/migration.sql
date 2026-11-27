-- Quién decidió la revisión de un ticket (aprobarlo o rechazarlo).
-- Antes la columna era "ID_admin_aprobador" y solo se llenaba al aprobar, así
-- que no quedaba registrado quién rechazaba. Ahora se llama "ID_admin_revisor"
-- y se llena al pasar de "en_revision" a "aprobado" o a "rechazado"; el Estado
-- dice cuál fue la decisión.
-- Solo renombres: no se modifican ni se pierden datos. PostgreSQL actualiza
-- solo la FK y el CHECK para que apunten a la columna con su nombre nuevo.

ALTER TABLE "Ticket" RENAME COLUMN "ID_admin_aprobador" TO "ID_admin_revisor";

-- Sigue igual: SET NULL si se borra el usuario, CASCADE si cambia su ID.
ALTER TABLE "Ticket" RENAME CONSTRAINT "Ticket_Aprobador_FK" TO "Ticket_Revisor_FK";

-- Sigue igual: nadie aprueba ni rechaza un ticket que creó.
ALTER TABLE "Ticket" RENAME CONSTRAINT "ck_ticket_aprobador" TO "ck_ticket_revisor";

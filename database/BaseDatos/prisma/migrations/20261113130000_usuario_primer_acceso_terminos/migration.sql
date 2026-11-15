-- Columnas que el backend necesita para el primer acceso (RF-02) y la
-- aceptación de Términos (RF-03). No están en el modelo relacional original.
ALTER TABLE "Usuario"
    ADD COLUMN "primerAcceso"            BOOLEAN NOT NULL DEFAULT true,
    ADD COLUMN "terminosAceptados"       BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN "versionTerminos"         VARCHAR(32),
    ADD COLUMN "fechaAceptacionTerminos" TIMESTAMP(6);

-- El backend solo reconoce los roles COLABORADOR y ADMINISTRADOR.
UPDATE "Roles" SET "NombreRol" = 'administrador' WHERE "NombreRol" = 'supervisor';

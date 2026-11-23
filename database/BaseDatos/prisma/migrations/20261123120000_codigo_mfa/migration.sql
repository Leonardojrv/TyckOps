-- T8 · Verificación en dos pasos (MFA) por código al correo.
--  - Cada fila es un desafío MFA: se crea tras una contraseña correcta y vale
--    3 minutos. Se borra al usarse, al agotar intentos o al vencer.
--  - El código se guarda solo como hash Argon2id (formato PHC, cabe en 255).
--  - ID_CodigoMFA (UUID) es el id del desafío que viaja en el pase MFA (jwtid).
-- Tabla nueva: no modifica datos existentes.

-- CreateTable
CREATE TABLE "CodigoMFA" (
    "ID_CodigoMFA" UUID NOT NULL,
    "CodigoHash" VARCHAR(255) NOT NULL,
    "FechaCreacion" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "UltimoEnvio" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "FechaExpiracion" TIMESTAMPTZ(6) NOT NULL,
    "Intentos" SMALLINT NOT NULL DEFAULT 0,
    "Reenvios" SMALLINT NOT NULL DEFAULT 0,
    "ID_user" INTEGER NOT NULL,

    CONSTRAINT "CodigoMFA_PK" PRIMARY KEY ("ID_CodigoMFA"),
    -- Solo hashes Argon2id: si alguien intenta guardar el código en claro, falla.
    CONSTRAINT "ck_codigomfa_hash" CHECK ("CodigoHash" LIKE '$argon2id$%'),
    -- Vigencia máxima de 3 minutos desde el último envío (y nunca hacia atrás).
    CONSTRAINT "ck_codigomfa_vigencia" CHECK (
        "FechaExpiracion" > "UltimoEnvio"
        AND "FechaExpiracion" <= "UltimoEnvio" + INTERVAL '3 minutes'
    ),
    CONSTRAINT "ck_codigomfa_envio" CHECK ("UltimoEnvio" >= "FechaCreacion"),
    CONSTRAINT "ck_codigomfa_contadores" CHECK ("Intentos" >= 0 AND "Reenvios" >= 0)
);

-- CreateIndex
CREATE INDEX "CodigoMFA_Usuario_IDX" ON "CodigoMFA"("ID_user");

-- CreateIndex (para borrar rápido los vencidos)
CREATE INDEX "CodigoMFA_Expiracion_IDX" ON "CodigoMFA"("FechaExpiracion");

-- AddForeignKey
ALTER TABLE "CodigoMFA" ADD CONSTRAINT "CodigoMFA_Usuario_FK" FOREIGN KEY ("ID_user") REFERENCES "Usuario"("ID_user") ON DELETE CASCADE ON UPDATE CASCADE;

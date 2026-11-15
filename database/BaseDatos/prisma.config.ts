import "dotenv/config";
import { defineConfig } from "prisma/config";

// Prisma 6: la URL de conexión se lee desde schema.prisma (env("DATABASE_URL")).
export default defineConfig({
  schema: "prisma/schema.prisma",
  migrations: {
    path: "prisma/migrations",
    seed: "node prisma/seed.js",
  },
});

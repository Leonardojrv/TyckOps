export async function connectPrisma(databaseUrl) {
  if (!databaseUrl) return null;

  const { PrismaClient } = await import('@prisma/client');
  const prisma = new PrismaClient({
    datasources: { db: { url: databaseUrl } },
  });

  await prisma.$connect();
  return prisma;
}
export class PrismaUserRepository {
  constructor(prisma) {
    this.prisma = prisma;
  }

  findByEmail(email) {
    if (!this.prisma.user?.findUnique) {
      throw new Error('El cliente Prisma no tiene el modelo User esperado.');
    }
    return this.prisma.user.findUnique({ where: { email } });
  }

  findById(id) {
    if (!this.prisma.user?.findUnique) {
      throw new Error('El cliente Prisma no tiene el modelo User esperado.');
    }
    return this.prisma.user.findUnique({ where: { id } });
  }
}
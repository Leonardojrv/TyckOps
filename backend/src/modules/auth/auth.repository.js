// En la BD el rol y el área están en tablas aparte (Roles, Departamento).
// Este repositorio los trae y los aplana a `role` y `area`, que es lo que espera AuthService.
const relaciones = { rol: true, departamento: true };

function aplanar(user) {
  if (!user) return null;
  const { rol, departamento, ...resto } = user;
  return { ...resto, role: rol?.NombreRol ?? null, area: departamento?.nom_depa ?? null };
}

// El id llega como string desde el JWT; en la BD es entero.
function idNumerico(id) {
  const numero = Number(id);
  return Number.isInteger(numero) ? numero : null;
}

export class PrismaUserRepository {
  constructor(prisma) {
    if (!prisma.user?.findFirst) {
      throw new Error('El cliente Prisma no tiene el modelo User esperado.');
    }
    this.prisma = prisma;
  }

  async findByEmail(email) {
    // Sin distinguir mayúsculas: el login normaliza a minúsculas, la BD puede no estarlo.
    const user = await this.prisma.user.findFirst({
      where: { email: { equals: email, mode: 'insensitive' } },
      include: relaciones,
    });
    return aplanar(user);
  }

  async findById(id) {
    const numero = idNumerico(id);
    if (numero === null) return null;
    return aplanar(await this.prisma.user.findUnique({ where: { id: numero }, include: relaciones }));
  }

  async update(id, data) {
    const user = await this.prisma.user.update({
      where: { id: idNumerico(id) },
      data,
      include: relaciones,
    });
    return aplanar(user);
  }
}

import bcrypt from 'bcryptjs';

export class MemoryUserRepository {
  constructor(users) {
    this.users = new Map(users.map((user) => [user.email.toLowerCase(), user]));
    this.usersById = new Map(users.map((user) => [String(user.id), user]));
  }

  async findByEmail(email) {
    return this.users.get(email.toLowerCase()) ?? null;
  }

  async findById(id) {
    return this.usersById.get(String(id)) ?? null;
  }
}

export async function crearRepositorioEnMemoria(accounts) {
  const users = await Promise.all(accounts.map(async ({ password, ...user }) => ({
    ...user,
    email: user.email.toLowerCase(),
    passwordHash: await bcrypt.hash(password, 10),
  })));

  return new MemoryUserRepository(users);
}
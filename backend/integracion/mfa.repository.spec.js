// MFA (T8) contra PostgreSQL real: tabla CodigoMFA y PrismaMfaRepository.
import { crearClientePruebas, reiniciarDatos } from './helpers/baseDePruebas.js';
import { PrismaMfaRepository, VIGENCIA_MFA_MS } from '../src/modules/auth/mfa.repository.js';

let prisma;
let usuarios;

beforeAll(async () => {
  prisma = crearClientePruebas();
  usuarios = await reiniciarDatos(prisma);
});

afterAll(async () => {
  await prisma.$disconnect();
});

beforeEach(async () => {
  await prisma.codigoMFA.deleteMany();
});

const repo = (opciones) => new PrismaMfaRepository(prisma, opciones);
const userId = () => usuarios.colaboradorActivo.id;

describe('Guardado cifrado', () => {
  test('el código se guarda como Argon2id, nunca en claro, y vence en 3 minutos', async () => {
    const d = await repo().crear({ userId: userId(), codigo: '482913' });
    const fila = await prisma.codigoMFA.findUnique({ where: { ID_CodigoMFA: d.id } });

    expect(fila.CodigoHash).toMatch(/^\$argon2id\$v=19\$m=19456,t=2,p=1\$/);
    expect(fila.CodigoHash).not.toContain('482913');
    expect(fila.FechaExpiracion.getTime() - fila.UltimoEnvio.getTime()).toBe(VIGENCIA_MFA_MS);
    expect(d).not.toHaveProperty('CodigoHash');
  });

  test('la BD rechaza un código en claro (ck_codigomfa_hash)', async () => {
    const ahora = new Date();
    await expect(prisma.codigoMFA.create({
      data: { ID_user: userId(), CodigoHash: '123456', UltimoEnvio: ahora, FechaCreacion: ahora, FechaExpiracion: new Date(ahora.getTime() + 60_000) },
    })).rejects.toThrow(/ck_codigomfa_hash/);
  });

  test('la BD rechaza una vigencia mayor a 3 minutos (ck_codigomfa_vigencia)', async () => {
    const d = await repo().crear({ userId: userId(), codigo: '111111' });
    await expect(prisma.codigoMFA.update({
      where: { ID_CodigoMFA: d.id },
      data: { FechaExpiracion: new Date(d.ultimoEnvio.getTime() + VIGENCIA_MFA_MS + 1000) },
    })).rejects.toThrow(/ck_codigomfa_vigencia/);
  });

  test('el repositorio no acepta configurar más de 3 minutos', () => {
    expect(() => repo({ vigenciaMs: VIGENCIA_MFA_MS + 1 })).toThrow(/3 minutos/);
  });
});

describe('Verificación', () => {
  test('código correcto: se acepta una sola vez', async () => {
    const r = repo();
    const d = await r.crear({ userId: userId(), codigo: '654321' });

    expect(await r.verificar(d.id, '654321')).toEqual({ estado: 'correcto', userId: String(userId()) });
    expect(await r.verificar(d.id, '654321')).toEqual({ estado: 'inexistente' });
  });

  test('dos verificaciones simultáneas con el código correcto: solo una pasa', async () => {
    const r = repo();
    const d = await r.crear({ userId: userId(), codigo: '777777' });
    const resultados = await Promise.all([r.verificar(d.id, '777777'), r.verificar(d.id, '777777')]);
    expect(resultados.filter((x) => x.estado === 'correcto')).toHaveLength(1);
  });

  test('código incorrecto suma intentos y al tercero se bloquea', async () => {
    const r = repo();
    const d = await r.crear({ userId: userId(), codigo: '000001' });
    for (let i = 1; i <= 2; i += 1) {
      expect(await r.verificar(d.id, '999999')).toEqual({ estado: 'incorrecto', intentos: i, quedan: 3 - i });
    }
    expect(await r.verificar(d.id, '999999')).toEqual({ estado: 'bloqueado', intentos: 3 });
    expect(await r.verificar(d.id, '000001')).toEqual({ estado: 'inexistente' });
  });

  test('código vencido: se rechaza y se borra', async () => {
    let reloj = new Date();
    const r = repo({ ahora: () => reloj });
    const d = await r.crear({ userId: userId(), codigo: '123123' });
    reloj = new Date(reloj.getTime() + VIGENCIA_MFA_MS);

    expect(await r.verificar(d.id, '123123')).toEqual({ estado: 'vencido' });
    expect(await r.buscar(d.id)).toBeNull();
  });

  test('id con formato inválido se trata como inexistente', async () => {
    expect(await repo().verificar('no-es-uuid', '123456')).toEqual({ estado: 'inexistente' });
  });
});

describe('Ciclo de vida', () => {
  test('un desafío nuevo anula el anterior del mismo usuario', async () => {
    const r = repo();
    const viejo = await r.crear({ userId: userId(), codigo: '111111' });
    await r.crear({ userId: userId(), codigo: '222222' });

    expect(await r.buscar(viejo.id)).toBeNull();
    expect(await prisma.codigoMFA.count({ where: { ID_user: userId() } })).toBe(1);
  });

  test('reenviar: el código anterior deja de servir y los intentos vuelven a 0', async () => {
    const r = repo();
    const d = await r.crear({ userId: userId(), codigo: '111111' });
    await r.verificar(d.id, '999999');

    const nuevo = await r.reemplazarCodigo(d.id, '222222');
    expect(nuevo).toMatchObject({ intentos: 0, reenvios: 1 });
    expect(await r.verificar(d.id, '111111')).toMatchObject({ estado: 'incorrecto' });
    expect(await r.verificar(d.id, '222222')).toMatchObject({ estado: 'correcto' });
  });

  test('limpiarVencidos borra solo los vencidos', async () => {
    let reloj = new Date();
    const r = repo({ ahora: () => reloj });
    await r.crear({ userId: usuarios.colaboradorActivo.id, codigo: '111111' });
    reloj = new Date(reloj.getTime() + VIGENCIA_MFA_MS + 1000);
    await r.crear({ userId: usuarios.adminActivo.id, codigo: '222222' });

    expect(await r.limpiarVencidos()).toBe(1);
    expect(await prisma.codigoMFA.count()).toBe(1);
  });

  test('al borrar el usuario se borran sus códigos (Cascade)', async () => {
    await repo().crear({ userId: userId(), codigo: '333333' });
    await prisma.ticket.deleteMany({ where: { ID_user: userId() } });
    await prisma.user.delete({ where: { id: userId() } });
    expect(await prisma.codigoMFA.count()).toBe(0);
  });
});

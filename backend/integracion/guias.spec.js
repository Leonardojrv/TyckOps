import request from 'supertest';
import ExcelJS from 'exceljs';
import { crearApp } from '../src/app.js';
import { AuthService } from '../src/modules/auth/auth.service.js';
import { crearRepositorioEnMemoria } from '../src/modules/auth/auth.memory.repository.js';
import { MemoryGuiasRepository } from '../src/modules/guias/guias.memory.repository.js';
import { GuiasService } from '../src/modules/guias/guias.service.js';
import { firmarToken, ENV_PRUEBAS } from './helpers/app.js';

async function crearExcelBuffer({ columnas, filas }) {
  const wb = new ExcelJS.Workbook();
  const ws = wb.addWorksheet('Plantilla');
  if (columnas) ws.addRow(columnas);
  for (const f of filas) ws.addRow(f);
  const buffer = await wb.xlsx.writeBuffer();
  return Buffer.from(buffer);
}

describe('Módulo de Guías de Autoayuda (Servicios Generales)', () => {
  let app;
  let adminToken;
  let colabToken;

  beforeEach(async () => {
    const userRepo = await crearRepositorioEnMemoria([
      { id: 'admin-1', name: 'Admin', email: 'admin@gamaitaly.cl', password: 'AdminPassword2026!', role: 'ADMINISTRADOR', termsAccepted: true, isFirstLogin: false },
      { id: 'colab-1', name: 'Colaborador', email: 'colab@gamaitaly.cl', password: 'WorkerPassword2026!', role: 'COLABORADOR', termsAccepted: true, isFirstLogin: false },
    ]);
    const authService = new AuthService(userRepo, ENV_PRUEBAS);
    const guiasRepo = new MemoryGuiasRepository();
    const guiasService = new GuiasService(guiasRepo);

    app = crearApp({
      env: ENV_PRUEBAS,
      authService,
      guiasService,
    });

    adminToken = firmarToken({ id: 'admin-1', role: 'ADMINISTRADOR' });
    colabToken = firmarToken({ id: 'colab-1', role: 'COLABORADOR' });
  });

  describe('Control de acceso por rol', () => {
    test('rechaza 401 si no hay token de autenticación', async () => {
      const res = await request(app).get('/guias/plantilla');
      expect(res.status).toBe(401);
    });

    test('rechaza 403 SIN_ROL_ADMIN si el usuario es colaborador', async () => {
      const res = await request(app)
        .get('/guias/plantilla')
        .set('Authorization', `Bearer ${colabToken}`);
      expect(res.status).toBe(403);
      expect(res.body.error.code).toBe('SIN_ROL_ADMIN');
    });
  });

  describe('GET /guias/plantilla', () => {
    test('entrega el archivo Excel con las 5 columnas requeridas', async () => {
      const res = await request(app)
        .get('/guias/plantilla')
        .set('Authorization', `Bearer ${adminToken}`)
        .responseType('blob');

      expect(res.status).toBe(200);
      expect(res.headers['content-type']).toContain('spreadsheetml.sheet');
      expect(res.headers['content-disposition']).toContain('plantilla_guias.xlsx');

      const wb = new ExcelJS.Workbook();
      await wb.xlsx.load(res.body);
      const ws = wb.worksheets[0];
      const headers = [
        ws.getCell('A1').text.toLowerCase(),
        ws.getCell('B1').text.toLowerCase(),
        ws.getCell('C1').text.toLowerCase(),
        ws.getCell('D1').text.toLowerCase(),
        ws.getCell('E1').text.toLowerCase(),
      ];
      expect(headers).toEqual(['id', 'categoría', 'problema', 'pasos', 'autogestionable']);
    });
  });

  describe('POST /guias/archivo', () => {
    test('rechaza si no se adjunta ningún archivo', async () => {
      const res = await request(app)
        .post('/guias/archivo')
        .set('Authorization', `Bearer ${adminToken}`);

      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe('ARCHIVO_REQUERIDO');
    });

    test('rechaza archivo con columnas faltantes', async () => {
      const buf = await crearExcelBuffer({
        columnas: ['id', 'categoria'],
        filas: [['1', 'electrica']],
      });

      const res = await request(app)
        .post('/guias/archivo')
        .set('Authorization', `Bearer ${adminToken}`)
        .attach('archivo', buf, 'incompleto.xlsx');

      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe('COLUMNAS_INVALIDAS');
    });

    test('responde con errores por fila si hay datos inválidos', async () => {
      const buf = await crearExcelBuffer({
        columnas: ['id', 'categoría', 'problema', 'pasos', 'autogestionable'],
        filas: [
          ['1', 'categoria_inventada', 'Falla en enchufe', 'Revisar interruptor', 'SI'],
          ['2', 'electrica', 'Ok', 'Pasos para revisar', 'SI'], // problema < 3 caracteres
          ['3', 'banos', 'Llave con fuga', 'Corto', 'QUIZAS'], // pasos < 5 y autogestionable inválido
        ],
      });

      const res = await request(app)
        .post('/guias/archivo')
        .set('Authorization', `Bearer ${adminToken}`)
        .attach('archivo', buf, 'errores.xlsx');

      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe('ERRORES_VALIDACION');
      expect(Array.isArray(res.body.error.details)).toBe(true);

      const filasConError = res.body.error.details.map((d) => d.fila);
      expect(filasConError).toContain(2);
      expect(filasConError).toContain(3);
      expect(filasConError).toContain(4);
    });

    test('procesa archivo válido, sanitiza HTML y guarda la versión', async () => {
      const buf = await crearExcelBuffer({
        columnas: ['id', 'categoría', 'problema', 'pasos', 'autogestionable'],
        filas: [
          ['1', 'electrica', '<script>alert("xss")</script>Luz no enciende', '<p>1. Cambiar <b>ampolleta</b>.</p>', 'SI'],
          ['2', 'aire acondicionado', 'Control remoto averiado', '1. Reemplazar baterías AAA.', 'NO'],
        ],
      });

      const res = await request(app)
        .post('/guias/archivo')
        .set('Authorization', `Bearer ${adminToken}`)
        .attach('archivo', buf, 'guias.xlsx');

      expect(res.status).toBe(201);
      expect(res.body.success).toBe(true);
      expect(res.body.data.version).toBe('v1');
      expect(res.body.data.totalGuias).toBe(2);

      const [g1, g2] = res.body.data.guias;
      expect(g1.problema).toBe('Luz no enciende');
      expect(g1.pasos).toBe('1. Cambiar ampolleta.');
      expect(g1.autogestionable).toBe(true);
      expect(g2.categoria).toBe('AIRE_ACONDICIONADO');
      expect(g2.autogestionable).toBe(false);
    });
  });

  describe('POST /guias/:version/activar y GET /guias', () => {
    test('publica la versión nueva, conserva la anterior y lista las vigentes', async () => {
      // 1. Subir primera versión
      const buf1 = await crearExcelBuffer({
        columnas: ['id', 'categoría', 'problema', 'pasos', 'autogestionable'],
        filas: [['1', 'electrica', 'Falla de luces', 'Revisar tablero', 'SI']],
      });
      const upload1 = await request(app)
        .post('/guias/archivo')
        .set('Authorization', `Bearer ${adminToken}`)
        .attach('archivo', buf1, 'v1.xlsx');
      const v1 = upload1.body.data.version;

      // 2. Activar v1
      const act1 = await request(app)
        .post(`/guias/${v1}/activar`)
        .set('Authorization', `Bearer ${adminToken}`);
      expect(act1.status).toBe(200);
      expect(act1.body.data.activa).toBe(true);

      // 3. Consultar vigentes -> Debe devolver v1
      const vig1 = await request(app)
        .get('/guias')
        .set('Authorization', `Bearer ${adminToken}`);
      expect(vig1.status).toBe(200);
      expect(vig1.body.data.version).toBe(v1);
      expect(vig1.body.data.total).toBe(1);

      // 4. Subir segunda versión v2
      const buf2 = await crearExcelBuffer({
        columnas: ['id', 'categoría', 'problema', 'pasos', 'autogestionable'],
        filas: [
          ['10', 'banos', 'Inodoro tapado', 'Usar sopapa', 'SI'],
          ['20', 'inmobiliario', 'Cajón atascado', 'Lubricar riel', 'SI'],
        ],
      });
      const upload2 = await request(app)
        .post('/guias/archivo')
        .set('Authorization', `Bearer ${adminToken}`)
        .attach('archivo', buf2, 'v2.xlsx');
      const v2 = upload2.body.data.version;

      // 5. Activar v2
      const act2 = await request(app)
        .post(`/guias/${v2}/activar`)
        .set('Authorization', `Bearer ${adminToken}`);
      expect(act2.status).toBe(200);
      expect(act2.body.data.version).toBe(v2);

      // 6. Consultar vigentes -> Ahora debe devolver v2 con 2 guías
      const vig2 = await request(app)
        .get('/guias')
        .set('Authorization', `Bearer ${adminToken}`);
      expect(vig2.status).toBe(200);
      expect(vig2.body.data.version).toBe(v2);
      expect(vig2.body.data.total).toBe(2);
      expect(vig2.body.data.guias[0].categoria).toBe('BANOS');
    });

    test('devuelve 404 si la versión no existe', async () => {
      const res = await request(app)
        .post('/guias/v_no_existe/activar')
        .set('Authorization', `Bearer ${adminToken}`);
      expect(res.status).toBe(404);
      expect(res.body.error.code).toBe('VERSION_NO_ENCONTRADA');
    });
  });
});

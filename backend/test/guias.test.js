import assert from 'node:assert/strict';
import { after, test } from 'node:test';
import jwt from 'jsonwebtoken';
import ExcelJS from 'exceljs';
import { crearApp } from '../src/app.js';
import { AuthService } from '../src/modules/auth/auth.service.js';
import { crearRepositorioEnMemoria } from '../src/modules/auth/auth.memory.repository.js';
import { MemoryGuiasRepository } from '../src/modules/guias/guias.memory.repository.js';
import { GuiasService } from '../src/modules/guias/guias.service.js';

const jwtSecret = 'test-secret-with-more-than-thirty-two-characters';
const env = { jwtSecret, jwtExpiresIn: '1h', corsOrigin: '*' };
const servers = [];

async function start(app) {
  const server = app.listen(0, '127.0.0.1');
  servers.push(server);
  await new Promise((resolve) => server.once('listening', resolve));
  return `http://127.0.0.1:${server.address().port}`;
}

after(async () => {
  await Promise.all(servers.map((server) => new Promise((resolve) => server.close(resolve))));
});

function tokenPara(usuario) {
  return jwt.sign(
    { role: usuario.role, termsAccepted: usuario.termsAccepted ?? true, isFirstLogin: false },
    jwtSecret,
    { subject: usuario.id, expiresIn: '1h' },
  );
}

// Crea un archivo Excel en memoria para pruebas
async function crearExcelEnMemoria({ columnas, filas }) {
  const wb = new ExcelJS.Workbook();
  const ws = wb.addWorksheet('Guías');
  if (columnas) {
    ws.addRow(columnas);
  }
  for (const fila of filas) {
    ws.addRow(fila);
  }
  const buffer = await wb.xlsx.writeBuffer();
  return Buffer.from(buffer);
}

// Arma multipart/form-data simple sin dependencias externas
function armarMultipart({ campo, nombreArchivo, buffer }) {
  const boundary = '----WebKitFormBoundary' + Math.random().toString(36).substring(2);
  const encabezado = `--${boundary}\r\nContent-Disposition: form-data; name="${campo}"; filename="${nombreArchivo}"\r\nContent-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet\r\n\r\n`;
  const pie = `\r\n--${boundary}--\r\n`;

  const cuerpo = Buffer.concat([
    Buffer.from(encabezado, 'utf-8'),
    buffer,
    Buffer.from(pie, 'utf-8'),
  ]);

  return { boundary, cuerpo };
}

test('Módulo de Guías: flujo completo (plantilla, validación, errores por fila, activación y consulta)', async () => {
  const userRepo = await crearRepositorioEnMemoria([
    { id: 'admin-1', name: 'Admin', email: 'admin@gamaitaly.cl', password: 'AdminPassword2026!', role: 'ADMINISTRADOR', termsAccepted: true, isFirstLogin: false },
    { id: 'colab-1', name: 'Colaborador', email: 'colab@gamaitaly.cl', password: 'WorkerPassword2026!', role: 'COLABORADOR', termsAccepted: true, isFirstLogin: false },
  ]);
  const authService = new AuthService(userRepo, env);
  const guiasRepo = new MemoryGuiasRepository();
  const guiasService = new GuiasService(guiasRepo);
  const baseUrl = await start(crearApp({ env, authService, guiasService }));

  const adminToken = tokenPara({ id: 'admin-1', role: 'ADMINISTRADOR' });
  const colabToken = tokenPara({ id: 'colab-1', role: 'COLABORADOR' });

  // 1. Control de accesos (Solo Administrador)
  {
    const resSinToken = await fetch(`${baseUrl}/guias/plantilla`);
    assert.equal(resSinToken.status, 401, 'Sin token debe responder 401');

    const resColab = await fetch(`${baseUrl}/guias/plantilla`, {
      headers: { Authorization: `Bearer ${colabToken}` },
    });
    assert.equal(resColab.status, 403, 'Colaborador debe recibir 403');
    const jsonColab = await resColab.json();
    assert.equal(jsonColab.error.code, 'SIN_ROL_ADMIN');
  }

  // 2. GET /guias/plantilla entrega el Excel con las columnas requeridas
  {
    const res = await fetch(`${baseUrl}/guias/plantilla`, {
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    assert.equal(res.status, 200);
    assert.ok(res.headers.get('content-type').includes('spreadsheetml.sheet'));
    assert.ok(res.headers.get('content-disposition').includes('plantilla_guias.xlsx'));

    const arrayBuffer = await res.arrayBuffer();
    const wb = new ExcelJS.Workbook();
    await wb.xlsx.load(Buffer.from(arrayBuffer));
    const ws = wb.worksheets[0];
    const headers = [
      ws.getCell('A1').text.toLowerCase(),
      ws.getCell('B1').text.toLowerCase(),
      ws.getCell('C1').text.toLowerCase(),
      ws.getCell('D1').text.toLowerCase(),
      ws.getCell('E1').text.toLowerCase(),
    ];
    assert.deepEqual(headers, ['id', 'categoría', 'problema', 'pasos', 'autogestionable']);
  }

  // 3. POST /guias/archivo rechaza si no hay archivo
  {
    const res = await fetch(`${baseUrl}/guias/archivo`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    assert.equal(res.status, 400);
    const json = await res.json();
    assert.equal(json.error.code, 'ARCHIVO_REQUERIDO');
  }

  // 4. POST /guias/archivo rechaza archivo si supera 2 MB
  {
    const bufferGrande = Buffer.alloc(2.1 * 1024 * 1024); // 2.1 MB
    const { boundary, cuerpo } = armarMultipart({
      campo: 'archivo',
      nombreArchivo: 'pesado.xlsx',
      buffer: bufferGrande,
    });
    const res = await fetch(`${baseUrl}/guias/archivo`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${adminToken}`,
        'Content-Type': `multipart/form-data; boundary=${boundary}`,
      },
      body: cuerpo,
    });
    assert.equal(res.status, 413);
    const json = await res.json();
    assert.equal(json.error.code, 'ARCHIVO_MUY_GRANDE');
  }

  // 5. POST /guias/archivo rechaza columnas inválidas o faltantes
  {
    const excelInvalido = await crearExcelEnMemoria({
      columnas: ['id', 'categoria', 'descripcion_invalida'],
      filas: [['1', 'electrica', 'algo']],
    });
    const { boundary, cuerpo } = armarMultipart({
      campo: 'archivo',
      nombreArchivo: 'columnas_malas.xlsx',
      buffer: excelInvalido,
    });
    const res = await fetch(`${baseUrl}/guias/archivo`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${adminToken}`,
        'Content-Type': `multipart/form-data; boundary=${boundary}`,
      },
      body: cuerpo,
    });
    assert.equal(res.status, 400);
    const json = await res.json();
    assert.equal(json.error.code, 'COLUMNAS_INVALIDAS');
  }

  // 6. POST /guias/archivo responde con los errores por fila si hay datos inválidos
  {
    const excelConErrores = await crearExcelEnMemoria({
      columnas: ['id', 'categoría', 'problema', 'pasos', 'autogestionable'],
      filas: [
        ['1', 'jardineria_falsa', 'Corte de pasto', 'Cortar el pasto del patio', 'SI'], // Categoría inválida
        ['2', 'electrica', 'Ab', 'Pasos detallados para revisar interruptor', 'SI'], // Problema muy corto (<3)
        ['3', 'banos', 'Llave gotea', 'Paso', 'TAL_VEZ'], // Pasos muy cortos y autogestionable inválido
      ],
    });
    const { boundary, cuerpo } = armarMultipart({
      campo: 'archivo',
      nombreArchivo: 'con_errores.xlsx',
      buffer: excelConErrores,
    });
    const res = await fetch(`${baseUrl}/guias/archivo`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${adminToken}`,
        'Content-Type': `multipart/form-data; boundary=${boundary}`,
      },
      body: cuerpo,
    });
    assert.equal(res.status, 400);
    const json = await res.json();
    assert.equal(json.error.code, 'ERRORES_VALIDACION');
    assert.ok(Array.isArray(json.error.details));
    // Comprobar que detectó los errores en filas 2, 3 y 4
    const filasConError = json.error.details.map((d) => d.fila);
    assert.ok(filasConError.includes(2), 'Fila 2 debe tener error');
    assert.ok(filasConError.includes(3), 'Fila 3 debe tener error');
    assert.ok(filasConError.includes(4), 'Fila 4 debe tener error');
  }

  // 7. POST /guias/archivo acepta archivo válido y quita cualquier HTML
  let versionGenerada = null;
  {
    const excelValido = await crearExcelEnMemoria({
      columnas: ['id', 'categoría', 'problema', 'pasos', 'autogestionable'],
      filas: [
        ['1', 'electrica', '<b>Ampolleta quemada</b>', '<p>1. Apagar interruptor.<script>alert(1)</script><br/>2. Reemplazar ampolleta.</p>', 'SI'],
        ['2', 'aire acondicionado', 'Equipo no enfría', '1. Revisar termostato.\n2. Limpiar filtro frontal.', 'NO'],
      ],
    });
    const { boundary, cuerpo } = armarMultipart({
      campo: 'archivo',
      nombreArchivo: 'guias_correctas.xlsx',
      buffer: excelValido,
    });
    const res = await fetch(`${baseUrl}/guias/archivo`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${adminToken}`,
        'Content-Type': `multipart/form-data; boundary=${boundary}`,
      },
      body: cuerpo,
    });
    assert.equal(res.status, 201);
    const json = await res.json();
    assert.equal(json.success, true);
    assert.equal(json.data.totalGuias, 2);
    versionGenerada = json.data.version;
    assert.ok(versionGenerada);

    // Verificar sanitización HTML en la guía recibida
    const guia1 = json.data.guias[0];
    assert.equal(guia1.problema, 'Ampolleta quemada', 'Debe quitar las etiquetas <b>');
    assert.ok(!guia1.pasos.includes('<script>'), 'Debe quitar <script>');
    assert.ok(!guia1.pasos.includes('<p>'), 'Debe quitar <p>');
    assert.equal(guia1.autogestionable, true);

    const guia2 = json.data.guias[1];
    assert.equal(guia2.categoria, 'AIRE_ACONDICIONADO');
    assert.equal(guia2.autogestionable, false);
  }

  // 8. GET /guias antes de activar devuelve lista vacía
  {
    const res = await fetch(`${baseUrl}/guias`, {
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    assert.equal(res.status, 200);
    const json = await res.json();
    assert.equal(json.data.version, null);
    assert.equal(json.data.total, 0);
  }

  // 9. POST /guias/:version/activar falla si la versión no existe
  {
    const res = await fetch(`${baseUrl}/guias/v999_inexistente/activar`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    assert.equal(res.status, 404);
    const json = await res.json();
    assert.equal(json.error.code, 'VERSION_NO_ENCONTRADA');
  }

  // 10. POST /guias/:version/activar publica la versión nueva
  {
    const res = await fetch(`${baseUrl}/guias/${versionGenerada}/activar`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    assert.equal(res.status, 200);
    const json = await res.json();
    assert.equal(json.success, true);
    assert.equal(json.data.version, versionGenerada);
    assert.equal(json.data.activa, true);
  }

  // 11. GET /guias lista las vigentes de la versión activa
  {
    const res = await fetch(`${baseUrl}/guias`, {
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    assert.equal(res.status, 200);
    const json = await res.json();
    assert.equal(json.success, true);
    assert.equal(json.data.version, versionGenerada);
    assert.equal(json.data.total, 2);
    assert.equal(json.data.guias[0].problema, 'Ampolleta quemada');
  }

  // 12. Subir una nueva versión v2 y activarla: conserva la anterior y actualiza la vigente
  {
    const excelV2 = await crearExcelEnMemoria({
      columnas: ['id', 'categoría', 'problema', 'pasos', 'autogestionable'],
      filas: [
        ['10', 'inmobiliario', 'Silla de escritorio rota', '1. Ubicar silla de repuesto en bodega.', 'SI'],
      ],
    });
    const { boundary, cuerpo } = armarMultipart({
      campo: 'archivo',
      nombreArchivo: 'guias_v2.xlsx',
      buffer: excelV2,
    });
    const resUpload = await fetch(`${baseUrl}/guias/archivo`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${adminToken}`,
        'Content-Type': `multipart/form-data; boundary=${boundary}`,
      },
      body: cuerpo,
    });
    const jsonUpload = await resUpload.json();
    const version2 = jsonUpload.data.version;
    assert.notEqual(version2, versionGenerada);

    // Activar v2
    await fetch(`${baseUrl}/guias/${version2}/activar`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${adminToken}` },
    });

    // Ahora la vigente es v2 con 1 guía
    const resVigentes = await fetch(`${baseUrl}/guias`, {
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    const jsonVigentes = await resVigentes.json();
    assert.equal(jsonVigentes.data.version, version2);
    assert.equal(jsonVigentes.data.total, 1);
    assert.equal(jsonVigentes.data.guias[0].categoria, 'INMOBILIARIO');
  }
});

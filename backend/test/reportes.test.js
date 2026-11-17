import assert from 'node:assert/strict';
import { mkdtemp, readdir, readFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { after, test } from 'node:test';
import jwt from 'jsonwebtoken';
import { crearApp } from '../src/app.js';
import { crearRepositorioEnMemoria } from '../src/modules/auth/auth.memory.repository.js';
import { AuthService } from '../src/modules/auth/auth.service.js';
import { detectarTipoImagen, quitarMetadatos } from '../src/modules/tickets/tickets.fotos.js';
import { MemoryTicketRepository } from '../src/modules/tickets/tickets.memory.repository.js';
import { TicketService } from '../src/modules/tickets/tickets.service.js';

const jwtSecret = 'test-secret-with-more-than-thirty-two-characters';
const env = { jwtSecret, jwtExpiresIn: '1h', corsOrigin: '*' };
const servers = [];
const carpetas = [];

after(async () => {
  await Promise.all(servers.map((server) => new Promise((resolve) => server.close(resolve))));
  await Promise.all(carpetas.map((dir) => rm(dir, { recursive: true, force: true })));
});

async function start(app) {
  const server = app.listen(0);
  servers.push(server);
  await new Promise((resolve) => server.once('listening', resolve));
  return `http://127.0.0.1:${server.address().port}`;
}

const segmento = (marcador, datos) => {
  const largo = Buffer.alloc(2);
  largo.writeUInt16BE(datos.length + 2);
  return Buffer.concat([Buffer.from([0xff, marcador]), largo, datos]);
};

// JPG mínimo con un bloque EXIF que contiene "coordenadas GPS" falsas.
const jpgConExif = Buffer.concat([
  Buffer.from([0xff, 0xd8]),
  segmento(0xe0, Buffer.from('JFIF\0')),
  segmento(0xe1, Buffer.from('Exif\0\0GPS-33.4489,-70.6693')),
  segmento(0xdb, Buffer.alloc(65)),
  Buffer.from([0xff, 0xda, 0x00, 0x02, 0x11, 0x22, 0xff, 0xd9]),
]);

function chunkPng(tipo, datos) {
  const largo = Buffer.alloc(4);
  largo.writeUInt32BE(datos.length);
  return Buffer.concat([largo, Buffer.from(tipo, 'latin1'), datos, Buffer.alloc(4)]);
}

const pngConTexto = Buffer.concat([
  Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
  chunkPng('IHDR', Buffer.alloc(13)),
  chunkPng('tEXt', Buffer.from('Author\0Camila')),
  chunkPng('IEND', Buffer.alloc(0)),
]);

test('las fotos se reconocen por su firma y pierden sus metadatos', () => {
  assert.equal(detectarTipoImagen(jpgConExif).ext, 'jpg');
  assert.equal(detectarTipoImagen(pngConTexto).ext, 'png');
  assert.equal(detectarTipoImagen(Buffer.from('MZ ejecutable disfrazado')), null);

  const jpg = quitarMetadatos(jpgConExif, { ext: 'jpg' });
  assert.ok(!jpg.includes('GPS'));
  assert.ok(jpg.includes('JFIF'));
  assert.ok(!quitarMetadatos(pngConTexto, { ext: 'png' }).includes('Camila'));
  assert.equal(quitarMetadatos(Buffer.from([0xff, 0xd8, 0x00]), { ext: 'jpg' }), null);
});

test('reportar falla: valida, guarda la foto limpia y crea el ticket Recibido (RF-04)', async () => {
  const uploadsDir = await mkdtemp(path.join(tmpdir(), 'tyckops-fotos-'));
  carpetas.push(uploadsDir);
  const users = await crearRepositorioEnMemoria([
    { id: 'w-1', name: 'Ana', email: 'ana@gamaitaly.cl', password: 'Temporal2026!', role: 'COLABORADOR', termsAccepted: true },
    { id: 'a-1', name: 'Admin', email: 'admin@gamaitaly.cl', password: 'Temporal2026!', role: 'ADMINISTRADOR', termsAccepted: true },
  ]);
  const authService = new AuthService(users, env, { log: () => {} });
  const tickets = new MemoryTicketRepository([]);
  const ticketService = new TicketService(tickets, { uploadsDir, auditLogger: { info: () => {} } });
  const baseUrl = await start(crearApp({ env, authService, ticketService }));
  const token = (sub, role = 'COLABORADOR') => `Bearer ${jwt.sign({ role }, jwtSecret, { subject: sub })}`;

  const enviar = ({ campos = {}, foto = jpgConExif, nombre = 'falla.jpg', tipo = 'image/jpeg', sub = 'w-1', role } = {}) => {
    const form = new FormData();
    const datos = { categoria: 'ELECTRICA', ubicacion: 'Piso 2, Sala B', descripcion: 'El enchufe echa chispas al conectar', ...campos };
    for (const [clave, valor] of Object.entries(datos)) form.append(clave, valor);
    if (foto) form.append('foto', new Blob([foto], { type: tipo }), nombre);
    return fetch(`${baseUrl}/api/tickets`, { method: 'POST', headers: { authorization: token(sub, role) }, body: form });
  };
  const codigo = async (respuesta) => (await respuesta.json()).error.code;

  // Rol y datos.
  assert.equal((await enviar({ sub: 'a-1', role: 'ADMINISTRADOR' })).status, 403);
  assert.equal(await codigo(await enviar({ campos: { categoria: 'OTRA' } })), 'DATOS_INVALIDOS');
  assert.equal(await codigo(await enviar({ campos: { descripcion: 'corta' } })), 'DATOS_INVALIDOS');

  // Un archivo que no es imagen, aunque diga ser .jpg, se rechaza.
  const falso = await enviar({ foto: Buffer.from('MZ esto no es una foto'), nombre: 'virus.jpg' });
  assert.equal(falso.status, 415);
  assert.equal(await codigo(falso), 'FOTO_TIPO_INVALIDO');

  // Más de 5 MB se corta.
  const grande = Buffer.concat([jpgConExif, Buffer.alloc(5 * 1024 * 1024)]);
  assert.equal((await enviar({ foto: grande })).status, 413);

  assert.equal((await readdir(uploadsDir)).length, 0, 'nada se guarda si el reporte es inválido');

  // Reporte válido.
  const ok = await enviar({ nombre: '../../etc/passwd.jpg' });
  assert.equal(ok.status, 201);
  const { ticket } = (await ok.json()).data;
  assert.equal(ticket.status, 'RECIBIDO');
  assert.equal(ticket.category, 'Eléctrica');
  assert.equal(ticket.location, 'Piso 2, Sala B');
  assert.equal(ticket.priority, null);

  // La foto queda con un nombre del servidor (no el del cliente) y sin EXIF.
  const archivos = await readdir(uploadsDir);
  assert.equal(archivos.length, 1);
  assert.match(archivos[0], new RegExp(`^ticket-${ticket.id}-[0-9a-f-]{36}\\.jpg$`));
  assert.ok(!(await readFile(path.join(uploadsDir, archivos[0]))).includes('GPS'));

  // La foto es opcional: un reporte sin foto también se crea y no guarda archivos.
  const sinFoto = await enviar({ foto: null, campos: { categoria: 'BANOS', descripcion: 'La llave del lavamanos gotea' } });
  assert.equal(sinFoto.status, 201);
  assert.equal((await sinFoto.json()).data.ticket.category, 'Baños');
  assert.equal((await readdir(uploadsDir)).length, 1);

  // Y ambos aparecen en "mis tickets" de su dueño.
  const mios = await (await fetch(`${baseUrl}/api/tickets/mis-tickets`, { headers: { authorization: token('w-1') } })).json();
  assert.equal(mios.data.resumen.enAtencion, 2);
});

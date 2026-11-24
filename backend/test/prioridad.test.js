// ¿PARA QUÉ SIRVE?
//   Prueba la prioridad inicial (hito MM2): guía -> regla elegida por la IA -> media.
//
// ¿QUÉ HACE?
//   Usa una IA y un módulo de guías "de mentira" (no llama a Groq) para revisar
//   el orden de decisión, que la IA solo pueda elegir un id enviado, la regla de
//   seguridad, el respaldo cuando la IA falla y que la prioridad solo se guarde
//   si el ticket sigue en Recibido.
//
// ¿CÓMO LO CAMBIO?
//   Si cambias src/ia/analizadorPrioridad.js, ajusta o agrega un caso aquí.

import assert from 'node:assert/strict';
import { test } from 'node:test';
import { AnalizadorPrioridad } from '../src/ia/analizadorPrioridad.js';
import { detectarRiesgo } from '../src/ia/reglasPrioridad.js';
import { MemoryTicketRepository } from '../src/modules/tickets/tickets.memory.repository.js';
import { TicketService } from '../src/modules/tickets/tickets.service.js';

const silencioso = { info() {} };

const REGLAS = {
  version: 7,
  reglas: [
    { id: 'ELE-01', categoria: 'ELECTRICA', prioridad: 'ALTA', descripcion: 'Enchufe o tablero con chispas, humo u olor a quemado' },
    { id: 'ELE-02', categoria: 'ELECTRICA', prioridad: 'MEDIA', descripcion: 'Luminaria apagada en un sector' },
    { id: 'BAN-01', categoria: 'BANOS', prioridad: 'ALTA', descripcion: 'Fuga de agua que no se puede cortar' },
  ],
};

// IA de prueba: responde lo que le digamos y guarda lo que recibió.
function iaFalsa(respuesta) {
  const llamadas = [];
  return {
    llamadas,
    async completar(solicitud) {
      llamadas.push(solicitud);
      if (respuesta instanceof Error) throw respuesta;
      return typeof respuesta === 'string' ? respuesta : JSON.stringify(respuesta);
    },
  };
}

const errorGroq = (code) => Object.assign(new Error(code), { code });
const guiaQueCalza = (id = 'G-AMPOLLETA') => ({ async buscar() { return { id }; } });
const sinGuia = { async buscar() { return null; } };

const datos = (descripcion, categoria = 'Eléctrica') => ({ ticketId: '1', categoria, descripcion, ubicacion: 'Piso 2' });

function analizador({ ia = null, guias = null, reglas = REGLAS } = {}) {
  return new AnalizadorPrioridad({ groqClient: ia, buscadorGuias: guias, obtenerReglas: async () => reglas });
}

test('palabras de riesgo: sin importar tildes ni mayúsculas', () => {
  assert.equal(detectarRiesgo(datos('El enchufe sacó CHISPAS')), 'chispas');
  assert.equal(detectarRiesgo(datos('Huele a quemado en la sala')), 'olor a quemado');
  assert.equal(detectarRiesgo(datos('Hay una fuga en el lavamanos')), 'fuga');
  assert.equal(detectarRiesgo(datos('Se inundó el baño')), 'inundacion');
  assert.equal(detectarRiesgo(datos('La silla está gastada')), null);
});

test('1. calza con una guía -> BAJA (origen guia), sin consultar a la IA', async () => {
  const ia = iaFalsa({ reglaId: 'ELE-01' });
  const r = await analizador({ ia, guias: guiaQueCalza() }).analizar(datos('Se quemó la ampolleta'));
  assert.deepEqual(
    [r.prioridad, r.origen, r.nivelIncidencia, r.guiaId, r.reglaId],
    ['BAJA', 'guia', 'menor', 'G-AMPOLLETA', null],
  );
  assert.equal(ia.llamadas.length, 0);
});

test('2. sin guía: la IA elige la regla y el CÓDIGO pone su prioridad', async () => {
  const ia = iaFalsa({ reglaId: 'ele-02' }); // sin importar mayúsculas
  const r = await analizador({ ia, guias: sinGuia }).analizar(datos('No prende la luz del pasillo'));
  assert.deepEqual([r.prioridad, r.origen, r.reglaId, r.versionReglas], ['MEDIA', 'regla', 'ELE-02', 7]);

  // La IA recibe SOLO las reglas de la categoría, y sin la prioridad.
  const enviado = JSON.parse(ia.llamadas[0].messages[1].content);
  assert.deepEqual(enviado.reglas.map((x) => x.id), ['ELE-01', 'ELE-02']);
  assert.equal(JSON.stringify(enviado.reglas).includes('ALTA'), false);
  assert.deepEqual(ia.llamadas[0].responseFormat, { type: 'json_object' });
  assert.equal(JSON.stringify(enviado).includes('ownerId'), false);
});

test('la IA no puede inventar: un id que no se le envió (u otra categoría) es falla_ia -> MEDIA', async () => {
  const inventado = await analizador({ ia: iaFalsa({ reglaId: 'URGENTE-99' }) }).analizar(datos('Luz apagada'));
  assert.deepEqual([inventado.prioridad, inventado.origen, inventado.errorIA], ['MEDIA', 'falla_ia', 'IA_REGLA_DESCONOCIDA']);

  // BAN-01 es ALTA, pero es de Baños: no se le envió para un ticket eléctrico.
  const otraCategoria = await analizador({ ia: iaFalsa({ reglaId: 'BAN-01' }) }).analizar(datos('Luz apagada'));
  assert.deepEqual([otraCategoria.prioridad, otraCategoria.origen], ['MEDIA', 'falla_ia']);

  const conPrioridad = await analizador({ ia: iaFalsa({ prioridad: 'ALTA' }) }).analizar(datos('Luz apagada'));
  assert.deepEqual([conPrioridad.prioridad, conPrioridad.origen, conPrioridad.errorIA], ['MEDIA', 'falla_ia', 'IA_RESPUESTA_INVALIDA']);
});

test('3. ninguna regla calza o no hay reglas de la categoría -> MEDIA (origen defecto)', async () => {
  const ninguna = await analizador({ ia: iaFalsa({ reglaId: null }) }).analizar(datos('Ruido raro en el tablero'));
  assert.deepEqual([ninguna.prioridad, ninguna.origen, ninguna.reglaId], ['MEDIA', 'defecto', null]);

  const ia = iaFalsa({ reglaId: 'X' });
  const sinReglas = await analizador({ ia }).analizar(datos('Silla rota', 'Inmobiliario'));
  assert.deepEqual([sinReglas.prioridad, sinReglas.origen], ['MEDIA', 'defecto']);
  assert.equal(ia.llamadas.length, 0, 'sin reglas no se gasta cuota de Groq');

  const sinArchivo = await analizador({ ia, reglas: { version: null, reglas: [] } }).analizar(datos('Luz apagada'));
  assert.equal(sinArchivo.origen, 'defecto');
});

test('3. la IA falla, tarda o no está configurada -> MEDIA (origen falla_ia)', async () => {
  for (const [ia, codigo] of [
    [iaFalsa(errorGroq('GROQ_TIMEOUT')), 'GROQ_TIMEOUT'],
    [iaFalsa(errorGroq('GROQ_RATE_LIMITED')), 'GROQ_RATE_LIMITED'],
    [iaFalsa('esto no es json'), 'IA_RESPUESTA_INVALIDA'],
    [null, 'IA_NO_CONFIGURADA'],
  ]) {
    const r = await analizador({ ia }).analizar(datos('Luz apagada'));
    assert.deepEqual([r.prioridad, r.origen, r.errorIA], ['MEDIA', 'falla_ia', codigo]);
  }

  const envuelto = await analizador({ ia: iaFalsa('```json\n{"reglaId": "ELE-01"}\n```') }).analizar(datos('Luz apagada'));
  assert.equal(envuelto.prioridad, 'ALTA');
});

test('seguridad: con palabras de riesgo nunca es baja ni se busca guía', async () => {
  let consultada = false;
  const guias = { async buscar() { consultada = true; return { id: 'G-1' }; } };

  const conRegla = await analizador({ ia: iaFalsa({ reglaId: 'ELE-01' }), guias }).analizar(datos('El enchufe saca chispas'));
  assert.deepEqual([conRegla.prioridad, conRegla.origen, conRegla.riesgo, conRegla.nivelIncidencia], ['ALTA', 'regla', 'chispas', 'falla_real']);

  const sinRegla = await analizador({ ia: iaFalsa({ reglaId: null }), guias }).analizar(datos('Sale humo del enchufe'));
  assert.deepEqual([sinRegla.prioridad, sinRegla.origen], ['MEDIA', 'defecto']);
  assert.equal(consultada, false);
});

test('si el módulo de guías o de reglas falla, igual hay prioridad', async () => {
  const guiasRotas = { async buscar() { throw new Error('caído'); } };
  const r = await analizador({ ia: iaFalsa({ reglaId: 'ELE-02' }), guias: guiasRotas }).analizar(datos('Luz apagada'));
  assert.equal(r.origen, 'regla');

  const reglasRotas = new AnalizadorPrioridad({ obtenerReglas: async () => { throw new Error('BD caída'); } });
  const r2 = await reglasRotas.analizar(datos('Luz apagada'));
  assert.deepEqual([r2.prioridad, r2.origen], ['MEDIA', 'defecto']);
});

test('el servicio guarda prioridad, origen y regla solo si sigue en Recibido y sin prioridad', async () => {
  const repo = new MemoryTicketRepository([
    { id: 'c-1', ownerId: 'w-1', code: 'REP-0001', status: 'CANCELADO', priority: null, title: 'x', location: 'P1', createdAt: new Date() },
    { id: 'p-1', ownerId: 'w-1', code: 'REP-0002', status: 'RECIBIDO', priority: 'ALTA', title: 'x', location: 'P1', createdAt: new Date() },
  ]);
  const eventos = [];
  const service = new TicketService(repo, {
    analizadorIA: analizador({ ia: iaFalsa({ reglaId: 'ELE-01' }) }),
    auditLogger: { info: (l) => eventos.push(JSON.parse(l)) },
  });

  const nuevo = await repo.create({ ownerId: 'w-1', category: 'ELECTRICA', location: 'Piso 2', description: 'El tablero huele raro' });
  assert.equal((await service.enrutarTicket({ ...nuevo, description: 'El tablero huele raro' })).prioridadGuardada, true);
  const guardado = await repo.findByIdForOwner(nuevo.id, 'w-1');
  assert.deepEqual(
    [guardado.priority, guardado.initialPriority, guardado.priorityOrigin, guardado.ruleId],
    ['ALTA', 'ALTA', 'regla', 'ELE-01'],
  );
  const evento = eventos.find((e) => e.action === 'prioridad_asignada');
  assert.deepEqual([evento.prioridad, evento.origen, evento.reglaId], ['ALTA', 'regla', 'ELE-01']);
  assert.equal(JSON.stringify(evento).includes('tablero'), false, 'la descripción no va al log');

  // Cancelado mientras la IA analizaba, o con prioridad puesta: no se toca.
  assert.equal(await repo.guardarPrioridadInicial('c-1', { prioridad: 'ALTA', origen: 'regla' }), false);
  const r2 = await service.enrutarTicket({ ...(await repo.findByIdForOwner('p-1', 'w-1')), description: 'x' });
  assert.equal(r2.prioridadGuardada, false);
  assert.equal((await repo.findByIdForOwner('p-1', 'w-1')).priorityOrigin, undefined);
});

test('crearReporte responde sin esperar a la IA y el ticket nunca queda sin prioridad', async () => {
  const repo = new MemoryTicketRepository([]);
  // Sin IA ni guías: media por defecto.
  const service = new TicketService(repo, { analizadorIA: new AnalizadorPrioridad(), auditLogger: silencioso });
  const creado = await service.crearReporte('w-1', { categoria: 'BANOS', ubicacion: 'Baño piso 1', descripcion: 'El estanque no carga agua' });
  assert.equal(creado.priority, null, 'la respuesta sale antes del análisis');

  await new Promise((resolve) => setImmediate(resolve));
  const guardado = await repo.findByIdForOwner(creado.id, 'w-1');
  assert.deepEqual([guardado.priority, guardado.priorityOrigin], ['MEDIA', 'defecto']);
});

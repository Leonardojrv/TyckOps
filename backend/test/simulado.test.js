// ¿PARA QUÉ SIRVE?
//   Prueba la respuesta SIMULADA que reemplaza a la IA cuando no hay
//   GROQ_API_KEY (T10): duplicados y guía de autoayuda.
//
// ¿QUÉ HACE?
//   Usa los casos reales que probó el equipo ("Mi computador no prende" en
//   "Piso 1, Escritorio 4") y revisa de punta a punta que el ticket quede en
//   prioridad Baja con su guía, y que el segundo reporte se agrupe con el primero.
//
// ¿CÓMO LO CAMBIO?
//   Si cambias el umbral de parecido o los problemas simples, ajusta estos
//   casos y corre `pnpm test`.

import assert from 'node:assert/strict';
import { test } from 'node:test';
import { AnalizadorIntegrado } from '../src/ia/analizadorIntegrado.js';
import { AnalizadorPrioridad } from '../src/ia/analizadorPrioridad.js';
import { AnalizadorSimulado, buscadorGuiasSimulado, mismaUbicacion, similitud, UMBRAL_SIMILITUD } from '../src/ia/analizadorSimulado.js';
import { buscarProblemaSimple, elegirGuia } from '../src/modules/tickets/tickets.guia.js';
import { MemoryTicketRepository } from '../src/modules/tickets/tickets.memory.repository.js';
import { TicketService } from '../src/modules/tickets/tickets.service.js';

test('similitud: "no prende" y "no quiere prender" son la misma falla', () => {
  assert.ok(similitud('Mi computador no prende', 'Mi computador no quiere prender.') >= UMBRAL_SIMILITUD);
  assert.ok(similitud('Mi computador no prende', 'La silla está rota') < UMBRAL_SIMILITUD);
  assert.ok(mismaUbicacion('Piso 1, Escritorio 4', 'piso 1 escritorio 4'));
  assert.ok(!mismaUbicacion('Piso 1, Escritorio 4', 'Piso 1, Escritorio 5'));
});

test('falla simple: el computador que no prende tiene su propia guía', () => {
  assert.equal(buscarProblemaSimple('Mi computador no prende')?.id, 'computador-no-enciende');
  assert.equal(buscarProblemaSimple('Mi computador no quiere prender.')?.id, 'computador-no-enciende');
  assert.equal(buscarProblemaSimple('No hay jabón en el dispensador')?.id, 'dispensador-vacio');
  assert.equal(buscarProblemaSimple('Se cayó el techo del pasillo'), null);
  const guia = elegirGuia({ category: 'Inmobiliario', description: 'Mi computador no prende' });
  assert.equal(guia.id, 'computador-no-enciende', 'la guía es del problema, no de la categoría');
  assert.match(guia.pasos[0].titulo, /cable de poder/);
});

async function crearConIA() {
  const repo = new MemoryTicketRepository([]);
  const analizador = new AnalizadorIntegrado({
    analizadorDuplicadosGuias: new AnalizadorSimulado({ ticketRepository: repo }),
    analizadorPrioridad: new AnalizadorPrioridad({
      groqClient: null,
      obtenerReglas: async () => ({ version: null, reglas: [] }),
      buscadorGuias: buscadorGuiasSimulado,
    }),
  });
  const service = new TicketService(repo, { analizadorIA: analizador, auditLogger: { info: () => {} } });
  // crearReporte lanza la IA sin esperarla; aquí la esperamos para revisar el resultado.
  const reportar = async (userId, descripcion, ubicacion = 'Piso 1, Escritorio 4', categoria = 'INMOBILIARIO') => {
    const t = await service.crearReporte(userId, { categoria, ubicacion, descripcion });
    const guardado = await repo.findByIdForOwner(t.id, userId);
    await service.enrutarTicket({ ...guardado, description: descripcion });
    return t.id;
  };
  return { service, reportar };
}

test('de punta a punta: guía en Baja y el segundo reporte queda agrupado', async () => {
  const { service, reportar } = await crearConIA();

  const primero = await reportar('w-1', 'Mi computador no prende');
  const d1 = await service.detalle('w-1', primero);
  assert.equal(d1.priority, 'BAJA');
  assert.equal(d1.selfHelp, true, 'muestra la Asistencia IA de Diagnóstico');
  assert.equal(d1.duplicateOf, null);
  assert.equal((await service.guia('w-1', primero)).id, 'computador-no-enciende');

  // Mismo perfil, misma falla y lugar: se agrupa y el mensaje sabe que es tuyo.
  const segundo = await reportar('w-1', 'Mi computador no quiere prender.');
  const d2 = await service.detalle('w-1', segundo);
  assert.equal(d2.duplicateOf.id, primero);
  assert.equal(d2.duplicateOf.mine, true);

  // Otra persona reporta lo mismo: también se agrupa con el PRIMERO, no es "tuyo".
  const tercero = await reportar('w-2', 'El computador no enciende');
  const d3 = await service.detalle('w-2', tercero);
  assert.equal(d3.duplicateOf.id, primero);
  assert.equal(d3.duplicateOf.mine, false);

  // Otro lugar u otra falla: no es duplicado.
  const otroLugar = await reportar('w-1', 'Mi computador no prende', 'Piso 3, Escritorio 9');
  assert.equal((await service.detalle('w-1', otroLugar)).duplicateOf, null);
});

test('con palabras de riesgo no hay guía: va directo a un técnico', async () => {
  const { service, reportar } = await crearConIA();
  const id = await reportar('w-1', 'Mi computador no prende y sale humo', 'Piso 2, Escritorio 1');
  const d = await service.detalle('w-1', id);
  assert.notEqual(d.priority, 'BAJA');
  assert.equal(d.selfHelp, false);
});

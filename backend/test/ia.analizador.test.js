import assert from 'node:assert/strict';
import { test } from 'node:test';
import { detectarRiesgo, PALABRAS_RIESGO } from '../src/ia/palabrasRiesgo.js';
import { filtrarCandidatosDuplicados, evaluarDuplicadoConIA } from '../src/ia/duplicados.js';
import { evaluarGuiaConIA } from '../src/ia/guiasMatcher.js';
import { AnalizadorTicket } from '../src/ia/analizadorTicket.js';
import { ClienteGroq } from '../src/ia/clienteGroq.js';

// Cliente Groq simulado para pruebas rápidas y deterministas
function clienteGroqMock(generadorRespuesta) {
  return new ClienteGroq({
    apiKey: 'mock-key',
    fetchImpl: async (_url, options) => {
      const body = JSON.parse(options.body);
      const content = generadorRespuesta(body);
      return {
        ok: true,
        status: 200,
        headers: new Headers(),
        json: async () => ({ choices: [{ message: { content } }] }),
      };
    },
  });
}

test('Filtro de seguridad: detecta palabras de riesgo obligatorias y desvía', () => {
  const palabrasExigidas = ['chispas', 'humo', 'olor a quemado', 'fuga', 'inundacion'];

  for (const palabra of palabrasExigidas) {
    const res = detectarRiesgo(`Atención, tenemos ${palabra} en el sector`);
    assert.equal(res.tieneRiesgo, true, `Debe detectar '${palabra}'`);
  }

  // Sin riesgo
  assert.equal(detectarRiesgo('Ampolleta no enciende').tieneRiesgo, false);
  assert.equal(detectarRiesgo('Dispensador de jabón vacío').tieneRiesgo, false);
  assert.equal(detectarRiesgo('El cajón se traba al cerrar').tieneRiesgo, false);
});

test('Guías: desvía inmediatamente si hay palabra de riesgo SIN llamar a Groq', async () => {
  let groqLlamado = false;
  const groq = clienteGroqMock(() => {
    groqLlamado = true;
    return '{}';
  });

  const res = await evaluarGuiaConIA({
    groqClient: groq,
    ticket: {
      ticketId: 't-1',
      categoria: 'ELECTRICA',
      descripcion: 'El tomacorriente saca chispas al conectar el cargador',
    },
    guiasVigentes: [
      { id: '1', categoria: 'ELECTRICA', problema: 'Tomacorriente suelto', pasos: 'Apretar tornillo', autogestionable: true },
    ],
  });

  assert.equal(groqLlamado, false, 'No debe llamar a Groq cuando hay riesgo');
  assert.equal(res.aplicable, false);
  assert.equal(res.desviadoPorRiesgo, true);
  assert.equal(res.palabraRiesgo, 'chispas');
  assert.equal(res.guia, null);
});

test('Guías: envía solo títulos a Groq, es conservadora y los pasos se leen de la BD', async () => {
  let payloadEnviado;
  const groq = clienteGroqMock((body) => {
    payloadEnviado = body;
    // La IA responde que coincide con la guía '10'
    return JSON.stringify({
      guiaId: '10',
      confianza: 0.95,
      motivo: 'Coincide con cambio de ampolleta',
    });
  });

  const guiasEnBD = [
    {
      id: '10',
      categoria: 'ELECTRICA',
      problema: 'Ampolleta quemada en puesto de trabajo',
      pasos: 'PASOS_DESDE_LA_BD: 1. Desconectar. 2. Cambiar por repuesto.',
      autogestionable: true,
    },
    {
      id: '20',
      categoria: 'ELECTRICA',
      problema: 'Interruptor trabado',
      pasos: 'PASOS_DESDE_LA_BD: Limpiar contornos.',
      autogestionable: true,
    },
    {
      id: '30',
      categoria: 'ELECTRICA',
      problema: 'Corte de disyuntor general',
      pasos: 'No tocar, llamar a cuadrilla.',
      autogestionable: false, // NO autogestionable: no debe enviarse
    },
  ];

  const res = await evaluarGuiaConIA({
    groqClient: groq,
    ticket: {
      ticketId: 't-2',
      categoria: 'ELECTRICA',
      descripcion: 'La luz de mi escritorio no prende',
    },
    guiasVigentes: guiasEnBD,
  });

  // Verificar que al prompt de Groq NUNCA se enviaron los pasos
  const promptUser = payloadEnviado.messages.find((m) => m.role === 'user').content;
  assert.ok(!promptUser.includes('PASOS_DESDE_LA_BD'), 'Los pasos nunca deben enviarse a la IA');
  assert.ok(promptUser.includes('Ampolleta quemada'), 'Debe enviar el título');
  assert.ok(!promptUser.includes('Corte de disyuntor general'), 'No debe incluir guías no autogestionables');

  // Verificar que la guía devuelta tiene los pasos leídos de la BD
  assert.equal(res.aplicable, true);
  assert.equal(res.guia.id, '10');
  assert.equal(res.guia.pasos, 'PASOS_DESDE_LA_BD: 1. Desconectar. 2. Cambiar por repuesto.');
});

test('Guías: ante la duda la IA es conservadora y devuelve ninguna', async () => {
  const groq = clienteGroqMock(() => JSON.stringify({
    guiaId: null,
    confianza: 0.4,
    motivo: 'El problema parece requerir desmontaje complejo, se sugiere técnico.',
  }));

  const res = await evaluarGuiaConIA({
    groqClient: groq,
    ticket: {
      ticketId: 't-3',
      categoria: 'ELECTRICA',
      descripcion: 'La lámpara fluorescente cuelga de un cable en el techo',
    },
    guiasVigentes: [
      { id: '10', categoria: 'ELECTRICA', problema: 'Ampolleta quemada', pasos: '1. Cambiar', autogestionable: true },
    ],
  });

  assert.equal(res.aplicable, false);
  assert.equal(res.guia, null);
  assert.equal(res.desviadoPorRiesgo, false);
});

test('Duplicados: si no hay candidatos activos cercanos no llama a Groq', async () => {
  let groqLlamado = false;
  const groq = clienteGroqMock(() => {
    groqLlamado = true;
    return '{}';
  });

  const res = await evaluarDuplicadoConIA({
    groqClient: groq,
    ticket: { ticketId: 't-10', categoria: 'ELECTRICA', ubicacion: 'Piso 5', descripcion: 'Enchufe suelto' },
    candidatos: [],
  });

  assert.equal(groqLlamado, false);
  assert.equal(res.esDuplicado, false);
  assert.equal(res.ticketOriginalId, null);
});

test('Duplicados: evalúa candidatos y detecta coincidencia con Groq', async () => {
  const groq = clienteGroqMock(() => JSON.stringify({
    esDuplicado: true,
    ticketOriginalId: 'cand-1',
    confianza: 0.92,
    motivo: 'Ambos reportan el mismo enchufe averiado en Recepción',
  }));

  const res = await evaluarDuplicadoConIA({
    groqClient: groq,
    ticket: { ticketId: 't-nuevo', categoria: 'ELECTRICA', ubicacion: 'Recepción', descripcion: 'Enchufe sin energía' },
    candidatos: [
      { id: 'cand-1', categoria: 'ELECTRICA', location: 'Recepción', description: 'Toma corriente malo en recepción', status: 'RECIBIDO' },
    ],
  });

  assert.equal(res.esDuplicado, true);
  assert.equal(res.ticketOriginalId, 'cand-1');
  assert.equal(res.confianza, 0.92);
});

test('AnalizadorTicket: orquesta veredicto de duplicado y asignación de guía en un solo paso', async () => {
  const groq = clienteGroqMock((body) => {
    const userMsg = body.messages.find((m) => m.role === 'user').content;
    if (userMsg.includes('Tickets candidatos existentes')) {
      return JSON.stringify({ esDuplicado: false, ticketOriginalId: null, confianza: 0.9, motivo: 'Ubicación distinta' });
    }
    return JSON.stringify({ guiaId: 'g-jabon', confianza: 0.95, motivo: 'Dispensador vacío' });
  });

  const ticketRepo = {
    findActiveCandidates: async () => [
      { id: 'cand-9', category: 'Baños', location: 'Piso 2', description: 'Llave gotea', status: 'EN_REVISION' },
    ],
  };

  const guiasRepo = {
    obtenerVersionActiva: async () => ({
      guias: [
        { id: 'g-jabon', categoria: 'BANOS', problema: 'Dispensador de jabón vacío', pasos: '1. Rellenar con sachet de bodega.', autogestionable: true },
      ],
    }),
  };

  const analizador = new AnalizadorTicket({
    groqClient: groq,
    ticketRepository: ticketRepo,
    guiasRepository: guiasRepo,
  });

  const resultado = await analizador.analizar({
    ticketId: 't-nuevo-88',
    categoria: 'BANOS',
    descripcion: 'No queda nada de jabón en el baño de visitas',
    ubicacion: 'Piso 1',
  });

  assert.equal(resultado.ticketId, 't-nuevo-88');
  assert.equal(resultado.duplicado.esDuplicado, false);
  assert.equal(resultado.guia.aplicable, true);
  assert.equal(resultado.guia.guia.id, 'g-jabon');
  assert.equal(resultado.guia.guia.pasos, '1. Rellenar con sachet de bodega.');
});

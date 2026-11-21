import fs from 'node:fs';
import { BANCO_CASOS_DUPLICADOS } from '../src/ia/bancoCasos.js';
import { ClienteGroq } from '../src/ia/clienteGroq.js';
import { evaluarDuplicadoConIA } from '../src/ia/duplicados.js';

const repeticiones = Math.max(1, Number(process.argv[2] ?? 1));
const metaKpi = 0.8;
const modelo = process.env.GROQ_MODEL ?? 'openai/gpt-oss-20b';
const razonamiento = process.env.GROQ_REASONING_EFFORT ?? 'low';

if (!process.env.GROQ_API_KEY) {
  console.error('Falta GROQ_API_KEY. Configúrala en backend/.env.');
  process.exit(1);
}

const groq = new ClienteGroq({
  apiKey: process.env.GROQ_API_KEY,
  model: modelo,
  reasoningEffort: razonamiento,
  timeoutMs: Number(process.env.GROQ_TIMEOUT_MS ?? 20000),
});

const dormir = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
let aciertos = 0;
let total = 0;
let ambiguos = 0;
let errores = 0;
let falsosPositivos = 0;
let falsosNegativos = 0;
let ticketEquivocado = 0;
const porGrupo = {};
const detalle = [];

console.log(`Modelo: ${modelo} | razonamiento: ${razonamiento} | repeticiones: ${repeticiones}`);

for (const caso of BANCO_CASOS_DUPLICADOS) {
  if (caso.esperado === null) {
    ambiguos += 1;
    detalle.push({ nombre: caso.nombre, grupo: caso.grupo, ambiguo: true });
    continue;
  }

  const resultados = [];
  porGrupo[caso.grupo] ??= { aciertos: 0, total: 0 };

  for (let repeticion = 0; repeticion < repeticiones; repeticion += 1) {
    try {
      const inicio = Date.now();
      const resultado = await evaluarDuplicadoConIA({
        groqClient: groq,
        ticket: caso.ticketNuevo,
        candidatos: caso.candidatos,
      });
      const acerto = resultado.esDuplicado === caso.esperado.esDuplicado
        && resultado.ticketOriginalId === caso.esperado.ticketOriginalId;

      if (resultado.instruccionesEnTexto && caso.esperado.manipulacionEnTexto !== true) {
        // Una detección extra no cambia el KPI, pero queda visible en el detalle.
      }

      total += 1;
      porGrupo[caso.grupo].total += 1;
      if (acerto) {
        aciertos += 1;
        porGrupo[caso.grupo].aciertos += 1;
      } else if (resultado.esDuplicado && !caso.esperado.esDuplicado) {
        falsosPositivos += 1;
      } else if (!resultado.esDuplicado && caso.esperado.esDuplicado) {
        falsosNegativos += 1;
      } else if (resultado.esDuplicado && resultado.ticketOriginalId !== caso.esperado.ticketOriginalId) {
        ticketEquivocado += 1;
      }

      resultados.push({
        acerto,
        esDuplicado: resultado.esDuplicado,
        ticketOriginalId: resultado.ticketOriginalId,
        instruccionesEnTexto: resultado.instruccionesEnTexto,
        motivo: resultado.motivo,
        ms: Date.now() - inicio,
      });
      await dormir(250);
    } catch (error) {
      errores += 1;
      resultados.push({ acerto: false, error: error.message });
    }
  }

  const aciertosCaso = resultados.filter((resultado) => resultado.acerto).length;
  console.log(`${aciertosCaso === repeticiones ? '✅' : aciertosCaso === 0 ? '❌' : '⚠️'} ${caso.id} ${caso.nombre}`);
  detalle.push({
    id: caso.id,
    nombre: caso.nombre,
    grupo: caso.grupo,
    autor: caso.autor,
    esperado: caso.esperado,
    nuevo: caso.ticketNuevo,
    repeticiones: resultados,
  });
}

const porcentaje = total > 0 ? aciertos / total : 0;
const cumple = porcentaje >= metaKpi;
const resumen = {
  aciertos,
  total,
  porcentaje,
  cumple,
  falsosPositivos,
  falsosNegativos,
  ticketEquivocado,
  errores,
  ambiguos,
  porGrupo,
};

console.log('----------------------------------------');
console.log(`Aciertos: ${aciertos}/${total} (${(porcentaje * 100).toFixed(1)} %)`);
console.log(`KPI-7 (meta >= ${metaKpi * 100} %): ${cumple ? 'CUMPLE ✅' : 'NO CUMPLE ❌'}`);
console.log(`Falsos positivos: ${falsosPositivos}`);
console.log(`Falsos negativos: ${falsosNegativos}`);
console.log(`Ticket original equivocado: ${ticketEquivocado}`);
console.log(`Errores de API: ${errores}`);
console.log(`Informativos ambiguos: ${ambiguos}`);

fs.mkdirSync('resultados', { recursive: true });
const marca = new Date().toISOString().replace(/[:.]/g, '-');
const archivo = `resultados/kpi7-${marca}.json`;
fs.writeFileSync(archivo, JSON.stringify({
  fecha: new Date().toISOString(),
  modelo,
  razonamiento,
  repeticiones,
  metaKpi,
  resumen,
  detalle,
}, null, 2));
console.log(`Resultado guardado en ${archivo}`);

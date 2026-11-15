// Reporter de Jest que guarda el resultado de cada prueba en un JSON
// (lo usa el reporte PDF). Va en .cjs porque Jest carga los reporters con require().
const fs = require('node:fs');
const path = require('node:path');

class ReporteJson {
  constructor(_globalConfig, opciones = {}) {
    this.salida = opciones.salida ?? 'jest-resultados.json';
  }

  onRunComplete(_contexts, resultados) {
    const suites = resultados.testResults.map((suite) => ({
      archivo: path.relative(process.cwd(), suite.testFilePath).replace(/\\/g, '/'),
      duracionMs: suite.perfStats.end - suite.perfStats.start,
      pruebas: suite.testResults.map((t) => ({
        grupo: t.ancestorTitles.join(' › '),
        nombre: t.title,
        estado: t.status,
        duracionMs: t.duration ?? 0,
        errores: t.failureMessages.map((m) => m.split('\n').slice(0, 6).join('\n')),
      })),
    }));
    const resumen = {
      fecha: new Date().toISOString(),
      total: resultados.numTotalTests,
      aprobadas: resultados.numPassedTests,
      fallidas: resultados.numFailedTests,
      omitidas: resultados.numPendingTests,
      suites,
    };
    fs.mkdirSync(path.dirname(this.salida), { recursive: true });
    fs.writeFileSync(this.salida, JSON.stringify(resumen, null, 2));
  }
}

module.exports = ReporteJson;

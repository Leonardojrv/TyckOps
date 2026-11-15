// Pruebas de integración (Jest + Supertest) contra PostgreSQL real.
// Ejecutar con: pnpm test:integracion
// Las pruebas unitarias existentes (test/*.test.js) siguen usando node --test.
export default {
  testEnvironment: 'node',
  transform: {},
  testMatch: ['<rootDir>/integracion/**/*.spec.js'],
  globalSetup: '<rootDir>/integracion/jest.globalSetup.js',
  testTimeout: 60000,
  maxWorkers: 1, // todas las suites comparten BDTyckOps_pruebas: una a la vez
  verbose: true,
  reporters: [
    'default',
    ['<rootDir>/integracion/helpers/reporteJson.cjs', { salida: 'integracion/resultados/jest-resultados.json' }],
  ],
};

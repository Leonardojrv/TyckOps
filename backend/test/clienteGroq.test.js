import assert from 'node:assert/strict';
import { test } from 'node:test';
import { ClienteGroq, GroqApiError } from '../src/ia/clienteGroq.js';

function respuesta(status, body, headers = {}) {
  return {
    ok: status >= 200 && status < 300,
    status,
    headers: new Headers(headers),
    json: async () => body,
  };
}

test('envía una solicitud Chat Completions y devuelve el contenido', async () => {
  let llamada;
  const client = new ClienteGroq({
    apiKey: 'test-key',
    model: 'openai/gpt-oss-20b',
    fetchImpl: async (url, options) => {
      llamada = { url, options };
      return respuesta(200, { choices: [{ message: { content: 'respuesta de prueba' } }] });
    },
  });

  const content = await client.completar({
    messages: [{ role: 'user', content: 'hola' }],
    temperature: 0,
    maxTokens: 50,
    responseFormat: { type: 'json_object' },
  });

  assert.equal(content, 'respuesta de prueba');
  assert.equal(llamada.url, 'https://api.groq.com/openai/v1/chat/completions');
  assert.equal(llamada.options.headers.authorization, 'Bearer test-key');
  assert.deepEqual(JSON.parse(llamada.options.body), {
    model: 'openai/gpt-oss-20b',
    messages: [{ role: 'user', content: 'hola' }],
    reasoning_effort: 'low',
    temperature: 0,
    max_tokens: 50,
    response_format: { type: 'json_object' },
  });
});

test('no envía reasoning_effort a modelos que no son GPT-OSS', async () => {
  let requestBody;
  const client = new ClienteGroq({
    apiKey: 'test-key',
    model: 'llama-3.3-70b-versatile',
    fetchImpl: async (_url, options) => {
      requestBody = JSON.parse(options.body);
      return respuesta(200, { choices: [{ message: { content: 'respuesta de prueba' } }] });
    },
  });

  await client.completar({ messages: [{ role: 'user', content: 'hola' }] });
  assert.equal('reasoning_effort' in requestBody, false);
});

test('mapea HTTP 429 y expone Retry-After sin reintentar automáticamente', async () => {
  let llamadas = 0;
  const client = new ClienteGroq({
    apiKey: 'test-key',
    fetchImpl: async () => {
      llamadas += 1;
      return respuesta(429, {}, { 'retry-after': '3' });
    },
  });

  await assert.rejects(
    client.completar({ messages: [{ role: 'user', content: 'hola' }] }),
    (error) => error instanceof GroqApiError
      && error.code === 'GROQ_RATE_LIMITED'
      && error.status === 429
      && error.retryAfterMs === 3000,
  );
  assert.equal(llamadas, 1);
});

test('aborta solicitudes que exceden el tiempo máximo', async () => {
  const client = new ClienteGroq({
    apiKey: 'test-key',
    timeoutMs: 5,
    fetchImpl: (_url, { signal }) => new Promise((_resolve, reject) => {
      signal.addEventListener('abort', () => {
        const error = new Error('aborted');
        error.name = 'AbortError';
        reject(error);
      }, { once: true });
    }),
  });

  await assert.rejects(
    client.completar({ messages: [{ role: 'user', content: 'hola' }] }),
    (error) => error.code === 'GROQ_TIMEOUT',
  );
});

test('no intenta conectar si no hay clave configurada', async () => {
  let llamadas = 0;
  const client = new ClienteGroq({ fetchImpl: async () => { llamadas += 1; } });

  await assert.rejects(
    client.completar({ messages: [{ role: 'user', content: 'hola' }] }),
    (error) => error.code === 'GROQ_CONFIG_MISSING' && error.status === 503,
  );
  assert.equal(llamadas, 0);
});
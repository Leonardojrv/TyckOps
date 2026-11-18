const GROQ_CHAT_COMPLETIONS_URL = 'https://api.groq.com/openai/v1/chat/completions';

export class GroqApiError extends Error {
  constructor(code, message, { status = null, retryAfterMs = null, cause } = {}) {
    super(message, { cause });
    this.name = 'GroqApiError';
    this.code = code;
    this.status = status;
    this.retryAfterMs = retryAfterMs;
  }
}

function parseRetryAfter(value) {
  if (!value) return null;
  const seconds = Number(value);
  if (Number.isFinite(seconds)) return Math.max(0, seconds * 1000);
  const date = Date.parse(value);
  return Number.isNaN(date) ? null : Math.max(0, date - Date.now());
}

export class ClienteGroq {
  constructor({
    apiKey,
    model = 'openai/gpt-oss-20b',
    reasoningEffort = 'low',
    timeoutMs = 20000,
    fetchImpl = globalThis.fetch,
  } = {}) {
    this.apiKey = apiKey?.trim() || null;
    this.model = model;
    this.reasoningEffort = reasoningEffort;
    this.timeoutMs = timeoutMs;
    this.fetchImpl = fetchImpl;
  }

  async completar({
    messages,
    model = this.model,
    reasoningEffort = this.reasoningEffort,
    temperature = 0,
    maxTokens,
    responseFormat,
  } = {}) {
    if (!this.apiKey) {
      throw new GroqApiError('GROQ_CONFIG_MISSING', 'Configura GROQ_API_KEY en backend/.env.', { status: 503 });
    }
    if (!Array.isArray(messages) || messages.length === 0) {
      throw new GroqApiError('GROQ_INVALID_REQUEST', 'Se requiere al menos un mensaje.', { status: 400 });
    }
    if (typeof this.fetchImpl !== 'function') {
      throw new GroqApiError('GROQ_FETCH_UNAVAILABLE', 'Este entorno no tiene fetch disponible. Usa Node.js 20 o superior.');
    }

    const body = { model, messages, temperature };
    if (model.startsWith('openai/gpt-oss-')) body.reasoning_effort = reasoningEffort;
    if (maxTokens !== undefined) body.max_tokens = maxTokens;
    if (responseFormat !== undefined) body.response_format = responseFormat;

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), this.timeoutMs);

    try {
      const response = await this.fetchImpl(GROQ_CHAT_COMPLETIONS_URL, {
        method: 'POST',
        headers: {
          authorization: `Bearer ${this.apiKey}`,
          'content-type': 'application/json',
        },
        body: JSON.stringify(body),
        signal: controller.signal,
      });

      if (response.status === 429) {
        throw new GroqApiError(
          'GROQ_RATE_LIMITED',
          'Groq alcanzó el límite de solicitudes. Intenta nuevamente más tarde.',
          { status: 429, retryAfterMs: parseRetryAfter(response.headers?.get('retry-after')) },
        );
      }
      if (response.status === 401 || response.status === 403) {
        throw new GroqApiError('GROQ_AUTH_FAILED', 'Groq rechazó la clave de API configurada.', { status: response.status });
      }
      if (!response.ok) {
        throw new GroqApiError('GROQ_UPSTREAM_ERROR', 'Groq no pudo completar la solicitud.', { status: response.status });
      }

      let payload;
      try {
        payload = await response.json();
      } catch (cause) {
        throw new GroqApiError('GROQ_INVALID_RESPONSE', 'Groq devolvió una respuesta JSON inválida.', { cause });
      }

      const content = payload?.choices?.[0]?.message?.content;
      if (typeof content !== 'string') {
        throw new GroqApiError('GROQ_INVALID_RESPONSE', 'La respuesta de Groq no contiene texto.', { status: response.status });
      }
      return content;
    } catch (error) {
      if (error instanceof GroqApiError) throw error;
      if (controller.signal.aborted || error?.name === 'AbortError') {
        throw new GroqApiError('GROQ_TIMEOUT', 'Groq tardó demasiado en responder.', { cause: error });
      }
      throw new GroqApiError('GROQ_NETWORK_ERROR', 'No se pudo conectar con Groq.', { cause: error });
    } finally {
      clearTimeout(timeout);
    }
  }
}
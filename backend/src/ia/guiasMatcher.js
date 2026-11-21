// Matching de guías de autoayuda con filtro de palabras de riesgo previo
// y consulta conservadora a Groq (enviando solo títulos y recuperando pasos de la BD).

import { detectarRiesgo } from './palabrasRiesgo.js';

/**
 * Normaliza nombres de categoría para comparación ('ELECTRICA', 'Eléctrica', etc.).
 */
function normalizarCategoria(cat) {
  if (!cat) return '';
  return String(cat)
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .trim()
    .toLowerCase()
    .replace(/[\s_-]+/g, '');
}

/**
 * Evalúa si un ticket califica para una guía de autoayuda:
 * 1. Filtro en código de palabras de riesgo -> Desvía de inmediato sin pasar por la IA.
 * 2. Consulta de guías autogestionables de la categoría.
 * 3. Consulta a Groq pasando ÚNICAMENTE los títulos, con instrucción conservadora ante la duda.
 * 4. Si la IA selecciona una guía, los pasos se leen de la base de datos/repositorio por id (nunca generados por la IA).
 * 
 * @param {object} params
 * @param {import('./clienteGroq.js').ClienteGroq} params.groqClient
 * @param {object} params.ticket - { categoria, descripcion, ubicacion, ticketId }
 * @param {Array} params.guiasVigentes - Lista completa de guías activas en el repositorio/BD
 * @returns {Promise<{ aplicable: boolean, guia: object | null, desviadoPorRiesgo: boolean, palabraRiesgo: string | null, motivo: string }>}
 */
export async function evaluarGuiaConIA({ groqClient, ticket, guiasVigentes = [] }) {
  const descripcion = String(ticket.descripcion ?? ticket.title ?? '');
  const categoria = ticket.categoria ?? ticket.category;

  // 1. REGLA DE RIESGO: Si contiene palabras de riesgo, se desvía sin pasar por la IA
  const riesgo = detectarRiesgo(descripcion);
  if (riesgo.tieneRiesgo) {
    return {
      aplicable: false,
      guia: null,
      desviadoPorRiesgo: true,
      palabraRiesgo: riesgo.palabra,
      motivo: `Ticket desviado a personal técnico sin consultar a la IA por riesgo detectado: '${riesgo.palabra}'.`,
    };
  }

  // 2. Filtrar guías autogestionables de la categoría del ticket
  const catTicket = normalizarCategoria(categoria);
  const guiasCandidatas = (guiasVigentes || []).filter((g) => {
    const catGuia = normalizarCategoria(g.categoria);
    const esAutogestionable = Boolean(g.autogestionable);
    return catGuia === catTicket && esAutogestionable;
  });

  if (guiasCandidatas.length === 0) {
    return {
      aplicable: false,
      guia: null,
      desviadoPorRiesgo: false,
      palabraRiesgo: null,
      motivo: 'No existen guías de autoayuda autogestionables configuradas para esta categoría.',
    };
  }

  // 3. Preparar mensaje para Groq: SOLO enviamos IDs y títulos (problema), NUNCA los pasos
  const catalogoTitulos = guiasCandidatas.map((g) => ({
    id: String(g.id),
    titulo_problema: g.problema,
  }));

  const promptSistema = `Eres un asistente conservador de soporte técnico para GA.MA Servicios Generales.
Tu función es determinar si la falla reportada por un colaborador corresponde a una guía de autoayuda para que la solucione él mismo de forma rápida y segura.

REGLA ESTRICTA DE SEGURIDAD (CONSERVADOR ANTE LA DUDA):
1. Si la falla reportada coincide claramente con el título de una guía de autoayuda (ej: "luz no enciende" -> ampolleta quemada; "dispensador vacío" -> reponer insumo), responde con el ID de esa guía.
2. Si la falla parece más compleja, requiere herramientas especiales, presenta dudas, o no encaja de forma precisa en ningún título, debes responder "ninguna" (guiaId: null).
3. Ante la menor discrepancia o duda, sé conservador y responde null.
4. Jamás inventes pasos ni guías que no estén en la lista.

Responde ÚNICAMENTE un objeto JSON válido con el siguiente formato:
{
  "guiaId": "id_de_la_guia" | null,
  "confianza": número entre 0.0 y 1.0,
  "motivo": "explicación breve y conservadora del veredicto"
}`;

  const promptUsuario = `Falla reportada por el colaborador:
"${descripcion}" (Categoría: ${categoria})

Títulos de guías autogestionables disponibles:
${JSON.stringify(catalogoTitulos, null, 2)}

Selecciona la guía aplicable o ninguna si hay dudas.`;

  try {
    const rawRespuesta = await groqClient.completar({
      messages: [
        { role: 'system', content: promptSistema },
        { role: 'user', content: promptUsuario },
      ],
      temperature: 0,
      responseFormat: { type: 'json_object' },
    });

    const parsed = JSON.parse(rawRespuesta);
    const idSugerido = parsed.guiaId ? String(parsed.guiaId) : null;
    const confianza = typeof parsed.confianza === 'number' ? parsed.confianza : 0;

    // Solo se aprueba si la confianza es alta (>= 0.7) y la guía existe en la BD
    if (idSugerido && confianza >= 0.7) {
      // 4. LOS PASOS SE LEEN DE LA BASE DE DATOS/REPOSITORIO POR ID, NUNCA DE LA IA
      const guiaReal = guiasCandidatas.find((g) => String(g.id) === idSugerido);
      if (guiaReal) {
        return {
          aplicable: true,
          guia: {
            id: String(guiaReal.id),
            categoria: guiaReal.categoria,
            problema: guiaReal.problema,
            pasos: guiaReal.pasos, // Leído íntegramente de la base de datos
            autogestionable: true,
          },
          desviadoPorRiesgo: false,
          palabraRiesgo: null,
          confianza,
          motivo: parsed.motivo || 'Guía de autoayuda asignada exitosamente.',
        };
      }
    }

    return {
      aplicable: false,
      guia: null,
      desviadoPorRiesgo: false,
      palabraRiesgo: null,
      confianza,
      motivo: parsed.motivo || 'No se encontró una guía autogestionable aplicable con certeza suficiente.',
    };
  } catch (error) {
    return {
      aplicable: false,
      guia: null,
      desviadoPorRiesgo: false,
      palabraRiesgo: null,
      confianza: 0,
      motivo: `Error al evaluar guía con IA: ${error.message}`,
    };
  }
}

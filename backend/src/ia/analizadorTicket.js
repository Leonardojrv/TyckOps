// Analizador integral de tickets con Groq: Detección de duplicados y asignación conservadora de guías.

import { evaluarDuplicadoConIA, filtrarCandidatosDuplicados } from './duplicados.js';
import { evaluarGuiaConIA } from './guiasMatcher.js';

export class AnalizadorTicket {
  /**
   * @param {object} params
   * @param {import('./clienteGroq.js').ClienteGroq} params.groqClient - Único cliente de Groq compartido
   * @param {object} [params.ticketRepository] - Repositorio para buscar candidatos a duplicado
   * @param {object} [params.guiasRepository] - Repositorio para consultar las guías vigentes y sus pasos
   */
  constructor({ groqClient, ticketRepository = null, guiasRepository = null } = {}) {
    this.groqClient = groqClient;
    this.ticketRepository = ticketRepository;
    this.guiasRepository = guiasRepository;
  }

  /**
   * Ejecuta el análisis completo del ticket:
   * 1. Veredicto de duplicado (con filtro de candidatos y prompt validado).
   * 2. Veredicto de guía de autoayuda (desvío por riesgo en código, prompt solo con títulos, pasos de BD).
   * 
   * @param {object} ticket - { ticketId, categoria, descripcion, ubicacion }
   * @returns {Promise<{ ticketId: string, duplicado: object, guia: object }>}
   */
  async analizar(ticket) {
    const ticketId = String(ticket.ticketId ?? ticket.id ?? '');

    // 1. Obtener candidatos activos para duplicados
    let candidatos = [];
    if (this.ticketRepository?.findActiveCandidates) {
      candidatos = await this.ticketRepository.findActiveCandidates({
        category: ticket.categoria ?? ticket.category,
        location: ticket.ubicacion ?? ticket.location,
        excludeId: ticketId,
      });
    } else if (this.ticketRepository?.tickets) {
      candidatos = filtrarCandidatosDuplicados(ticket, this.ticketRepository.tickets);
    }

    // 2. Obtener guías vigentes
    let guiasVigentes = [];
    if (this.guiasRepository?.obtenerVersionActiva) {
      const versionActiva = await this.guiasRepository.obtenerVersionActiva();
      guiasVigentes = versionActiva?.guias ?? [];
    }

    // 3. Ejecutar ambas evaluaciones
    const [duplicado, guia] = await Promise.all([
      evaluarDuplicadoConIA({
        groqClient: this.groqClient,
        ticket,
        candidatos,
      }),
      evaluarGuiaConIA({
        groqClient: this.groqClient,
        ticket,
        guiasVigentes,
      }),
    ]);

    return {
      ticketId,
      duplicado,
      guia,
    };
  }
}

export class AnalizadorIntegrado {
  constructor({ analizadorDuplicadosGuias, analizadorPrioridad }) {
    this.analizadorDuplicadosGuias = analizadorDuplicadosGuias;
    this.analizadorPrioridad = analizadorPrioridad;
  }

  async analizar(datos) {
    const analisisTickets = await this.analizadorDuplicadosGuias.analizar(datos);
    const guiaId = analisisTickets?.guia?.aplicable
      ? analisisTickets.guia.guia?.id ?? null
      : null;
    const analisisPrioridad = await this.analizadorPrioridad.analizar({
      ...datos,
      ...(guiaId && { guiaId }),
    });

    return {
      ...analisisTickets,
      ...analisisPrioridad,
    };
  }
}

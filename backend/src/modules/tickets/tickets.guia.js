// ¿PARA QUÉ SIRVE?
//   Arma la "Guía de solución IA" que ve el colaborador cuando su ticket es de
//   prioridad Baja (T10 · RF-10).
//
// ¿QUÉ HACE?
//   Decide si un ticket puede usar la guía (es tuyo, sigue Recibido, prioridad
//   Baja y nadie decidió aún) y entrega los pasos, en este orden:
//   1. Una guía SIMULADA del problema que describe el ticket ("mi computador no
//      prende", "no hay jabón"...), mientras el servicio de IA no entregue la suya.
//   2. Una guía vigente que cargó el administrador para esa categoría.
//   3. Una guía simulada general de la categoría.
//   Los pasos nunca los escribe la IA: salen de aquí o de las guías cargadas.
//
// ¿CÓMO LO CAMBIO?
//   - Para agregar un problema que se pueda resolver solo, súmalo a
//     PROBLEMAS_SIMPLES con sus palabras y sus pasos (pasos seguros, sin
//     herramientas ni abrir equipos).
//   - Cuando el servicio de IA guarde qué guía eligió, cambia `elegirGuia` para
//     buscarla por su id.

// Prioridad y estados en que se muestra o continúa la guía.
const PRIORIDAD_AUTOAYUDA = 'BAJA';
const ESTADOS_AUTOAYUDA = new Set(['RECIBIDO', 'AUTOGESTION']);

// Lo que queda guardado en TipoSolucion después de que el colaborador decide.
export const SOLUCION_AUTOAYUDA = 'autoayuda_ia'; // "Cerrar ticket (Problema solucionado)"
export const SOLUCION_ESCALADA = 'escalado_colaborador'; // "Reportar a administración"

const MAX_PASOS = 10;
const MAX_TEXTO = 300;

// "Eléctrica" / "ELECTRICA" / "Electricidad" -> "electrica"
function normalizar(texto) {
  return String(texto ?? '')
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/[\s_-]+/g, '');
}

// "Mi computador NO prende." -> "mi computador no prende" (para buscar palabras)
export function textoPlano(texto) {
  return String(texto ?? '')
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9ñ\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function claveCategoria(categoria) {
  const c = normalizar(categoria);
  if (c.startsWith('electric')) return 'electrica';
  if (c.startsWith('bano')) return 'banos';
  if (c.startsWith('aire')) return 'aire';
  if (c.startsWith('inmo') || c.startsWith('mobil')) return 'inmobiliario';
  return c;
}

// "no prende", "no quiere prender", "no enciende", "no funciona"...
const NO_FUNCIONA = /\bno\b(?:\s+\w+){0,2}\s+(?:prende|prender|enciende|encender|funciona|funcionar|carga|cargar|responde|arranca|da imagen)\b/;

// Fallas simples que el colaborador puede revisar solo. Para que una calce, el
// texto debe nombrar el objeto Y el síntoma.
const PROBLEMAS_SIMPLES = [
  {
    id: 'computador-no-enciende',
    titulo: 'Equipo computacional que no enciende',
    objeto: /\b(computador|computadora|pc|notebook|laptop|cpu|monitor|pantalla|impresora)\b/,
    sintoma: [NO_FUNCIONA, /\bapagad[oa]\b/, /\bpantalla (negra|en negro)\b/],
    pasos: [
      ['Revise el cable de poder', 'Verifique que el cable esté bien conectado al equipo y al enchufe, sin daños visibles.'],
      ['Pruebe la zapatilla o el enchufe', 'Compruebe que el interruptor de la zapatilla esté encendido y pruebe conectando el equipo en otro enchufe cercano.'],
      ['Reinicie el equipo', 'Mantenga presionado el botón de encendido por 10 segundos, espere unos segundos y vuelva a encenderlo.'],
      ['Revise el monitor', 'Si el equipo enciende pero no hay imagen, compruebe que el monitor esté encendido y su cable de video bien conectado.'],
    ],
  },
  {
    id: 'luz-no-enciende',
    titulo: 'Luz o luminaria que no enciende',
    objeto: /\b(luz|luces|ampolleta|ampolletas|luminaria|lampara|foco|tubo)\b/,
    sintoma: [NO_FUNCIONA, /\bapagad[oa]s?\b/, /\bquemad[oa]s?\b/],
    pasos: [
      ['Revise el interruptor', 'Compruebe que el interruptor de la luz esté encendido y pruebe apagarlo y encenderlo una vez.'],
      ['Compare con otras luces', 'Verifique si otras luces del mismo sector funcionan. Si ninguna enciende, puede ser un corte del sector.'],
      ['No manipule la luminaria', 'Si solo esa luz no enciende, no intente cambiar la ampolleta usted mismo: repórtelo para el cambio.'],
    ],
  },
  {
    id: 'dispensador-vacio',
    titulo: 'Dispensador sin insumo',
    objeto: /\b(dispensador|jabon|papel|toalla|toallas|alcohol gel)\b/,
    sintoma: [/\b(vacio|vacia|sin|no hay|se acabo|no sale|agotad[oa])\b/],
    pasos: [
      ['Revise la tapa del dispensador', 'Compruebe que la tapa esté bien cerrada y que el botón o palanca no esté trabado.'],
      ['Busque repuesto en el piso', 'Revise si hay insumos de repuesto en la despensa del piso y repóngalo si está disponible.'],
      ['Avise si no hay stock', 'Si no hay repuesto, repórtelo a administración para que el personal de aseo lo reponga.'],
    ],
  },
  {
    id: 'aire-no-responde',
    titulo: 'Aire acondicionado que no enfría o no responde',
    objeto: /\b(aire|climatizador|control remoto)\b/,
    sintoma: [NO_FUNCIONA, /\bno (enfria|calienta|refresca)\b/],
    pasos: [
      ['Revise el control remoto', 'Cambie o reacomode las pilas del control y apunte directo al equipo.'],
      ['Revise el modo y la temperatura', 'Compruebe que esté en modo frío o calor (no ventilación) y con una temperatura distinta a la del ambiente.'],
      ['Despeje el equipo', 'Verifique que nada tape la salida de aire ni el sensor del equipo.'],
    ],
  },
  {
    id: 'mueble-no-ajusta',
    titulo: 'Silla o mueble que no se ajusta',
    objeto: /\b(silla|sillas|escritorio|cajon|cajonera|mueble)\b/,
    sintoma: [/\bno (sube|baja|se ajusta|abre|cierra|gira)\b/, /\btrabad[oa]\b/, /\bse atasca\b/],
    pasos: [
      ['Revise los ajustes', 'Compruebe que palancas, perillas o seguros no estén bloqueados y que se puedan mover a mano.'],
      ['Retire peso', 'Quite objetos pesados del mueble o de los cajones y vuelva a intentarlo.'],
      ['No lo use si es inseguro', 'Si el mueble se tambalea o tiene piezas rotas, deje de usarlo y repórtelo a administración.'],
    ],
  },
  {
    id: 'enchufe-sin-corriente',
    titulo: 'Enchufe o zapatilla sin corriente',
    objeto: /\b(enchufe|enchufes|tomacorriente|zapatilla)\b/,
    sintoma: [NO_FUNCIONA, /\bsin (corriente|energia|luz)\b/, /\bno (da|tiene) (corriente|energia)\b/],
    pasos: [
      ['Inspección visual del cableado', 'Verifique visualmente que el cable y el conector no presenten daños físicos, dobleces agresivos o cortes visibles. No los toque si están dañados.'],
      ['Revise el interruptor de la zapatilla', 'Compruebe que la zapatilla esté encendida y bien conectada a la pared.'],
      ['Prueba con otro equipo', 'Conecte un equipo pequeño (por ejemplo, un cargador) para saber si la falla es del enchufe o del equipo.'],
    ],
  },
];

// Guías generales por categoría (si el texto no calza con ningún problema).
const GUIAS_CATEGORIA = {
  electrica: 'enchufe-sin-corriente',
  banos: 'dispensador-vacio',
  aire: 'aire-no-responde',
  inmobiliario: 'mueble-no-ajusta',
};

const GUIA_GENERICA = {
  id: 'revision-basica',
  titulo: 'Revisión básica',
  pasos: [
    ['Revise el entorno', 'Compruebe que el equipo o lugar no esté desconectado, apagado o bloqueado por algo externo.'],
    ['Pruebe nuevamente', 'Espere unos minutos e inténtelo otra vez.'],
  ],
};

/**
 * La falla simple que describe el texto, o null si no calza con ninguna.
 * Ejemplo: "Mi computador no quiere prender" -> computador-no-enciende.
 */
export function buscarProblemaSimple(texto) {
  const t = textoPlano(texto);
  if (!t) return null;
  return PROBLEMAS_SIMPLES.find((p) => p.objeto.test(t) && p.sintoma.some((s) => s.test(t))) ?? null;
}

// Corta textos largos y quita lo que no es texto plano (las guías vigentes ya
// vienen sanitizadas, esto es una segunda barrera).
function limpiar(texto) {
  return String(texto ?? '').replace(/<[^>]*>/g, '').replace(/\s+/g, ' ').trim().slice(0, MAX_TEXTO);
}

/**
 * Convierte el texto de una guía cargada ("1. Verificar interruptor.\n2. ...")
 * en pasos { titulo, detalle }. Si una línea trae "Título: detalle", se separa.
 */
export function pasosDesdeTexto(texto) {
  return String(texto ?? '')
    .split(/\r?\n/)
    .map((linea) => linea.replace(/^\s*\d+[.)-]?\s*/, '').trim())
    .filter(Boolean)
    .slice(0, MAX_PASOS)
    .map((linea) => {
      const i = linea.indexOf(':');
      return i > 0 && i < 80
        ? { titulo: limpiar(linea.slice(0, i)), detalle: limpiar(linea.slice(i + 1)) }
        : { titulo: limpiar(linea), detalle: '' };
    });
}

/** ¿El ticket puede usar la guía? (prioridad Baja, Recibido y sin decisión previa). */
export function admiteAutoayuda(ticket) {
  return String(ticket?.priority ?? '').toUpperCase() === PRIORIDAD_AUTOAYUDA
    && ESTADOS_AUTOAYUDA.has(String(ticket?.status ?? '').toUpperCase())
    && !ticket?.solutionType;
}

function comoGuia(problema) {
  return {
    id: problema.id,
    titulo: problema.titulo,
    origen: 'simulada',
    pasos: problema.pasos.map(([titulo, detalle]) => ({ titulo, detalle })),
  };
}

/**
 * La guía para un ticket (ver el orden arriba).
 * @returns {{ id: string, titulo: string, origen: 'vigente' | 'simulada', pasos: {titulo: string, detalle: string}[] }}
 */
export function elegirGuia(ticket, guiasVigentes = []) {
  // 1. El problema concreto que describió el colaborador.
  const problema = buscarProblemaSimple(ticket?.description ?? ticket?.title);
  if (problema) return comoGuia(problema);

  // 2. Una guía vigente del administrador para esa categoría.
  const clave = claveCategoria(ticket?.category);
  const vigente = (guiasVigentes ?? []).find(
    (g) => g?.autogestionable && claveCategoria(g.categoria) === clave && pasosDesdeTexto(g.pasos).length > 0,
  );
  if (vigente) {
    return { id: String(vigente.id), titulo: limpiar(vigente.problema), origen: 'vigente', pasos: pasosDesdeTexto(vigente.pasos) };
  }

  // 3. La guía general de la categoría (o una revisión básica).
  const general = PROBLEMAS_SIMPLES.find((p) => p.id === GUIAS_CATEGORIA[clave]) ?? GUIA_GENERICA;
  return comoGuia(general);
}

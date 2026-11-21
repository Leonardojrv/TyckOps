import ExcelJS from 'exceljs';
import { normalizarBooleano, normalizarCategoria, quitarHtml } from './guias.sanitizar.js';

export const COLUMNAS_REQUERIDAS = ['id', 'categoria', 'problema', 'pasos', 'autogestionable'];

/**
 * Normaliza el nombre de un encabezado (quita acentos, minúsculas, sin espacios).
 */
function normalizarEncabezado(texto) {
  if (!texto) return '';
  return String(texto)
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .trim()
    .toLowerCase()
    .replace(/[\s_-]+/g, '');
}

/**
 * Genera el archivo Excel (.xlsx) de plantilla con las 5 columnas requeridas y filas de ejemplo.
 * @returns {Promise<Buffer>}
 */
export async function generarPlantillaExcel() {
  const workbook = new ExcelJS.Workbook();
  workbook.creator = 'TyckOps - GA.MA Servicios Generales';
  workbook.created = new Date();

  const worksheet = workbook.addWorksheet('Plantilla Guías', {
    views: [{ state: 'frozen', ySplit: 1 }],
  });

  worksheet.columns = [
    { header: 'id', key: 'id', width: 10 },
    { header: 'categoría', key: 'categoria', width: 22 },
    { header: 'problema', key: 'problema', width: 35 },
    { header: 'pasos', key: 'pasos', width: 55 },
    { header: 'autogestionable', key: 'autogestionable', width: 18 },
  ];

  // Estilo del encabezado
  const filaEncabezado = worksheet.getRow(1);
  filaEncabezado.font = { name: 'Arial', size: 11, bold: true, color: { argb: 'FFFFFFFF' } };
  filaEncabezado.fill = {
    type: 'pattern',
    pattern: 'solid',
    fgColor: { argb: 'FFB3011A' }, // Color corporativo GA.MA
  };
  filaEncabezado.alignment = { vertical: 'middle', horizontal: 'center', wrapText: true };
  filaEncabezado.height = 28;

  // Filas de ejemplo instructivas
  worksheet.addRow({
    id: 1,
    categoria: 'Eléctrica',
    problema: 'Luz o ampolleta no enciende en puesto de trabajo',
    pasos: '1. Verificar interruptor local.\n2. Comprobar si otras luces del sector funcionan.\n3. Si solo es una ampolleta, cambiar por repuesto disponible.',
    autogestionable: 'SI',
  });

  worksheet.addRow({
    id: 2,
    categoria: 'Baños',
    problema: 'Dispensador de jabón o papel higiénico vacío',
    pasos: '1. Verificar despensa de insumos del piso.\n2. Reponer si hay disponibilidad.\n3. Si no hay stock, reportar a personal de limpieza.',
    autogestionable: 'SI',
  });

  worksheet.addRow({
    id: 3,
    categoria: 'Aire acondicionado',
    problema: 'Control remoto de climatización no responde',
    pasos: '1. Revisar las pilas del control remoto.\n2. Verificar que el sensor del equipo no esté obstruido.',
    autogestionable: 'SI',
  });

  // Ajuste de alineación y bordes
  worksheet.eachRow((row, rowNumber) => {
    if (rowNumber > 1) {
      row.alignment = { vertical: 'top', wrapText: true };
      row.font = { name: 'Arial', size: 10 };
    }
  });

  const buffer = await workbook.xlsx.writeBuffer();
  return Buffer.from(buffer);
}

/**
 * Lee y valida exhaustivamente un archivo Excel (.xlsx) subido por el administrador.
 * @param {Buffer} buffer
 * @returns {Promise<{ success: true, guias: Array } | { success: false, codigo: string, mensaje: string, errores?: Array }>}
 */
export async function procesarArchivoExcel(buffer) {
  if (!buffer || buffer.length === 0) {
    return {
      success: false,
      codigo: 'ARCHIVO_VACIO',
      mensaje: 'El archivo subido está vacío.',
    };
  }

  const workbook = new ExcelJS.Workbook();
  try {
    await workbook.xlsx.load(buffer);
  } catch (error) {
    return {
      success: false,
      codigo: 'FORMATO_INVALIDO',
      mensaje: 'El archivo no es un documento Excel (.xlsx) válido o está dañado.',
    };
  }

  const worksheet = workbook.worksheets[0];
  if (!worksheet || worksheet.rowCount < 1) {
    return {
      success: false,
      codigo: 'ARCHIVO_VACIO',
      mensaje: 'El archivo no contiene hojas de cálculo o está vacío.',
    };
  }

  // Mapear encabezados de la fila 1
  const fila1 = worksheet.getRow(1);
  const mapaColumnas = new Map();

  fila1.eachCell({ includeEmpty: false }, (cell, colNumber) => {
    const norm = normalizarEncabezado(cell.text ?? cell.value);
    if (norm === 'categoria') mapaColumnas.set('categoria', colNumber);
    else if (norm === 'id') mapaColumnas.set('id', colNumber);
    else if (norm === 'problema') mapaColumnas.set('problema', colNumber);
    else if (norm === 'pasos') mapaColumnas.set('pasos', colNumber);
    else if (norm === 'autogestionable') mapaColumnas.set('autogestionable', colNumber);
  });

  // Validar que estén las 5 columnas requeridas
  const faltantes = COLUMNAS_REQUERIDAS.filter((col) => !mapaColumnas.has(col));
  if (faltantes.length > 0) {
    return {
      success: false,
      codigo: 'COLUMNAS_INVALIDAS',
      mensaje: `El archivo debe contener las columnas: id, categoría, problema, pasos, autogestionable. Faltan: ${faltantes.join(', ')}.`,
    };
  }

  const guiasValidas = [];
  const errores = [];

  // Recorrer filas desde la 2
  for (let numFila = 2; numFila <= worksheet.rowCount; numFila += 1) {
    const fila = worksheet.getRow(numFila);

    // Obtener valores crudos
    const rawId = fila.getCell(mapaColumnas.get('id')).value;
    const rawCategoria = fila.getCell(mapaColumnas.get('categoria')).value;
    const rawProblema = fila.getCell(mapaColumnas.get('problema')).value;
    const rawPasos = fila.getCell(mapaColumnas.get('pasos')).value;
    const rawAutogestionable = fila.getCell(mapaColumnas.get('autogestionable')).value;

    // Verificar si la fila está completamente vacía (muy común al final de Excel)
    const tieneContenido = [rawId, rawCategoria, rawProblema, rawPasos, rawAutogestionable].some(
      (v) => v !== null && v !== undefined && String(v).trim() !== '',
    );
    if (!tieneContenido) continue;

    // 1. Sanitizar y validar Categoría
    const catLimpia = normalizarCategoria(rawCategoria);
    if (!catLimpia) {
      errores.push({
        fila: numFila,
        campo: 'categoría',
        error: `La categoría '${rawCategoria ?? ''}' no es válida. Debe ser Eléctrica, Baños, Aire acondicionado o Inmobiliario.`,
      });
    }

    // 2. Sanitizar y validar Problema (quitar HTML)
    const probLimpio = quitarHtml(rawProblema);
    if (!probLimpio || probLimpio.length < 3) {
      errores.push({
        fila: numFila,
        campo: 'problema',
        error: 'El campo problema es obligatorio y debe tener al menos 3 caracteres.',
      });
    } else if (probLimpio.length > 300) {
      errores.push({
        fila: numFila,
        campo: 'problema',
        error: 'El campo problema no debe superar los 300 caracteres.',
      });
    }

    // 3. Sanitizar y validar Pasos (quitar HTML)
    const pasosLimpio = quitarHtml(rawPasos);
    if (!pasosLimpio || pasosLimpio.length < 5) {
      errores.push({
        fila: numFila,
        campo: 'pasos',
        error: 'El campo pasos es obligatorio y debe contener al menos 5 caracteres con las instrucciones.',
      });
    } else if (pasosLimpio.length > 2500) {
      errores.push({
        fila: numFila,
        campo: 'pasos',
        error: 'El campo pasos supera el límite máximo de 2500 caracteres.',
      });
    }

    // 4. Validar Autogestionable
    const autoBool = normalizarBooleano(rawAutogestionable);
    if (autoBool === null) {
      errores.push({
        fila: numFila,
        campo: 'autogestionable',
        error: `El valor '${rawAutogestionable ?? ''}' no es válido para autogestionable. Debe ser SI o NO.`,
      });
    }

    // 5. Validar o asignar ID
    const idLimpio = rawId !== null && rawId !== undefined && String(rawId).trim() !== ''
      ? String(rawId).trim()
      : String(guiasValidas.length + 1);

    if (catLimpia && probLimpio && probLimpio.length >= 3 && pasosLimpio && pasosLimpio.length >= 5 && autoBool !== null) {
      guiasValidas.push({
        id: idLimpio,
        categoria: catLimpia,
        problema: probLimpio,
        pasos: pasosLimpio,
        autogestionable: autoBool,
      });
    }
  }

  if (errores.length > 0) {
    return {
      success: false,
      codigo: 'ERRORES_VALIDACION',
      mensaje: 'Se encontraron errores de validación en una o más filas del archivo.',
      errores,
    };
  }

  if (guiasValidas.length === 0) {
    return {
      success: false,
      codigo: 'ARCHIVO_VACIO',
      mensaje: 'El archivo no contiene filas con datos de guías válidas.',
    };
  }

  return {
    success: true,
    guias: guiasValidas,
  };
}

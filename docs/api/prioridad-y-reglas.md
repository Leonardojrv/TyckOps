# Prioridad inicial con IA y reglas (Hito MM2)

Explicación corta de cómo el backend decide la prioridad de un ticket nuevo y de cómo se usan los endpoints nuevos.

---

## 1. ¿Cómo se decide la prioridad?

Cuando un colaborador reporta una falla, el backend crea el ticket **al tiro** (el colaborador no espera) y en segundo plano le asigna una prioridad **en este orden**:

| Paso | ¿Cuándo? | Prioridad | Origen que se guarda |
|---|---|---|---|
| 1 | El ticket calza con una **guía de autoayuda** (incidencia menor) | **Baja** | `guia` |
| 2 | No calza con una guía → la **IA elige una regla** del .txt | La que dice esa regla (**alta** o **media**) | `regla` |
| 3a | Ninguna regla calza, o no hay reglas para esa categoría | **Media** | `defecto` |
| 3b | La IA falla, tarda demasiado o responde algo inválido | **Media** | `falla_ia` |

**Un ticket nunca queda sin prioridad.**

### La IA no inventa prioridades

- La IA recibe **solo las reglas de la categoría del ticket** (por ejemplo, solo las de Eléctrica), y **sin** su prioridad.
- La IA solo responde **el id** de la regla que calza (o "ninguna").
- El **código** revisa que ese id sea uno de los que se le enviaron y pone la prioridad que dice la regla.
- Si la IA responde un id que no existe o que es de otra categoría, se trata como falla de la IA → **media**.

### Regla de seguridad

Si la descripción tiene palabras de **riesgo** (chispas, humo, olor a quemado, fuga, fuego, cortocircuito, cable pelado, inundación...), el ticket **nunca** queda en baja y **no se buscan guías de autoayuda**. La prioridad sale de las reglas, o queda en media.

### Ejemplos

| Lo que escribe el colaborador | Categoría | Resultado |
|---|---|---|
| "Se quemó la ampolleta de mi escritorio" | Eléctrica | **Baja** (calza con una guía) |
| "El tablero del piso 3 saca chispas" | Eléctrica | **Alta** (regla ELE-01). Nunca baja: tiene palabra de riesgo |
| "No funciona el enchufe de mi puesto" | Eléctrica | **Media** (regla ELE-04) |
| "La pared tiene un color raro" | Inmobiliario | **Media** (ninguna regla calza → `defecto`) |
| Groq no responde | cualquiera | **Media** (`falla_ia`) |

> **Hoy:** el paso 1 (guías) se activa cuando se integre el módulo de guías. Mientras tanto, los tickets van directo al paso 2.
> Sin `GROQ_API_KEY` en `backend/.env`, todos los tickets que no calzan con una guía quedan en **media** (`falla_ia`).

---

## 2. Archivo de reglas (.txt)

Ejemplo completo y comentado: [`docs/requerimientos/reglas-prioridad-ejemplo.txt`](../requerimientos/reglas-prioridad-ejemplo.txt)

```
id | categoria | prioridad | descripcion
ELE-01 | Electrica | alta | Enchufe, interruptor o tablero que saca chispas, humo u olor a quemado
BAN-03 | Banos | media | WC o urinario tapado o que no descarga
```

- **prioridad:** solo `alta` o `media` (la baja la da una guía).
- **categoria:** `Electrica`, `Banos`, `Aire acondicionado` o `Inmobiliario`.
- **id:** único en el archivo.
- Líneas con `#` son comentarios.

Las reglas tienen **versiones**, igual que las guías: subir un archivo crea una versión **inactiva**; recién al **activarla** empieza a usarse. Solo hay una versión activa a la vez.

---

## 3. Endpoints nuevos

Todos requieren `Authorization: Bearer <token>` de un **administrador** con los Términos aceptados.
Las respuestas siguen el formato de siempre: `{ "success": true, "data": ... }` o `{ "success": false, "error": { "code", "message", "details" } }`.

### `POST /api/reglas/archivo` — subir el .txt

`multipart/form-data`, campo **`archivo`** (extensión `.txt`, máx. 200 KB, UTF-8).

**201 — archivo válido** (queda inactivo):
```json
{
  "success": true,
  "data": {
    "version": 3,
    "activa": false,
    "subidaEn": "2026-11-20T15:00:00.000Z",
    "activadaEn": null,
    "totalReglas": 17,
    "mensaje": "Archivo válido con 17 reglas. Versión 3 lista para activarse.",
    "reglas": [
      { "id": "ELE-01", "categoria": "ELECTRICA", "prioridad": "ALTA", "descripcion": "Enchufe, interruptor o tablero que saca chispas..." }
    ]
  }
}
```

**400 — archivo con errores** (no se guarda nada; vienen **todos** los errores con su línea):
```json
{
  "success": false,
  "error": {
    "code": "ERRORES_VALIDACION",
    "message": "El archivo tiene 2 error(es). Corrígelos y vuelve a subirlo.",
    "details": [
      { "linea": 4, "campo": "prioridad", "mensaje": "Una regla no puede ser \"baja\": la prioridad baja la da una guía de autoayuda. Usa \"alta\" o \"media\"." },
      { "linea": 7, "campo": "id", "mensaje": "El id \"ELE-01\" ya se usó en la línea 3." }
    ]
  }
}
```

Otros errores: `ARCHIVO_REQUERIDO` (400), `FORMATO_INVALIDO` (400, no es .txt o no es texto), `ARCHIVO_MUY_GRANDE` (413).

### `POST /api/reglas/:version/activar` — activar una versión

Ejemplo: `POST /api/reglas/3/activar` (también acepta `v3`). Desactiva la versión anterior.

**200:**
```json
{ "success": true, "data": { "version": 3, "activa": true, "subidaEn": "...", "activadaEn": "...", "mensaje": "Versión 3 activada: las reglas ya se usan en los tickets nuevos." } }
```
**404** `VERSION_NO_ENCONTRADA` si no existe.

### `GET /api/reglas` — reglas vigentes

**200:**
```json
{
  "success": true,
  "data": {
    "version": { "version": 3, "activa": true, "subidaEn": "...", "activadaEn": "..." },
    "total": 17,
    "reglas": [ { "id": "ELE-01", "categoria": "ELECTRICA", "prioridad": "ALTA", "descripcion": "..." } ]
  }
}
```
Si nunca se activó un archivo: `"version": null, "total": 0, "reglas": []`.

### `PATCH /api/admin/tickets/:id/prioridad` — el administrador cambia la prioridad

Body JSON:
```json
{ "prioridad": "alta" }
```
(`baja`, `media` o `alta`, sin importar mayúsculas).

**200:**
```json
{
  "success": true,
  "data": {
    "ticket": {
      "id": "42",
      "status": "EN_REVISION",
      "priority": "ALTA",
      "initialPriority": "BAJA",
      "priorityOrigin": "guia",
      "ruleId": null,
      "changed": true
    }
  }
}
```
- `initialPriority` y `priorityOrigin` muestran lo que decidió el sistema al crear el ticket.
- `changed: false` si ya tenía esa prioridad (no se registra un cambio).
- Cada cambio queda guardado en la tabla `CambioPrioridad` (quién, cuándo, de cuál a cuál).

Errores: `DATOS_INVALIDOS` (400), `TICKET_NO_ENCONTRADO` (404), `PRIORIDAD_NO_MODIFICABLE` (409, el ticket ya está resuelto, cerrado, rechazado o cancelado).

### Tickets del colaborador

Sin cambios en las rutas: `GET /api/tickets/mis-tickets` y `GET /api/tickets/:id` ya traen `"priority": "ALTA" | "MEDIA" | "BAJA" | null`.
Justo después de crear un ticket la respuesta trae `priority: null`, porque la prioridad se calcula en segundo plano (toma unos segundos). Al volver a consultar ya aparece.

---

## 4. ¿Qué se guarda en la base de datos?

Migración `20261120120000_prioridad_inicial`:

| Tabla | Columna | Para qué |
|---|---|---|
| `Ticket` | `Prioridad` (ya existía) | Prioridad **actual** (el admin la puede cambiar) |
| `Ticket` | `PrioridadInicial` | Lo que decidió el sistema al crear el ticket |
| `Ticket` | `OrigenPrioridad` | `guia`, `regla`, `defecto` o `falla_ia` |
| `Ticket` | `ID_ReglaAplicada` | Id de la regla del .txt (ej. `ELE-01`) |
| `Ticket` | `ID_VersionReglas` | Qué versión del .txt se usó |
| `ReglasPrioridad` | `Activa`, `FechaActivacion` | Cada fila es una versión del .txt; solo una activa |
| `CambioPrioridad` (nueva) | anterior, nueva, admin, fecha | Historial de cambios del administrador |

**¿Cuántas veces corrige el admin a la IA?** Se puede medir comparando `PrioridadInicial` con `Prioridad`, o contando las filas de `CambioPrioridad` por `OrigenPrioridad`.

---

## 5. ¿Dónde está el código?

Orden sugerido para revisar:

1. [`backend/src/ia/analizadorPrioridad.js`](../../backend/src/ia/analizadorPrioridad.js): el orden de decisión (guía → regla → media).
2. [`backend/src/modules/reglas/reglas.parser.js`](../../backend/src/modules/reglas/reglas.parser.js): cómo se lee y valida el .txt.
3. [`backend/src/ia/reglasPrioridad.js`](../../backend/src/ia/reglasPrioridad.js): las palabras de riesgo.
4. [`backend/test/prioridad.test.js`](../../backend/test/prioridad.test.js) y [`backend/test/reglas.test.js`](../../backend/test/reglas.test.js): cada test es un ejemplo del comportamiento.

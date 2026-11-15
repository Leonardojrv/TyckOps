# -*- coding: utf-8 -*-
"""
Genera docs/pruebas/Reporte_Pruebas_TyckOps.pdf a partir de los resultados
reales de las pruebas:

  backend/integracion/resultados/jest-resultados.json     (Jest + Supertest)
  backend/integracion/resultados/node-test.txt            (node --test)
  mobile/test_integracion/resultados/flutter-unitarias.json
  mobile/test_integracion/resultados/flutter-integracion.json

Requiere: pip install reportlab
Uso:      python docs/pruebas/generar_reporte.py
"""
import json
import re
import sys
from datetime import datetime
from pathlib import Path

from reportlab.graphics.shapes import Drawing, Line, Polygon, Rect, String
from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import cm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (KeepTogether, PageBreak, Paragraph, SimpleDocTemplate,
                                Spacer, Table, TableStyle)

RAIZ = Path(__file__).resolve().parents[2]
SALIDA = RAIZ / "docs" / "pruebas" / "Reporte_Pruebas_TyckOps.pdf"

JEST = RAIZ / "backend/integracion/resultados/jest-resultados.json"
NODE_TXT = RAIZ / "backend/integracion/resultados/node-test.txt"
FL_UNIT = RAIZ / "mobile/test_integracion/resultados/flutter-unitarias.json"
FL_INT = RAIZ / "mobile/test_integracion/resultados/flutter-integracion.json"

# ---------------------------------------------------------------- estilo
ROJO = colors.HexColor("#B3011A")
ROJO_CLARO = colors.HexColor("#FBE9EB")
GRIS = colors.HexColor("#5E5E5E")
GRIS_CLARO = colors.HexColor("#F3F3F3")
BORDE = colors.HexColor("#D9D9D9")
VERDE = colors.HexColor("#1E7B34")
VERDE_CLARO = colors.HexColor("#E6F4EA")
AMBAR = colors.HexColor("#8A5A00")
AMBAR_CLARO = colors.HexColor("#FFF4E0")
TINTA = colors.HexColor("#1B1B1B")

FUENTES = Path("C:/Windows/Fonts")
pdfmetrics.registerFont(TTFont("Arial", str(FUENTES / "arial.ttf")))
pdfmetrics.registerFont(TTFont("Arial-Bold", str(FUENTES / "arialbd.ttf")))
pdfmetrics.registerFont(TTFont("Arial-Italic", str(FUENTES / "ariali.ttf")))
pdfmetrics.registerFont(TTFont("Consolas", str(FUENTES / "consola.ttf")))
pdfmetrics.registerFontFamily("Arial", normal="Arial", bold="Arial-Bold", italic="Arial-Italic")

E = {
    "titulo": ParagraphStyle("titulo", fontName="Arial-Bold", fontSize=26, leading=31, textColor=TINTA),
    "subtitulo": ParagraphStyle("subtitulo", fontName="Arial", fontSize=13, leading=18, textColor=GRIS),
    "h1": ParagraphStyle("h1", fontName="Arial-Bold", fontSize=16, leading=20, textColor=ROJO,
                         spaceBefore=6, spaceAfter=8),
    "h2": ParagraphStyle("h2", fontName="Arial-Bold", fontSize=12, leading=15, textColor=TINTA,
                         spaceBefore=10, spaceAfter=5),
    "p": ParagraphStyle("p", fontName="Arial", fontSize=9.5, leading=13.5, textColor=TINTA, spaceAfter=6),
    "nota": ParagraphStyle("nota", fontName="Arial", fontSize=8.5, leading=12, textColor=GRIS, spaceAfter=6),
    "celda": ParagraphStyle("celda", fontName="Arial", fontSize=8, leading=10.5, textColor=TINTA),
    "celda_b": ParagraphStyle("celda_b", fontName="Arial-Bold", fontSize=8, leading=10.5, textColor=TINTA),
    "celda_cab": ParagraphStyle("celda_cab", fontName="Arial-Bold", fontSize=8, leading=10.5,
                                textColor=colors.white),
    "codigo": ParagraphStyle("codigo", fontName="Consolas", fontSize=8, leading=11, textColor=TINTA,
                             backColor=GRIS_CLARO, borderPadding=(5, 6, 5, 6), spaceAfter=8, spaceBefore=2),
    "kpi_num": ParagraphStyle("kpi_num", fontName="Arial-Bold", fontSize=22, leading=26,
                              alignment=TA_CENTER, textColor=TINTA),
    "kpi_txt": ParagraphStyle("kpi_txt", fontName="Arial", fontSize=8, leading=10, alignment=TA_CENTER,
                              textColor=GRIS),
}


def P(texto, estilo="p"):
    return Paragraph(texto, E[estilo])


def tabla(filas, anchos, cabecera=True, zebra=True, estilos_extra=None):
    datos = []
    for i, fila in enumerate(filas):
        estilo = "celda_cab" if (cabecera and i == 0) else "celda"
        datos.append([c if not isinstance(c, str) else Paragraph(c, E[estilo]) for c in fila])
    t = Table(datos, colWidths=anchos, repeatRows=1 if cabecera else 0)
    st = [
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("TOPPADDING", (0, 0), (-1, -1), 4),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
        ("LEFTPADDING", (0, 0), (-1, -1), 5),
        ("RIGHTPADDING", (0, 0), (-1, -1), 5),
        ("LINEBELOW", (0, 0), (-1, -1), 0.4, BORDE),
    ]
    if cabecera:
        st.append(("BACKGROUND", (0, 0), (-1, 0), ROJO))
    if zebra:
        for i in range(1 if cabecera else 0, len(datos)):
            if i % 2 == 0:
                st.append(("BACKGROUND", (0, i), (-1, i), GRIS_CLARO))
    st.extend(estilos_extra or [])
    t.setStyle(TableStyle(st))
    return t


def insignia(estado):
    if estado == "ok":
        return '<font color="#1E7B34"><b>APROBADA</b></font>'
    if estado == "hallazgo":
        return '<font color="#8A5A00"><b>APROBADA*</b></font>'
    return '<font color="#B3011A"><b>FALLIDA</b></font>'


# ---------------------------------------------------------------- datos
def leer_jest():
    d = json.loads(JEST.read_text(encoding="utf-8"))
    pruebas = []
    for s in d["suites"]:
        for t in s["pruebas"]:
            pruebas.append({
                "suite": Path(s["archivo"]).name,
                "grupo": t["grupo"],
                "nombre": t["nombre"],
                "ok": t["estado"] == "passed",
                "ms": t["duracionMs"],
            })
    return d, pruebas


def leer_flutter(ruta):
    suites, grupos, inicios, pruebas = {}, {}, {}, []
    for linea in ruta.read_text(encoding="utf-8").splitlines():
        if not linea.strip().startswith("{"):
            continue
        ev = json.loads(linea)
        tipo = ev.get("type")
        if tipo == "suite":
            suites[ev["suite"]["id"]] = Path(ev["suite"]["path"]).name
        elif tipo == "group":
            g = ev["group"]
            grupos[g["id"]] = g["name"] or ""
        elif tipo == "testStart":
            inicios[ev["test"]["id"]] = (ev["test"], ev["time"])
        elif tipo == "testDone" and not ev.get("hidden"):
            t, t0 = inicios[ev["testID"]]
            grupo = next((grupos[g] for g in reversed(t["groupIDs"]) if grupos.get(g)), "")
            nombre = t["name"]
            if grupo and nombre.startswith(grupo + " "):
                nombre = nombre[len(grupo) + 1:]
            pruebas.append({
                "suite": suites.get(t["suiteID"], "?"),
                "grupo": grupo,
                "nombre": nombre,
                "ok": ev["result"] == "success" and not ev.get("skipped"),
                "ms": ev["time"] - t0,
            })
    return pruebas


def leer_node_test():
    texto = NODE_TXT.read_text(encoding="utf-8", errors="replace")
    pruebas = []
    for m in re.finditer(r"^([✔✖])\s+(.+?)\s+\(([\d.]+)ms\)\s*$", texto, re.M):
        pruebas.append({"suite": "app.test.js", "grupo": "", "nombre": m.group(2),
                        "ok": m.group(1) == "✔", "ms": float(m.group(3))})
    return pruebas


jest_resumen, P_JEST = leer_jest()
P_NODE = leer_node_test()
P_FL_UNIT = leer_flutter(FL_UNIT)
P_FL_INT = leer_flutter(FL_INT)

TODAS = P_JEST + P_NODE + P_FL_UNIT + P_FL_INT
TOTAL = len(TODAS)
OK = sum(p["ok"] for p in TODAS)
FALLIDAS = TOTAL - OK
FECHA = datetime.fromisoformat(jest_resumen["fecha"].replace("Z", "+00:00")).astimezone()


def cuenta(lista, **filtro):
    sel = [p for p in lista if all(f(p[k]) if callable(f) else p[k] == f for k, f in filtro.items())]
    return sum(p["ok"] for p in sel), len(sel)


# ---------------------------------------------------------------- pie de página
def decorar(canvas, doc):
    canvas.saveState()
    ancho, alto = A4
    if doc.page > 1:
        canvas.setFillColor(ROJO)
        canvas.rect(0, alto - 0.35 * cm, ancho, 0.35 * cm, stroke=0, fill=1)
        canvas.setFont("Arial", 7.5)
        canvas.setFillColor(GRIS)
        canvas.drawString(2 * cm, alto - 1.05 * cm, "TyckOps · Reporte de pruebas de integración")
        canvas.drawRightString(ancho - 2 * cm, alto - 1.05 * cm, FECHA.strftime("%d-%m-%Y"))
    canvas.setFont("Arial", 7.5)
    canvas.setFillColor(GRIS)
    canvas.drawCentredString(ancho / 2, 1.1 * cm, f"Página {doc.page}")
    canvas.restoreState()


# ---------------------------------------------------------------- diagrama
def diagrama_ecosistema():
    d = Drawing(17 * cm, 6.4 * cm)

    def caja(x, y, w, h, titulo, lineas, fondo=GRIS_CLARO, borde=BORDE, color_titulo=TINTA, tam=9):
        d.add(Rect(x, y, w, h, rx=6, ry=6, fillColor=fondo, strokeColor=borde, strokeWidth=1))
        d.add(String(x + w / 2, y + h - 15, titulo, fontName="Arial-Bold", fontSize=tam,
                     fillColor=color_titulo, textAnchor="middle"))
        for i, l in enumerate(lineas):
            d.add(String(x + w / 2, y + h - 29 - i * 11, l, fontName="Arial", fontSize=7.2,
                         fillColor=GRIS, textAnchor="middle"))

    def flecha(x1, y, x2, etiqueta):
        d.add(Line(x1, y, x2 - 5, y, strokeColor=ROJO, strokeWidth=1.4))
        d.add(Polygon([x2, y, x2 - 7, y + 3.5, x2 - 7, y - 3.5], fillColor=ROJO, strokeColor=ROJO))
        d.add(String((x1 + x2) / 2, y + 6, etiqueta, fontName="Arial", fontSize=6.8,
                     fillColor=ROJO, textAnchor="middle"))

    # App (0-90) · Backend (150-245) · Prisma (295-370) · Docker (380-482)
    y, h = 75, 88
    caja(0, y, 90, h, "App móvil", ["Flutter 3.50", "Dio + go_router", "Sesión con JWT"])
    caja(150, y, 95, h, "Backend API", ["Node 22 · Express 5", "Zod · bcrypt · JWT", "Helmet · rate-limit"])
    caja(295, y, 75, h, "Prisma ORM", ["v6.19.3", "modelo User", "→ tabla Usuario"])
    d.add(Rect(380, 4, 102, 176, rx=8, ry=8, fillColor=None, strokeColor=ROJO, strokeWidth=0.8,
               strokeDashArray=[3, 2]))
    d.add(String(431, 168, "Docker · postgres_db", fontName="Arial-Bold", fontSize=7.5,
                 fillColor=ROJO, textAnchor="middle"))
    caja(387, 92, 88, 68, "BDTyckOps", ["base real", "(solo lectura", "en las pruebas)"],
         fondo=AMBAR_CLARO, borde=colors.HexColor("#E8C98F"), tam=8.5)
    caja(387, 12, 88, 72, "BDTyckOps_pruebas", ["base aislada,", "se recarga en", "cada prueba"],
         fondo=VERDE_CLARO, borde=colors.HexColor("#A8D5B5"), tam=7.5)
    flecha(90, y + h / 2, 150, "HTTP + JWT")
    flecha(245, y + h / 2, 295, "consultas")
    flecha(370, y + h / 2, 387, "")
    d.add(String(0, 40, "Jest + Supertest → backend (en memoria y por HTTP real) → PostgreSQL",
                 fontName="Arial-Italic", fontSize=7.2, fillColor=GRIS, textAnchor="start"))
    d.add(String(0, 27, "flutter test → app completa → backend real → PostgreSQL",
                 fontName="Arial-Italic", fontSize=7.2, fillColor=GRIS, textAnchor="start"))
    return d


# ---------------------------------------------------------------- contenido
def portada():
    h = []
    h.append(Spacer(1, 3.2 * cm))
    banda = Table([[""]], colWidths=[3 * cm], rowHeights=[0.25 * cm])
    banda.setStyle(TableStyle([("BACKGROUND", (0, 0), (-1, -1), ROJO)]))
    h.append(banda)
    h.append(Spacer(1, 0.6 * cm))
    h.append(P("Reporte de pruebas de integración", "titulo"))
    h.append(Spacer(1, 0.25 * cm))
    h.append(P("TyckOps · App móvil, Backend API y Base de datos PostgreSQL", "subtitulo"))
    h.append(Spacer(1, 1.4 * cm))

    estado = "TODAS LAS PRUEBAS APROBADAS" if FALLIDAS == 0 else f"{FALLIDAS} PRUEBA(S) FALLIDA(S)"
    color = VERDE if FALLIDAS == 0 else ROJO
    kpis = Table([
        [P(str(TOTAL), "kpi_num"), P(str(OK), "kpi_num"), P(str(FALLIDAS), "kpi_num"), P("1", "kpi_num")],
        [P("pruebas ejecutadas", "kpi_txt"), P("aprobadas", "kpi_txt"), P("fallidas", "kpi_txt"),
         P("hallazgo a corregir", "kpi_txt")],
    ], colWidths=[4.1 * cm] * 4)
    kpis.setStyle(TableStyle([
        ("BOX", (0, 0), (-1, -1), 0.6, BORDE),
        ("INNERGRID", (0, 0), (-1, -1), 0.6, BORDE),
        ("BACKGROUND", (0, 0), (-1, -1), GRIS_CLARO),
        ("TOPPADDING", (0, 0), (-1, -1), 8),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 8),
    ]))
    h.append(kpis)
    h.append(Spacer(1, 0.5 * cm))
    sello = Table([[Paragraph(f'<font color="white"><b>{estado}</b></font>', E["celda_b"])]],
                  colWidths=[16.4 * cm])
    sello.setStyle(TableStyle([("BACKGROUND", (0, 0), (-1, -1), color), ("ALIGN", (0, 0), (-1, -1), "CENTER"),
                               ("TOPPADDING", (0, 0), (-1, -1), 7), ("BOTTOMPADDING", (0, 0), (-1, -1), 7)]))
    h.append(sello)
    h.append(Spacer(1, 3.5 * cm))
    ficha = [
        ["Proyecto", "TyckOps — sistema de tickets de mantenimiento (GA.MA Italy Professional)"],
        ["Fecha de ejecución", FECHA.strftime("%d-%m-%Y, %H:%M h")],
        ["Entorno", "Local (Windows 10) · Docker · PostgreSQL 15 · Node.js 22 · Flutter 3.50"],
        ["Herramientas", "Jest 29.7 + Supertest 7.1 · node:test · flutter_test"],
        ["Alcance excluido", "Pruebas desde dispositivos externos (teléfonos físicos u otros equipos)"],
    ]
    h.append(tabla(ficha, [4 * cm, 12.4 * cm], cabecera=False))
    h.append(PageBreak())
    return h


def resumen():
    h = [P("1. Resumen ejecutivo", "h1")]
    h.append(P(
        f"Se ejecutaron <b>{TOTAL} pruebas automatizadas</b> sobre el ecosistema completo de TyckOps, "
        f"en local y contra el PostgreSQL real del contenedor Docker: <b>{OK} aprobadas y {FALLIDAS} fallidas</b>. "
        "Las pruebas cubren el inicio de sesión correcto e incorrecto, todos los códigos de error de la API, "
        "el primer ingreso con y sin aceptación de Términos y Condiciones, la separación de pantallas por rol "
        "en la app móvil y la comunicación de extremo a extremo App → Backend → Base de datos."))
    h.append(P(
        "Cada prueba que modifica datos verifica además <b>lo que quedó guardado en PostgreSQL</b>, no solo la "
        "respuesta HTTP. Para no alterar la información real, esas pruebas usan una base aislada "
        "(<b>BDTyckOps_pruebas</b>) dentro del mismo servidor PostgreSQL, con las mismas migraciones que la base "
        "real; sobre la base real (<b>BDTyckOps</b>) solo se hicieron comprobaciones de lectura."))

    h.append(P("Resultado por requisito solicitado", "h2"))
    req = [["Requisito", "Cómo se verificó", "Pruebas", "Resultado"]]

    def fila(nombre, como, lista):
        ok = sum(p["ok"] for p in lista)
        tot = len(lista)
        res = "APROBADO" if ok == tot else "CON FALLAS"
        color = "#1E7B34" if ok == tot else "#B3011A"
        req.append([f"<b>{nombre}</b>", como, f"{ok}/{tot}", f'<font color="{color}"><b>{res}</b></font>'])

    login_ok = [p for p in P_JEST if p["grupo"] == "Login correcto"] + \
               [p for p in P_FL_INT if p["grupo"] in ("Login correcto",) or
                (p["suite"] == "repositorio_api_test.dart" and p["grupo"] == "Login desde la app"
                 and ("colaborador:" in p["nombre"] or "administrador:" in p["nombre"] or "normaliza" in p["nombre"]))]
    login_mal = [p for p in P_JEST if p["grupo"] == "Login incorrecto"] + \
                [p for p in P_FL_INT if p["grupo"] == "Login incorrecto" or
                 (p["grupo"] == "Login desde la app" and any(k in p["nombre"] for k in ("incorrecta", "corporativo", "rol no")))]
    errores = [p for p in P_JEST if p["suite"] == "errores.spec.js"] + \
              [p for p in P_FL_INT if p["grupo"] in ("Sesión (/auth/me)", "Errores de red")]
    primer = [p for p in P_JEST if p["suite"] == "primerAcceso.spec.js"] + \
             [p for p in P_FL_INT if p["grupo"] in ("Primer acceso y Términos", "Primer ingreso y Términos")]
    pantallas = [p for p in P_FL_INT if p["grupo"] == "Cada rol ve SOLO su pantalla"] + \
                [p for p in P_JEST if p["suite"] == "roles.spec.js"] + \
                [p for p in P_FL_UNIT if p["suite"] == "route_guard_test.dart"]
    ecosistema = [p for p in P_JEST if p["suite"] == "ecosistema.spec.js"] + P_FL_INT

    fila("Login correcto", "Colaborador y administrador inician sesión; se valida el token JWT y los datos leídos de la BD; "
         "en la app, cada uno llega a su pantalla.", login_ok)
    fila("Login incorrecto", "Clave errónea, correo inexistente, dominio no corporativo, datos vacíos o inválidos, "
         "rol no habilitado y bloqueo tras 5 intentos.", login_mal)
    fila("Errores correspondientes", "Cada código (400, 401, 403, 404, 409, 429, 503) con su código interno, mensaje "
         "y formato uniforme; la app muestra el mensaje correcto.", errores)
    fila("Primer ingreso con / sin Términos", "Usuarios nuevos van a primer acceso; sin aceptar no avanzan y la BD no "
         "cambia; al aceptar se guarda versión y fecha; cambio opcional de clave.", primer)
    fila("Pantallas por rol", "En la app, el colaborador ve solo su menú y el administrador solo el suyo; "
         "navegar a rutas del otro rol devuelve a su inicio; el backend también lo exige.", pantallas)
    fila("Ecosistema conectado", "Docker → PostgreSQL 15 → Prisma → backend real por HTTP → app Flutter, con "
         "verificación de datos en la BD.", ecosistema)
    h.append(tabla(req, [3.4 * cm, 8.8 * cm, 1.7 * cm, 2.5 * cm]))
    h.append(P("Algunas pruebas cuentan para más de un requisito (por ejemplo, las de la app también prueban el "
               "ecosistema), por eso la suma de esta tabla es mayor que el total.", "nota"))

    h.append(P("Hallazgos principales", "h2"))
    h.append(P("• <b>JSON mal formado responde 500 en vez de 400</b> (único hallazgo a corregir; detalle en la sección 7)."))
    h.append(P("• No se encontraron fallas de conectividad, de permisos por rol ni de persistencia en la base de datos."))
    h.append(P("• La API no usa códigos de la familia 300: los dos códigos de error que más se ven al probar el login "
               "son el <b>404</b> (ruta inexistente) y el <b>403</b> (sin permiso: rol de administrador o Términos "
               "no aceptados). Ambos están verificados, junto con todos los demás, en la sección 5."))
    h.append(PageBreak())
    return h


def entorno():
    h = [P("2. Entorno y arquitectura probada", "h1")]
    h.append(diagrama_ecosistema())
    h.append(P("Figura 1. Componentes del ecosistema y qué herramienta prueba cada tramo.", "nota"))
    filas = [
        ["Componente", "Versión / detalle"],
        ["Sistema operativo", "Windows 10 Pro 22H2 (10.0.19045)"],
        ["Docker", "Docker 29.9.2 · contenedor <b>postgres_db</b> (imagen postgres:15-alpine), puerto 5432"],
        ["Base de datos", "PostgreSQL 15 · bases <b>BDTyckOps</b> (real) y <b>BDTyckOps_pruebas</b> (aislada)"],
        ["ORM", "Prisma 6.19.3 (mismas migraciones en ambas bases: 5 migraciones)"],
        ["Backend", "Node.js 22.14 · Express 5 · Zod · bcryptjs 3 · jsonwebtoken 9 · Helmet · express-rate-limit"],
        ["App móvil", "Flutter 3.50.0 (stable) · Dio · go_router · flutter_secure_storage · google_fonts"],
        ["Pruebas backend", "<b>Jest 29.7.0 + Supertest 7.1.4</b> (integración) · node:test (unitarias existentes)"],
        ["Pruebas app", "flutter_test: unitarias existentes + integración contra el backend real"],
    ]
    h.append(tabla(filas, [3.6 * cm, 12.8 * cm]))

    h.append(P("Datos de prueba", "h2"))
    h.append(P("Antes de cada prueba que modifica datos, la base aislada se vacía y se recarga con este set conocido "
               "(roles, 3 departamentos, 4 categorías y 5 usuarios). Las contraseñas son ficticias y solo existen en "
               "esa base."))
    usuarios = [
        ["Usuario", "Rol en la BD", "Departamento", "Primer acceso", "Términos"],
        ["colaborador.nuevo@gamaitaly.cl", "colaborador", "RRHH", "Pendiente", "No aceptados"],
        ["admin.nuevo@gamaitaly.cl", "administrador", "Administracion", "Pendiente", "No aceptados"],
        ["colaborador.activo@gamaitaly.cl", "colaborador", "Servicios generales", "Completado", "Aceptados"],
        ["admin.activo@gamaitaly.cl", "administrador", "Administracion", "Completado", "Aceptados"],
        ["invitado@gamaitaly.cl", "invitado (no habilitado)", "RRHH", "Completado", "Aceptados"],
    ]
    h.append(tabla(usuarios, [5.4 * cm, 3.4 * cm, 3.2 * cm, 2.2 * cm, 2.2 * cm]))
    h.append(PageBreak())
    return h


def estrategia():
    h = [P("3. Estrategia y herramientas", "h1")]
    h.append(P("Se probaron las tres capas por separado y luego juntas. Las pruebas son automatizadas y repetibles: "
               "cualquier integrante del equipo puede volver a ejecutarlas con los comandos de la sección 8."))
    filas = [
        ["Nivel", "Herramienta", "Qué hace", "Pruebas"],
        ["Integración API", "<b>Jest + Supertest</b>",
         "Supertest envía peticiones HTTP a la app Express real (src/app.js), conectada por Prisma a "
         "BDTyckOps_pruebas. Jest verifica estado HTTP, cuerpo, token, auditoría y filas de la BD.",
         f"{len([p for p in P_JEST if p['suite'] != 'ecosistema.spec.js'])}"],
        ["Ecosistema", "<b>Jest + Supertest</b>",
         "Levanta el servidor como proceso real (node src/server.js) y le habla por la red; revisa Docker, "
         "versión de PostgreSQL, migraciones y que la base real coincida con el schema.",
         f"{len([p for p in P_JEST if p['suite'] == 'ecosistema.spec.js'])}"],
        ["Unitarias backend", "node:test", "Pruebas existentes del equipo (lógica de login en memoria).", f"{len(P_NODE)}"],
        ["Unitarias app", "flutter_test", "Pruebas existentes: guardia de rutas, validadores, mensajes de error.",
         f"{len(P_FL_UNIT)}"],
        ["Capa de datos app", "flutter_test",
         "Las clases reales de la app (ApiClient con Dio y ApiAuthRepository) contra el backend real.",
         f"{len([p for p in P_FL_INT if p['suite'] == 'repositorio_api_test.dart'])}"],
        ["Pantallas app", "flutter_test",
         "La app completa (TyckOpsApp con su router) se maneja como un usuario: escribe en los campos, toca "
         "botones y lee lo que aparece en pantalla, con el backend y PostgreSQL reales detrás.",
         f"{len([p for p in P_FL_INT if p['suite'] == 'pantallas_test.dart'])}"],
    ]
    h.append(tabla(filas, [2.8 * cm, 2.9 * cm, 9.2 * cm, 1.5 * cm]))

    h.append(P("Decisiones de diseño de las pruebas", "h2"))
    for t in [
        "<b>Base aislada.</b> Las pruebas que escriben datos usan BDTyckOps_pruebas, creada en el mismo servidor y "
        "con las mismas 5 migraciones. La base real BDTyckOps solo se consulta (migraciones al día, schema sin "
        "diferencias, tablas, un login fallido que no modifica nada).",
        "<b>Una app o un backend nuevo por prueba.</b> El backend limita el login a 5 intentos cada 15 minutos por "
        "IP. Para que ese límite no contamine otras pruebas, cada prueba usa una instancia nueva (y una prueba "
        "específica verifica el bloqueo).",
        "<b>Verificación en la BD.</b> Tras aceptar Términos o cambiar la clave, la prueba lee la fila en PostgreSQL "
        "(primerAcceso, terminosAceptados, versionTerminos, fechaAceptacionTerminos, hash bcrypt).",
        "<b>Pantallas con fuentes reales.</b> flutter_test dibuja el texto con una fuente de cuadrados más ancha que "
        "la real, lo que causaba un desborde falso de 81 px en la pantalla de primer acceso. Se cargó Segoe UI "
        "(medidas similares a Inter) y el desborde desapareció: no es un defecto de la app.",
        "<b>Teléfono simulado.</b> Las pantallas se prueban a 360 × 800 puntos (tamaño típico de Android).",
    ]:
        h.append(P("• " + t))
    h.append(PageBreak())
    return h


CATALOGO = [
    ("400", "DATOS_INVALIDOS", "Cuerpo vacío, correo mal formado o no corporativo, clave nueva débil", "Los datos enviados no son válidos / mensaje del campo"),
    ("400", "TERMINOS_REQUERIDOS", "Primer acceso sin aceptar Términos o con otra versión", "Debes aceptar los Términos y Condiciones vigentes."),
    ("400", "CONTRASENA_ACTUAL_INCORRECTA", "Cambio de clave con la temporal equivocada", "La contraseña temporal actual no es correcta."),
    ("400", "CONTRASENA_REPETIDA", "Clave nueva igual a la actual", "La nueva contraseña debe ser distinta de la actual."),
    ("401", "CREDENCIALES_INVALIDAS", "Clave errónea o correo inexistente (misma respuesta)", "Correo o contraseña incorrectos."),
    ("401", "NO_AUTENTICADO", "Sin encabezado Authorization o esquema distinto de Bearer", "Inicia sesión para continuar."),
    ("401", "TOKEN_INVALIDO", "Token falso, vencido o firmado con otra clave", "La sesión no es válida o expiró."),
    ("401", "SESION_INVALIDA", "Token válido de un usuario que ya no existe", "La sesión ya no es válida…"),
    ("403", "SIN_ROL_ADMIN", "Colaborador en una ruta de administrador", "Se requiere el rol de administrador."),
    ("403", "TERMINOS_NO_ACEPTADOS", "Ruta protegida sin haber aceptado Términos", "Debes aceptar los Términos y Condiciones."),
    ("403", "ROL_INVALIDO", "Login de un usuario con rol no habilitado", "La cuenta no tiene un rol habilitado."),
    ("404", "RUTA_NO_ENCONTRADA", "Ruta o método inexistente (5 casos)", "La ruta solicitada no existe."),
    ("409", "PRIMER_ACCESO_COMPLETADO", "Repetir el primer acceso", "La configuración inicial ya fue realizada."),
    ("429", "DEMASIADOS_INTENTOS", "6.º intento de login en 15 minutos", "Espera antes de volver a intentar."),
    ("503", "AUTENTICACION_NO_DISPONIBLE", "Backend sin conexión a PostgreSQL", "La base de datos aún no está conectada."),
    ("500", "ERROR_INTERNO", "JSON mal formado (HALLAZGO: debería ser 400)", "Ocurrió un error interno."),
]


def catalogo_errores():
    h = [P("4. Catálogo de códigos verificados", "h1")]
    h.append(P("Todas las respuestas de error tienen el mismo formato, verificado en cada caso: "
               "<font name='Consolas'>{\"success\": false, \"error\": {\"code\", \"message\"}}</font>. "
               "La app móvil traduce cada una a una <font name='Consolas'>ApiException</font> y muestra el "
               "<i>message</i> al usuario."))
    filas = [["HTTP", "Código interno", "Cuándo ocurre (caso probado)", "Mensaje al usuario"]]
    for http, codigo, cuando, msg in CATALOGO:
        filas.append([f"<b>{http}</b>", f"<font name='Consolas' size='7'>{codigo}</font>", cuando, msg])
    extra = [("BACKGROUND", (0, len(filas) - 1), (-1, len(filas) - 1), AMBAR_CLARO)]
    h.append(tabla(filas, [1.1 * cm, 5.2 * cm, 5.4 * cm, 4.7 * cm], estilos_extra=extra))
    h.append(P("Respuestas correctas también verificadas: <b>200</b> en login, /auth/me, primer acceso, /auth/sesion "
               "y la ruta de administrador; <b>204</b> en la verificación CORS. "
               "Sobre el código «300 y algo»: la API no responde ningún código de la familia 3xx; el que suele "
               "aparecer junto al 404 al probar el login es el <b>403</b>.", "nota"))
    h.append(PageBreak())
    return h


def detalle():
    h = [P("5. Detalle de cada prueba", "h1")]
    h.append(P("Listado completo generado desde los resultados de la ejecución. «APROBADA*» indica una prueba que pasa "
               "pero documenta un hallazgo."))

    def seccion(titulo, lista, descripcion):
        bloque = [P(titulo, "h2"), P(descripcion, "nota")]
        filas = [["#", "Grupo", "Prueba", "ms", "Resultado"]]
        for i, p in enumerate(lista, 1):
            estado = "hallazgo" if p["ok"] and "HALLAZGO" in p["nombre"] else ("ok" if p["ok"] else "x")
            filas.append([str(i), p["grupo"] or "—", p["nombre"], f"{p['ms']:.0f}", insignia(estado)])
        bloque.append(tabla(filas, [0.7 * cm, 3.6 * cm, 8.9 * cm, 1.1 * cm, 2.1 * cm]))
        return bloque

    def suite(lista, nombre):
        return [p for p in lista if p["suite"] == nombre]

    h += seccion("5.1 Backend · Login (Jest + Supertest) — login.spec.js", suite(P_JEST, "login.spec.js"),
                 "Inicio de sesión correcto e incorrecto contra PostgreSQL.")
    h += seccion("5.2 Backend · Códigos de error (Jest + Supertest) — errores.spec.js", suite(P_JEST, "errores.spec.js"),
                 "Cada código HTTP con su código interno y formato.")
    h += seccion("5.3 Backend · Primer acceso y Términos (Jest + Supertest) — primerAcceso.spec.js",
                 suite(P_JEST, "primerAcceso.spec.js"), "Respuesta HTTP y fila resultante en PostgreSQL.")
    h += seccion("5.4 Backend · Acceso por rol (Jest + Supertest) — roles.spec.js", suite(P_JEST, "roles.spec.js"),
                 "Lo que cada rol puede y no puede hacer en la API.")
    h += seccion("5.5 Ecosistema (Jest + Supertest) — ecosistema.spec.js", suite(P_JEST, "ecosistema.spec.js"),
                 "Docker, PostgreSQL, migraciones y servidor real por HTTP.")
    h += seccion("5.6 App · Capa de datos contra el backend real — repositorio_api_test.dart",
                 suite(P_FL_INT, "repositorio_api_test.dart"), "ApiClient (Dio) + ApiAuthRepository reales.")
    h += seccion("5.7 App · Pantallas de extremo a extremo — pantallas_test.dart",
                 suite(P_FL_INT, "pantallas_test.dart"), "App completa manejada como un usuario.")
    h += seccion("5.8 Pruebas unitarias existentes (regresión)", P_NODE + P_FL_UNIT,
                 "Pruebas que ya tenía el equipo; se ejecutaron para confirmar que nada se rompió.")
    h.append(PageBreak())
    return h


def pantallas():
    h = [P("6. Pantallas por rol: qué se comprobó", "h1")]
    h.append(P("La app decide qué pantalla mostrar según el rol que devuelve el servidor (nunca lo decide la app). "
               "Las pruebas inician sesión de verdad y revisan el menú inferior, que es distinto para cada rol:"))
    filas = [
        ["Situación", "Pantalla esperada", "Comprobado"],
        ["Colaborador con primer acceso completado", "Inicio del colaborador · menú: Inicio, Reportar falla, Mis solicitudes", "Sí"],
        ["Administrador con primer acceso completado", "Inicio del administrador · menú: Inicio, Tickets, Dashboard", "Sí"],
        ["Usuario nuevo (cualquier rol)", "Configuración de cuenta (Términos + contraseña); sin menús", "Sí"],
        ["Usuario nuevo intenta navegar a otra ruta", "El router lo devuelve a Configuración de cuenta", "Sí"],
        ["Usuario nuevo pulsa continuar sin marcar Términos", "Se queda; la BD no cambia", "Sí"],
        ["Usuario nuevo rechaza los Términos", "Vuelve al login con el aviso correspondiente", "Sí"],
        ["Colaborador abre rutas /admin/* (3 rutas)", "Vuelve a su inicio; nunca ve Tickets ni Dashboard", "Sí"],
        ["Administrador abre rutas /worker/* (3 rutas)", "Vuelve a su inicio; nunca ve Reportar falla", "Sí"],
        ["Cada rol recorre sus 3 pestañas", "Cada pestaña muestra su sección correcta", "Sí"],
        ["Cerrar sesión", "Vuelve al login y ya no deja entrar a pantallas internas", "Sí"],
        ["Login fallido", "Sigue en el login, muestra el mensaje y borra la clave escrita", "Sí"],
    ]
    h.append(tabla(filas, [5.8 * cm, 8.2 * cm, 2.4 * cm]))
    h.append(P("Nota: las secciones internas (Reportar falla, Mis solicitudes, Tickets, Dashboard) todavía son "
               "pantallas «en construcción» en el código de la app; se verificó que cada rol llega solo a las suyas, "
               "no su contenido futuro.", "nota"))
    return h


def hallazgos():
    h = [P("7. Hallazgos y observaciones", "h1")]
    filas = [
        ["#", "Severidad", "Descripción", "Recomendación"],
        ["1", '<font color="#8A5A00"><b>Media</b></font>',
         "Un cuerpo con JSON mal formado responde <b>500 ERROR_INTERNO</b> en vez de 400. Express ya marca el "
         "error con status 400 (<font name='Consolas'>entity.parse.failed</font>), pero "
         "<font name='Consolas'>manejarErrores</font> solo reconoce ZodError y HttpError. Además deja una traza "
         "completa en la consola del servidor.",
         "En manejarErrores.js, responder 400 DATOS_INVALIDOS cuando <font name='Consolas'>error.type === "
         "'entity.parse.failed'</font>. La prueba ya fija el comportamiento actual: al corregirlo, actualizarla a 400."],
        ["2", '<font color="#5E5E5E"><b>Informativa</b></font>',
         "El límite de 5 intentos de login cada 15 minutos es por IP. En una red corporativa donde muchos usuarios "
         "salen por la misma IP, los errores de unos podrían bloquear a otros.",
         "Evaluar limitar por IP + correo antes de producción."],
        ["3", '<font color="#5E5E5E"><b>Informativa</b></font>',
         "Un login con 401 dispara en la app el cierre de sesión local (onUnauthorized). No tiene efecto visible "
         "porque aún no hay sesión, pero mezcla «credenciales malas» con «sesión vencida».",
         "Opcional: ignorar el 401 de /auth/login en el interceptor."],
        ["4", '<font color="#5E5E5E"><b>Informativa</b></font>',
         "En las pruebas, la pantalla de primer acceso nunca termina de animarse (pumpAndSettle no se detiene): "
         "algún elemento se anima sin fin. No afecta el funcionamiento.",
         "Revisar qué elemento se anima continuamente y si es intencional."],
        ["5", '<font color="#5E5E5E"><b>Informativa</b></font>',
         "La app descarga la fuente Inter desde internet (google_fonts). Sin conexión usa la fuente del sistema.",
         "Opcional: incluir Inter como asset de la app."],
    ]
    h.append(tabla(filas, [0.7 * cm, 2.1 * cm, 7.9 * cm, 5.7 * cm]))
    h.append(Spacer(1, 6))
    h.append(P("No se modificó código del backend ni de la app para estas pruebas: los hallazgos quedan para que el "
               "equipo decida cómo corregirlos.", "nota"))
    return h


def reproducir():
    h = [P("8. Cómo volver a ejecutar las pruebas", "h1")]
    h.append(P("Requisitos: Docker con el contenedor postgres_db levantado y backend/.env configurado "
               "(ver database/INSTRUCCIONES_CONEXION.txt). La base BDTyckOps_pruebas se crea sola la primera vez."))
    for titulo, cmd in [
        ("Backend: pruebas de integración (Jest + Supertest)", "cd backend\npnpm test:integracion"),
        ("Backend: pruebas unitarias existentes", "cd backend\npnpm test"),
        ("App: pruebas unitarias existentes", "cd mobile\nflutter test"),
        ("App: integración contra el backend real (levanta el backend sola; una suite a la vez)",
         "cd mobile\nflutter test test_integracion --concurrency=1"),
        ("Regenerar este reporte", "python docs/pruebas/generar_reporte.py"),
    ]:
        h.append(P(f"<b>{titulo}</b>", "p"))
        h.append(P(cmd.replace("\n", "<br/>"), "codigo"))
    h.append(P("Archivos de pruebas creados", "h2"))
    filas = [
        ["Archivo", "Contenido"],
        ["backend/jest.config.js", "Configuración de Jest (ESM, una suite a la vez, reporte JSON)"],
        ["backend/integracion/*.spec.js", "5 suites: login, errores, primerAcceso, roles, ecosistema"],
        ["backend/integracion/helpers/", "Base de pruebas, datos de prueba, app de prueba, CLI y reporter"],
        ["mobile/test_integracion/repositorio_api_test.dart", "Capa de datos de la app contra el backend real"],
        ["mobile/test_integracion/pantallas_test.dart", "Pantallas de extremo a extremo por rol"],
        ["mobile/test_integracion/soporte/entorno.dart", "Levanta el backend, recarga datos y consulta la BD"],
        ["docs/pruebas/generar_reporte.py", "Genera este PDF desde los resultados"],
    ]
    h.append(tabla(filas, [7.2 * cm, 9.2 * cm]))
    h.append(Spacer(1, 10))
    h.append(P("9. Conclusión", "h1"))
    h.append(P(
        f"El ecosistema TyckOps funciona de extremo a extremo en local: la app móvil se comunica con el backend, el "
        f"backend con PostgreSQL en Docker, y cada acción del usuario queda correctamente guardada. Las {TOTAL} "
        f"pruebas ejecutadas {'pasaron' if FALLIDAS == 0 else 'no pasaron en su totalidad'}; el login, los códigos de "
        "error, el primer ingreso con Términos y la separación de pantallas por rol se comportan según lo esperado. "
        "Queda un hallazgo de severidad media (JSON mal formado → 500) recomendado para corregir antes de producción."))
    return h


def main():
    for ruta in (JEST, NODE_TXT, FL_UNIT, FL_INT):
        if not ruta.exists():
            sys.exit(f"Falta el archivo de resultados: {ruta}")
    SALIDA.parent.mkdir(parents=True, exist_ok=True)
    doc = SimpleDocTemplate(str(SALIDA), pagesize=A4, leftMargin=2 * cm, rightMargin=2 * cm,
                            topMargin=1.8 * cm, bottomMargin=1.8 * cm,
                            title="Reporte de pruebas de integración — TyckOps",
                            author="Equipo TyckOps", subject="Pruebas App · Backend · Base de datos")
    historia = portada() + resumen() + entorno() + estrategia() + catalogo_errores() + detalle() + \
        pantallas() + [Spacer(1, 10)] + hallazgos() + [PageBreak()] + reproducir()
    doc.build(historia, onFirstPage=decorar, onLaterPages=decorar)
    print(f"Reporte generado: {SALIDA}  ({TOTAL} pruebas, {OK} aprobadas, {FALLIDAS} fallidas)")


if __name__ == "__main__":
    main()

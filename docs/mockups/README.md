# Mockups (Google Stitch)

Cada carpeta contiene `screen.png` (referencia visual) y `code.html` (valores exactos de colores, tipografía y espaciados).
La app debe replicar estas pantallas.

## Sistemas de diseño

- `administrador/gama_professional_field_ops/DESIGN.md`
- `colaborador/italian_industrial_precision/DESIGN.md`

Ambos comparten la tipografía (Inter), la paleta base (rojo `#D7282F`, negro `#111111`, grises `#F4F4F4` / `#E5E5E5` / `#8A8A8A`) y las tarjetas (radio 16 px, borde 1 px). La app usa **un solo tema** (`mobile/lib/core/theme/`).

## Decisiones acordadas (05-11-2026)

1. **Chips de estado:** se usan los 8 colores del sistema del administrador en toda la app, uno por estado del ciclo de vida.
2. **Botones e inputs:** radio de 12 px.
3. **Barra inferior:** 3 pestañas, como en las pantallas (no las 4 del DESIGN.md).
   - Colaborador: Inicio · Reportar falla · Mis solicitudes
   - Administrador: Inicio · Tickets · Dashboard
   - Ambos roles usan el mismo indicador de pestaña activa: ícono y texto en rojo con un punto rojo debajo (sin el óvalo del mockup del administrador).
4. **Login único:** se usa `login/login_de_administrador` (trae el logo GA.MA) para ambos roles.
5. **Términos y Condiciones (T4):** se mantiene la pantalla `primer_acceso_y_seguridad_del_colaborador`, con estos ajustes:
   - "Guardar preferencias y continuar" queda deshabilitado hasta marcar la casilla de términos.
   - "Omitir por ahora" solo omite el cambio de contraseña, no los términos.
   - Se agrega el botón secundario "Rechazar términos", que cierra la sesión con un mensaje.
   - El servidor también bloquea a los usuarios que no han aceptado.

## Pantallas fuera de los requerimientos (por confirmar con el equipo)

- `administrador/crear_y_editar_trabajador`
- `administrador/detalle_y_eliminaci_n_de_trabajador`
- `administrador/historiales_tickets_de_insumos_y_reparaciones` (parte de "insumos")

## Relación pantalla → requerimiento

| Pantalla | RF | Tarea |
|---|---|---|
| login/login_de_administrador | RF-01, RF-11 adm | T3 |
| login/primer_acceso_y_seguridad_del_colaborador | RF-02, RF-03 | T3, T4 |
| colaborador/home_inicio | — | T5 |
| colaborador/reportar_una_falla, confirmaci_n_ticket_reparaci_n | RF-04 | T6 |
| colaborador/mis_solicitudes_listado, detalle_ticket_en_proceso | RF-05 | T7 |
| colaborador/detalle_ticket_rechazado | RF-07 | T7 |
| colaborador/cancelaci_n_de_ticket_y_modal, historial_de_reparaciones | RF-08, RF-09 | T8 |
| colaborador/asistencia_ia_de_diagn_stico | RF-10 a RF-12 | T9 |
| colaborador/notificaciones_push | RF-06 | T10 |
| colaborador/ticket_duplicado_mensaje_al_colaborador | RF-16 | T13 |
| administrador/inicio_del_administrador, listado_de_personal | RF-12 adm | T11 |
| administrador/generar_ticket_reparaci_n, bandeja_de_tickets_por_prioridad | RF-13, RF-15 | T12 |
| administrador/tickets_duplicados_agrupados, revisi_n_de_ticket_duplicado | RF-16 | T13 |
| administrador/detalle_de_ticket_para_el_administrador, detalle_de_ticket_propio_aprobaci_n_bloqueada, rechazar_ticket_con_motivo | RF-17 | T13 |
| administrador/dashboard_colaborativo_vista_general, comparativa_de_carga_por_rea, frecuencia_de_* | RF-18 | T14 |
| administrador/gesti_n_ia_carga_de_archivo_plano | RF-14 | T15 |

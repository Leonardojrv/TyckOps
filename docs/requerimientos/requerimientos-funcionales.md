# Requerimientos funcionales

## Ciclo de vida del ticket

Cada cambio de estado genera una notificación push al trabajador.

| Estado | Significado | Lo cambia |
|---|---|---|
| Recibido | El ticket fue enviado y aún no es revisado | Sistema (al crear) |
| En revisión | El administrador está evaluando la solicitud | Administrador |
| Aprobado | La solicitud fue aceptada | Administrador |
| Rechazado | La solicitud no procede; debe indicar el motivo | Administrador |
| En proceso | Se está ejecutando la reparación | Administrador |
| Resuelto | La falla fue solucionada | Administrador |
| Cerrado | El administrador da por finalizado y archiva el ticket | Administrador |
| Cancelado | El trabajador anuló el ticket antes de ser atendido | Trabajador |

**Flujo normal:** Recibido → En revisión → Aprobado → En proceso → Resuelto → Cerrado.
**Alternativas:** Rechazado (desde En revisión) y Cancelado (solo desde Recibido).

## Trabajador / Colaborador (app móvil)

- **RF-01.** Iniciar sesión con correo corporativo.
- **RF-02.** Cambiar opcionalmente la contraseña inicial o mantener la actual.
- **RF-03.** Revisar y aceptar o rechazar los Términos y Condiciones.
- **RF-04.** Reportar una falla (eléctrica, baños, aire acondicionado, inmobiliario) con descripción, ubicación y fotos, generando un ticket.
- **RF-05.** Ver el estado actual de cada ticket según el ciclo de vida.
- **RF-06.** Recibir notificación push cada vez que cambie el estado de un ticket.
- **RF-07.** Ver el motivo cuando un ticket sea rechazado.
- **RF-08.** Consultar el historial de solicitudes.
- **RF-09.** Cancelar un ticket mientras esté en estado Recibido.
- **RF-10.** Recibir una guía paso a paso generada por IA cuando el ticket sea de Categoría Baja.
- **RF-11.** Presionar "Cerrar ticket" en la asistencia de IA si los pasos funcionaron.
- **RF-12.** Presionar "Reportar ticket" para escalar a la bandeja del Administrador si la guía no resolvió el problema.

## Administrador (app móvil)

### Acceso y roles
- **RF-11.** Iniciar sesión con correo corporativo; el sistema verifica el rol administrador.
- **RF-12.** Navegación principal: Generar ticket de reparación, Cargar archivo plano de IA, Historial de reparaciones, Listado de personal y Dashboard operativo.

### Gestión de tickets y control operativo
- **RF-13.** Crear tickets manualmente con los mismos parámetros del colaborador.
- **RF-14.** Cargar un archivo plano (.csv, .json, .txt) con directrices para la IA de tickets de categoría baja.
- **RF-15.** Ver una bandeja de tickets ordenada por prioridad y criticidad.
- **RF-16.** Detección automática de duplicados por ubicación y descripción, agrupados para unificar o rechazar.
- **RF-17.** Aprobar, rechazar y cerrar tickets; el motivo es obligatorio al rechazar.

### Dashboard analítico
- **RF-18.** Dashboard operativo segmentado:
  - a) Comparativa global entre incidentes menores (categoría baja) y fallas reales.
  - b) Frecuencia temporal de incidentes menores y tasa de resolución por IA.
  - c) Frecuencia de fallas reales por prioridad (Urgente, Alta, Normal).
  - d) Carga operativa por las 8 áreas: Control de Gestión, Tesorería, Contabilidad, Marketing, Ventas Masivo, Educación, Recursos Humanos y Gerencia.

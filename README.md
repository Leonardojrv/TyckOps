# TyckOps · GA.MA Servicios Generales

Sistema de tickets para reportar fallas (eléctricas, baños, aire acondicionado e inmobiliario) con dos roles: **Colaborador** y **Administrador**. Incluye asistencia por IA para incidencias menores (categoría baja) y un dashboard operativo.

## Equipo

| Integrante | Responsabilidad | Carpeta |
|---|---|---|
| Maximiliano Navarrete | App móvil Flutter (ambos roles) | `mobile/` |
| Moisés Marín | Backend e implementación de IA | `backend/` |
| Leonardo Remires | Base de datos PostgreSQL | `database/` |

## Stack

- **App móvil:** Flutter (Android e iOS), fl_chart, Firebase Messaging
- **Backend:** Node.js + Express/Fastify, Prisma, Socket.IO
- **Base de datos:** PostgreSQL
- **Infraestructura:** Docker Compose

## Estructura

```
gama-servicios-generales/
├── docs/       # documentación (requerimientos, mockups, API, gestión)
├── mobile/     # app Flutter
├── backend/    # API, IA y servidor
└── database/   # PostgreSQL y modelo de datos
```

## Metodología

Scrumban. Máximo 2 tarjetas en proceso por persona.

**Definición de "Hecho":** probado en Android, subido al repositorio y sin errores conocidos.

## Ramas

- `main`: versión estable. No se trabaja directo aquí.
- Una rama por tarjeta: `feature/T2-base-app`, `feature/T3-login`, etc.

## Cómo levantarlo

_Se completará cuando cada parte esté lista (app, backend y base de datos)._

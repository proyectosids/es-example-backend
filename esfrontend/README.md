# esfrontend

Base Flutter mobile para Escuela Sabatica conectado al backend `ES_ULV_BACKEND`.

## Flujo implementado

1. Trimestres con imagen (`/api/v1/quarterlies`)
2. Lecciones del trimestre (normalizadas a 13) (`/api/v1/quarterlies/:id/lessons`)
3. Semana/Dias de la leccion (`/api/v1/quarterlies/:id/lessons/:lessonId/days`)
4. Lectura diaria (`/api/v1/quarterlies/:id/lessons/:lessonId/days/:dayId/read`)

## Modo offline real

- Persistencia local con `sqflite`:
  - `quarterlies`
  - `lessons`
  - `days`
  - `day_reads`
  - `sync_state`
- Primer acceso por trimestre:
  - descarga completa con `GET /api/v1/sync/bulk?lang=es&quarterlyId=...`
- Sincronizacion incremental:
  - consulta `GET /api/v1/sync/changes?lang=es&since=...`
  - actualiza solo dias cambiados en local.
- Lectura local-first:
  - la app siempre intenta mostrar cache local antes de red.

## Render de lectura

- `readJson` se renderiza de forma enriquecida:
  - HTML (`p`, `h1-h3`, `blockquote`, listas).
  - Secciones y bloques anidados.
  - Listas/versiculos en formato legible.
- Incluye fallback con JSON original (expandible) para depuracion.

## Configuracion API

Por defecto usa:

`http://10.0.2.2:3000/api/v1`

Puedes cambiarla al correr:

```bash
flutter run --dart-define=API_BASE_URL=http://TU_IP_LOCAL:3000/api/v1
```

## Estructura

- `lib/core`: config y cliente HTTP
- `lib/features/catalog/data`: modelos y repositorio
- `lib/features/catalog/presentation`: providers y pantallas

## Comandos

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

## Bitacora tecnica (RBAC)

Ver [`docs/frontend_integration_log.md`](docs/frontend_integration_log.md) para el historial de integracion con backend (Fase 1, 2 y 3).

# Frontend Integration Log (Backend RBAC)

## Contexto
Proyecto Flutter activo: `ES_ULV_BACKEND/esfrontend`.
Objetivo: integrar autenticacion/autorizacion RBAC del backend sin romper flujo offline-first de lectura.

## Fase 1 (completada)
- Login JWT (`/auth/login`) y refresh (`/auth/refresh`).
- Persistencia segura con `flutter_secure_storage`.
- `SessionProvider` con estados `loading/guest/authenticated`.
- Interceptor Dio:
  - inyeccion `Authorization: Bearer`.
  - refresh automatico ante `401`.
  - cierre de sesion si refresh falla.
- UI minima de cuenta/login (icono perfil en Home).

Archivos principales:
- `lib/core/network/api_client.dart`
- `lib/core/storage/token_storage.dart`
- `lib/features/auth/**`
- `lib/features/catalog/presentation/providers/catalog_providers.dart`
- `lib/features/catalog/presentation/screens/quarterlies_screen.dart`

## Fase 2 (completada)
- Consumo de contexto de usuario:
  - `GET /me`
  - `GET /me/permissions`
  - `GET /me/screens`
- `SessionState` expandido con:
  - `profile` (usuario, memberships, roleAssignments)
  - `accessContext` (permissions, screens, orgUnitId)
- Hidratacion de contexto en:
  - inicio de app (sesion existente)
  - login exitoso
  - refresh de token
- Fallback seguro: si falla carga de contexto, se mantiene sesion activa.

## Fase 3 (completada)
- Capa de guardas por permisos y pantallas:
  - `hasPermissionProvider(permissionCode)`
  - `canOpenScreenProvider(screenKey)`
- Guardas aplicadas en UI actual:
  - Home -> navegar a lecciones (`mobile.lessons`).
  - Trimestre -> abrir lector semanal (`mobile.lesson_reader`).
  - Botones de descarga/sync en Trimestre visibles solo con `app.sync.execute`.
- Pantalla de cuenta muestra contexto cargado y boton manual de `Actualizar contexto`.

Archivo principal de guardas:
- `lib/features/auth/presentation/access/access_control.dart`

## Criterios de no regresion respetados
- No se altero el pipeline de lectura HTML/versiculos/preguntas.
- No se altero la persistencia offline de catalogo.
- Navegacion base se mantiene funcional para modo invitado (fallback).

## Fase 4 (completada)
- Selector de `orgUnitId` activo en sesion (pantalla de cuenta).
- Persistencia de alcance seleccionado en secure storage:
  - key: `auth_selected_org_unit_id`.
- Recalculo de contexto al cambiar alcance:
  - vuelve a consultar `/me/permissions?orgUnitId=...`
  - vuelve a consultar `/me/screens?orgUnitId=...`
- Validacion de alcance seleccionado:
  - si el `orgUnitId` guardado ya no existe en memberships, se aplica fallback al org primario.
- Se mantiene fallback de no-regresion:
  - sin sesion: modo invitado en pantallas de estudio.

## Fase 5 (completada)
- Persistencia local de contexto de sesion para compatibilidad offline:
  - `profile` cacheado en secure storage (`auth_profile_json`).
  - `accessContext` cacheado en secure storage (`auth_access_context_json`).
  - alcance seleccionado persistido (`auth_selected_org_unit_id`).
- Arranque offline:
  - si hay sesion valida, la app monta inmediatamente con cache local de perfil/permisos/pantallas.
  - luego intenta refrescar contra backend en background.
- Compatibilidad de refresh token en red inestable:
  - no se cierra sesion por errores de red al refrescar token.
  - solo se cierra sesion cuando refresh devuelve `401/403` (token invalido/expirado).
- Mensaje de estado:
  - cuando no hay conexion durante hidratacion, se mantiene contexto local y se muestra aviso.

## Fase 6 (completada)
- Nuevas pantallas administrativas implementadas en frontend:
  - `admin.users`
  - `admin.roles`
  - `admin.org_structure`
  - `admin.reports`
- Se creo `Panel administrativo` como entrada unica desde pantalla Cuenta.
- Activacion condicional por `me/screens`:
  - solo se muestran las opciones cuyo `screenKey` esta habilitado en `accessContext.screens`.
- Repositorio admin integrado con backend actual:
  - `GET /users?orgUnitId=...`
  - `GET /roles`
  - `GET /org-units?...`
- Pantallas de lectura existentes permanecen sin cambios funcionales.

## Fase 6.1 (completada)
- Acciones administrativas reales agregadas:
  - Crear usuario (`POST /users`) en `admin.users`.
  - Asignar rol a usuario (`POST /users/:userId/roles`) en `admin.users`.
  - Editar unidad organizacional (`PATCH /org-units/:orgUnitId`) en `admin.org_structure`.
- Guardas por permiso aplicadas en UI:
  - Crear usuario visible solo con `app.users.manage`.
  - Asignar rol visible solo con `app.roles.assign`.
  - Editar org unit visible solo con `app.org.manage`.
- Las pantallas siguen condicionadas por `me/screens` (Fase 6).

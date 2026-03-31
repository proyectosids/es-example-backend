# Diseño técnico backend (Auth + RBAC + Scope)

## Objetivo
Implementar autenticación y autorización multi-tenant para la estructura:
`Asociación General -> División -> Unión -> Asociación/Misión -> Distrito -> Iglesia -> Grupo Pequeño`

## Base de datos (ya agregado en `query_bd_es.sql`)
- `Tenants`
- `OrgUnitTypes`
- `OrgUnits`
- `OrgUnitClosure`
- `Users`
- `Roles`
- `Permissions`
- `RolePermissions`
- `Screens`
- `ScreenPermissions`
- `UserRoleAssignments`
- `UserOrgMemberships`
- vista `vwUserEffectivePermissions`

## Reglas clave
1. **Todo usuario pertenece a un `tenant`.**
2. **Roles tienen alcance (`ScopeOrgUnitId`).**
3. El permiso asignado en un nodo aplica a **todos sus descendientes** (usando `OrgUnitClosure`).
4. El **miembro de iglesia** debe tener permisos de lectura del catálogo + marcar estudio (`app.catalog.read`, `app.study_marks.write`).

## Endpoints recomendados (fase 1)

### Auth
- `POST /api/v1/auth/login`
  - entrada: `tenantCode`, `email`, `password`
  - salida: `accessToken`, `refreshToken`, `user`, `tenant`
- `POST /api/v1/auth/refresh`
- `POST /api/v1/auth/logout`

### Perfil
- `GET /api/v1/me`
- `GET /api/v1/me/permissions?orgUnitId=...`
- `GET /api/v1/me/screens?orgUnitId=...`

### Organización
- `GET /api/v1/org-units?type=&parentId=`
- `POST /api/v1/org-units`
- `PATCH /api/v1/org-units/:id`

### Usuarios y roles
- `GET /api/v1/users?orgUnitId=`
- `POST /api/v1/users`
- `POST /api/v1/users/:id/roles`
  - body: `roleCode`, `scopeOrgUnitId`, `validFrom`, `validTo`
- `DELETE /api/v1/user-role-assignments/:id`

### Catálogo (existente)
- mantener endpoints actuales.
- proteger con permiso `app.catalog.read` en rutas privadas.

## Middleware recomendado

## 1) `authMiddleware`
- valida JWT
- inyecta `req.auth = { userId, tenantId }`

## 2) `requirePermission(permissionCode, scopeResolver)`
- obtiene `tenantId/userId` del token
- resuelve `orgUnitId` por request (params/query/body)
- verifica en `vwUserEffectivePermissions`:
  - `TenantId = tenantId`
  - `UserId = userId`
  - `PermissionCode = permissionCode`
  - `EffectiveOrgUnitId = orgUnitId`
- si no existe: `403`

## 3) `requireScreen(screenKey, scopeResolver)` (opcional)
- traduce `screenKey` -> permisos mínimos desde `ScreenPermissions`
- exige todos o al menos uno (según estrategia definida)

## Repositorios nuevos sugeridos
- `src/repos/auth.repo.js`
- `src/repos/users.repo.js`
- `src/repos/orgUnits.repo.js`
- `src/repos/roles.repo.js`
- `src/repos/permissions.repo.js`

## Rutas nuevas sugeridas
- `src/routes/auth.routes.js`
- `src/routes/users.routes.js`
- `src/routes/org.routes.js`
- `src/routes/roles.routes.js`

## Notas de implementación
1. Para password hash usar `bcrypt`.
2. Para JWT usar `access(15m)` + `refresh(7d-30d)`.
3. Guardar `EmailNormalized` en mayúsculas.
4. Mantener `tenantId` en todas las consultas de seguridad.
5. Para consistencia, cuando se crea/mueve un `OrgUnit`, recalcular `OrgUnitClosure`.

## Fase 2 (cuando conectes grupos e iglesia)
- métricas por grupo/iglesia/distrito.
- tablero escalonado hasta Asociación General.
- sincronización de `study_marks` por usuario y alcance.

## Documento complementario (flujo SaaS membresias y gobierno de roles)
- Ver: `src/db/scritp_db/saas_member_lifecycle_design.md`
- Incluye:
  - tablas nuevas (`RoleAssignmentRules`, `SmallGroupMemberships`, `QuarterlyMembershipPolicy` opcional),
  - endpoints publicos de registro miembro,
  - endpoints de aprobacion de grupos,
  - endpoints de gobierno de roles por nivel organizacional,
  - roadmap por fases sin ruptura.

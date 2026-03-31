# Diseño técnico SaaS: Registro de miembros + Gobierno de roles por jerarquía

## 1) Objetivo
Implementar el flujo organizacional real sin romper lo actual:

- Miembro se registra desde app como `CHURCH_MEMBER` (sin pedir toda la jerarquía global).
- `PASTOR` (scope iglesia) puede crear/asignar solo Director ES de iglesia.
- Director ES de iglesia puede asignar líderes de grupo pequeño entre miembros de su iglesia.
- Miembro puede solicitar cambio de grupo pequeño por trimestre.
- Una vez aprobado en el trimestre actual, no puede cambiar hasta el siguiente trimestre.

Compatibilidad: el backend y frontend actuales (catálogo/lectura/offline) se mantienen.

---

## 2) Reglas de negocio exactas

1. Registro de miembro (self-service)
- Rol por defecto: `CHURCH_MEMBER`.
- Scope por defecto del rol: `CHURCH` seleccionada.
- Puede elegir grupo pequeño al registrarse, pero entra como `PENDING` (requiere aprobación del líder).

2. Jerarquía visible para registro
- El miembro solo navega: `UNION -> FIELD (Asociación/Misión) -> DISTRICT -> CHURCH -> SMALL_GROUP`.
- No se solicita División ni Asociación General en UI de registro.

3. Gobierno de altas administrativas
- Asociación/Misión (FIELD director) da de alta `PASTOR` de iglesias en su alcance.
- `PASTOR` da de alta/asigna `CHURCH_SABBATH_DIRECTOR` en su iglesia.
- `CHURCH_SABBATH_DIRECTOR` asigna `SMALL_GROUP_LEADER` dentro de su iglesia.

4. Cambio de grupo por trimestre
- Máximo una membresía `APPROVED` por usuario y trimestre.
- Si ya tiene `APPROVED` en trimestre actual, no puede cambiar hasta el siguiente.
- Si hay solicitud `PENDING`, no se permite una nueva solicitud para el mismo trimestre.

---

## 3) Tablas nuevas (SQL Server, aditivas)

## 3.1 `RoleAssignmentRules`
Regla explícita de quién puede asignar qué rol y en qué alcance.

```sql
CREATE TABLE dbo.RoleAssignmentRules (
  RoleAssignmentRuleId   UNIQUEIDENTIFIER NOT NULL
    CONSTRAINT DF_RoleAssignmentRules_Id DEFAULT NEWSEQUENTIALID(),
  AssignerRoleCode       NVARCHAR(80) NOT NULL,
  AssignableRoleCode     NVARCHAR(80) NOT NULL,
  ScopeOrgUnitTypeCode   NVARCHAR(40) NOT NULL, -- CHURCH / SMALL_GROUP / ...
  RequiresSameChurch     BIT NOT NULL CONSTRAINT DF_RoleAssignmentRules_SameChurch DEFAULT 0,
  IsActive               BIT NOT NULL CONSTRAINT DF_RoleAssignmentRules_IsActive DEFAULT 1,
  CreatedAt              DATETIME2 NOT NULL CONSTRAINT DF_RoleAssignmentRules_CreatedAt DEFAULT SYSUTCDATETIME(),
  CONSTRAINT PK_RoleAssignmentRules PRIMARY KEY (RoleAssignmentRuleId),
  CONSTRAINT FK_RoleAssignmentRules_AssignerRole FOREIGN KEY (AssignerRoleCode) REFERENCES dbo.Roles(Code),
  CONSTRAINT FK_RoleAssignmentRules_AssignableRole FOREIGN KEY (AssignableRoleCode) REFERENCES dbo.Roles(Code),
  CONSTRAINT FK_RoleAssignmentRules_ScopeType FOREIGN KEY (ScopeOrgUnitTypeCode) REFERENCES dbo.OrgUnitTypes(OrgUnitTypeCode),
  CONSTRAINT UQ_RoleAssignmentRules UNIQUE (AssignerRoleCode, AssignableRoleCode, ScopeOrgUnitTypeCode)
);
```

Seed mínimo recomendado:

```sql
INSERT INTO dbo.RoleAssignmentRules (AssignerRoleCode, AssignableRoleCode, ScopeOrgUnitTypeCode, RequiresSameChurch)
VALUES
('FIELD_SABBATH_DIRECTOR', 'PASTOR', 'CHURCH', 0),
('PASTOR', 'CHURCH_SABBATH_DIRECTOR', 'CHURCH', 1),
('CHURCH_SABBATH_DIRECTOR', 'SMALL_GROUP_LEADER', 'SMALL_GROUP', 1);
```

## 3.2 `SmallGroupMemberships`
Workflow + estado efectivo por trimestre.

```sql
CREATE TABLE dbo.SmallGroupMemberships (
  SmallGroupMembershipId UNIQUEIDENTIFIER NOT NULL
    CONSTRAINT DF_SmallGroupMemberships_Id DEFAULT NEWSEQUENTIALID(),
  TenantId               UNIQUEIDENTIFIER NOT NULL,
  UserId                 UNIQUEIDENTIFIER NOT NULL,
  ChurchOrgUnitId        UNIQUEIDENTIFIER NOT NULL,
  SmallGroupOrgUnitId    UNIQUEIDENTIFIER NOT NULL,
  QuarterlyId            NVARCHAR(30) NOT NULL, -- ejemplo: 2026-02
  Status                 NVARCHAR(20) NOT NULL, -- PENDING|APPROVED|REJECTED|CANCELLED
  RequestedByUserId      UNIQUEIDENTIFIER NOT NULL,
  ApprovedByUserId       UNIQUEIDENTIFIER NULL,
  RequestedAt            DATETIME2 NOT NULL CONSTRAINT DF_SGM_RequestedAt DEFAULT SYSUTCDATETIME(),
  DecidedAt              DATETIME2 NULL,
  Notes                  NVARCHAR(500) NULL,
  IsActive               BIT NOT NULL CONSTRAINT DF_SGM_IsActive DEFAULT 1,
  CONSTRAINT PK_SmallGroupMemberships PRIMARY KEY (SmallGroupMembershipId),
  CONSTRAINT FK_SGM_Tenant FOREIGN KEY (TenantId) REFERENCES dbo.Tenants(TenantId),
  CONSTRAINT FK_SGM_User FOREIGN KEY (UserId) REFERENCES dbo.Users(UserId),
  CONSTRAINT FK_SGM_Church FOREIGN KEY (ChurchOrgUnitId) REFERENCES dbo.OrgUnits(OrgUnitId),
  CONSTRAINT FK_SGM_SmallGroup FOREIGN KEY (SmallGroupOrgUnitId) REFERENCES dbo.OrgUnits(OrgUnitId),
  CONSTRAINT FK_SGM_RequestedBy FOREIGN KEY (RequestedByUserId) REFERENCES dbo.Users(UserId),
  CONSTRAINT FK_SGM_ApprovedBy FOREIGN KEY (ApprovedByUserId) REFERENCES dbo.Users(UserId),
  CONSTRAINT CK_SGM_Status CHECK (Status IN ('PENDING','APPROVED','REJECTED','CANCELLED'))
);

CREATE INDEX IX_SGM_UserQuarter ON dbo.SmallGroupMemberships(TenantId, UserId, QuarterlyId, Status, IsActive);
CREATE INDEX IX_SGM_GroupQuarter ON dbo.SmallGroupMemberships(TenantId, SmallGroupOrgUnitId, QuarterlyId, Status, IsActive);

CREATE UNIQUE INDEX UX_SGM_OneActiveApprovedPerQuarter
ON dbo.SmallGroupMemberships(TenantId, UserId, QuarterlyId)
WHERE IsActive=1 AND Status='APPROVED';

CREATE UNIQUE INDEX UX_SGM_OneActivePendingPerQuarter
ON dbo.SmallGroupMemberships(TenantId, UserId, QuarterlyId)
WHERE IsActive=1 AND Status='PENDING';
```

## 3.3 `QuarterlyMembershipPolicy` (opcional, recomendado)
Controla ventanas de cambio por trimestre (si se requiere fecha límite).

```sql
CREATE TABLE dbo.QuarterlyMembershipPolicy (
  TenantId                 UNIQUEIDENTIFIER NOT NULL,
  QuarterlyId              NVARCHAR(30) NOT NULL,
  ChangeOpenAt             DATETIME2 NULL,
  ChangeCloseAt            DATETIME2 NULL,
  RequireLeaderApproval    BIT NOT NULL CONSTRAINT DF_QMP_RequireApproval DEFAULT 1,
  CreatedAt                DATETIME2 NOT NULL CONSTRAINT DF_QMP_CreatedAt DEFAULT SYSUTCDATETIME(),
  UpdatedAt                DATETIME2 NOT NULL CONSTRAINT DF_QMP_UpdatedAt DEFAULT SYSUTCDATETIME(),
  CONSTRAINT PK_QuarterlyMembershipPolicy PRIMARY KEY (TenantId, QuarterlyId),
  CONSTRAINT FK_QMP_Tenant FOREIGN KEY (TenantId) REFERENCES dbo.Tenants(TenantId)
);
```

---

## 4) Endpoints nuevos (contrato exacto)

## 4.1 Público: discovery de estructura para registro

### `GET /api/v1/public/org/unions?tenantCode=...`
- retorna solo org units de tipo `UNION`.

### `GET /api/v1/public/org/fields?unionId=...`
- retorna `FIELD` hijos de esa unión.

### `GET /api/v1/public/org/districts?fieldId=...`
- retorna `DISTRICT` hijos.

### `GET /api/v1/public/org/churches?districtId=...`
- retorna `CHURCH` hijas.

### `GET /api/v1/public/org/small-groups?churchId=...`
- retorna `SMALL_GROUP` del church.

Nota: validar pertenencia por `TenantId` en todos.

## 4.2 Público: registro de miembro

### `POST /api/v1/public/auth/register-member`
Body:
```json
{
  "tenantCode": "ulv-demo",
  "email": "nuevo@demo.local",
  "password": "Secret123!",
  "firstName": "Nombre",
  "lastName": "Apellido",
  "displayName": "Nombre Apellido",
  "unionOrgUnitId": "...",
  "fieldOrgUnitId": "...",
  "districtOrgUnitId": "...",
  "churchOrgUnitId": "...",
  "smallGroupOrgUnitId": "..."
}
```
Reglas server:
- validar cadena jerárquica completa (`smallGroup -> church -> district -> field -> union`).
- crear `Users`.
- crear `UserOrgMemberships` en iglesia (MEMBER, IsPrimary=1).
- crear `UserRoleAssignments` con `CHURCH_MEMBER` scope iglesia.
- si viene grupo pequeño, insertar `SmallGroupMemberships` con `PENDING`.

Respuesta:
```json
{
  "userId": "...",
  "status": "REGISTERED",
  "smallGroupRequestStatus": "PENDING"
}
```

## 4.3 Miembro autenticado

### `GET /api/v1/me/small-group-membership?quarterlyId=2026-02`
- devuelve estado actual (`PENDING/APPROVED/REJECTED/...`).

### `POST /api/v1/me/small-group-change-requests`
Body:
```json
{
  "quarterlyId": "2026-02",
  "smallGroupOrgUnitId": "..."
}
```
Reglas:
- si existe `APPROVED` en ese trimestre -> `409`.
- si existe `PENDING` en ese trimestre -> `409`.
- validar que grupo pertenece a su iglesia.
- crear `SmallGroupMemberships` en `PENDING`.

## 4.4 Líder de grupo / Director / Pastor (aprobación)

### `GET /api/v1/small-groups/:smallGroupId/membership-requests?quarterlyId=...`
Permisos: `app.group.members.manage` y alcance sobre ese `smallGroupId`.

### `POST /api/v1/small-groups/:smallGroupId/membership-requests/:requestId/approve`
### `POST /api/v1/small-groups/:smallGroupId/membership-requests/:requestId/reject`
- actualiza status y metadatos de aprobación.

## 4.5 Gobierno de roles por flujo organizacional

### `POST /api/v1/church-admin/sabbath-directors`
- Actor requerido: `PASTOR` con scope iglesia + `app.users.manage`.
- Crea usuario (si no existe) y asigna rol `CHURCH_SABBATH_DIRECTOR` en esa iglesia.

### `POST /api/v1/church-admin/small-group-leaders`
- Actor requerido: `CHURCH_SABBATH_DIRECTOR` + `app.roles.assign`.
- Body: `userId`, `smallGroupOrgUnitId`, `validFrom`, `validTo`.
- Valida que usuario pertenezca a esa iglesia.
- Asigna `SMALL_GROUP_LEADER` en ese grupo.

### `POST /api/v1/field-admin/pastors`
- Actor requerido: rol de alcance `FIELD_*` con permiso `app.users.manage`.
- Crea/asigna `PASTOR` en iglesia del field.

---

## 5) Guardas de seguridad (backend)

1. Mantener `requirePermission(...)` actual.
2. Añadir validador de flujo de asignación:
- consulta `RoleAssignmentRules`.
- verifica coincidencia de scope (`ScopeOrgUnitTypeCode`).
- verifica `RequiresSameChurch` cuando aplique.
3. Bloquear uso de endpoint genérico de asignación para roles sensibles cuando no cumpla regla.

---

## 6) Cambios en frontend (incrementales, no ruptura)

## Fase FE-A
- Pantalla de registro miembro con cascada:
  - Unión -> Asociación/Misión -> Distrito -> Iglesia -> Grupo.
- Registro crea usuario member sin pedir División/AG.

## Fase FE-B
- Pantalla "Mi grupo pequeño" (estado por trimestre):
  - ver estado actual.
  - solicitar cambio cuando corresponda.

## Fase FE-C
- Vistas de aprobación para líder/director/pastor según permisos y pantallas.

---

## 7) Fases de implementación (backend)

## Fase BE-1 (aditiva)
- Migraciones: `RoleAssignmentRules`, `SmallGroupMemberships`, opcional `QuarterlyMembershipPolicy`.
- Seed de reglas de asignación.

## Fase BE-2
- Endpoints públicos de discovery + `register-member`.
- Pruebas de validación jerárquica.

## Fase BE-3
- Endpoints miembro para solicitud de cambio por trimestre.
- Endpoints de aprobación por líder/director.

## Fase BE-4
- Endpoints específicos de gobierno de roles (`field-admin/pastors`, `church-admin/...`).
- Hardening: auditoría y validaciones cruzadas.

## Fase BE-5
- Integración frontend + pruebas E2E por rol.

---

## 8) No ruptura (criterios)

- No eliminar ni renombrar endpoints existentes.
- Nuevas tablas son aditivas.
- Reglas nuevas se aplican a endpoints nuevos; los antiguos se endurecen con feature flag gradual.
- Catálogo de estudio y offline actual permanece intacto.

---

## 9) Feature flags recomendados

- `FF_MEMBER_SELF_REGISTER`
- `FF_GROUP_APPROVAL_FLOW`
- `FF_ROLE_GOVERNANCE_RULES`
- `FF_CHURCH_ADMIN_ENDPOINTS`

Permite activar por tenant sin afectar operación actual.

---

## 10) Estado actual implementado (2026-03-27)

Implementado:

- Migración BE-1 aditiva:
  - `src/db/scritp_db/migration_be1_saas_member_lifecycle.sql`
  - tablas: `RoleAssignmentRules`, `SmallGroupMemberships`, `QuarterlyMembershipPolicy`
  - seed base de reglas de asignación.
- Endpoints públicos de estructura:
  - `GET /api/v1/public/org/unions?tenantCode=...`
  - `GET /api/v1/public/org/fields?tenantCode=...&unionId=...`
  - `GET /api/v1/public/org/districts?tenantCode=...&fieldId=...`
  - `GET /api/v1/public/org/churches?tenantCode=...&districtId=...`
  - `GET /api/v1/public/org/small-groups?tenantCode=...&churchId=...`
- Registro de miembro:
  - `POST /api/v1/public/auth/register-member`
  - alta de `CHURCH_MEMBER` + membresía primaria iglesia.
  - solicitud `PENDING` de grupo pequeño opcional.
- Flujo de grupo pequeño autenticado:
  - `GET /api/v1/me/small-group-membership`
  - `POST /api/v1/me/small-group-change-requests`
  - `GET /api/v1/small-groups/:smallGroupId/membership-requests`
  - `POST /api/v1/small-groups/:smallGroupId/membership-requests/:requestId/approve`
  - `POST /api/v1/small-groups/:smallGroupId/membership-requests/:requestId/reject`
- Gobierno de asignaciones aplicado al flujo genérico:
  - `POST /api/v1/users`
  - `POST /api/v1/users/:userId/roles`
  - cuando hay regla activa en `RoleAssignmentRules`, se valida antes de asignar.

Pendiente siguiente fase:

- Aplicación operativa de ventanas por trimestre (`QuarterlyMembershipPolicy`).

Actualización BE-2 (implementado):

- Endpoints especializados habilitados:
  - `POST /api/v1/field-admin/pastors`
    - requiere `app.users.manage` sobre iglesia objetivo.
    - actor debe tener `FIELD_SABBATH_DIRECTOR` con alcance efectivo sobre esa iglesia.
    - asignación sujeta a `RoleAssignmentRules`.
  - `POST /api/v1/church-admin/sabbath-directors`
    - requiere `app.users.manage` sobre iglesia objetivo.
    - actor debe tener `PASTOR` en esa iglesia.
    - asignación sujeta a `RoleAssignmentRules`.
  - `POST /api/v1/church-admin/small-group-leaders`
    - requiere `app.roles.assign` sobre grupo pequeño objetivo.
    - actor debe tener `CHURCH_SABBATH_DIRECTOR` con alcance efectivo sobre ese grupo.
    - valida que el usuario objetivo pertenezca a la iglesia dueña del grupo.
    - asignación sujeta a `RoleAssignmentRules`.

Actualización Paso 2 / Política trimestral (implementado):

- Enforcement de `QuarterlyMembershipPolicy` en:
  - `POST /api/v1/me/small-group-change-requests`
  - `GET /api/v1/me/small-group-membership`
- Reglas aplicadas:
  - si no existe política configurada, la ventana se considera abierta
  - si `ChangeOpenAt` es futura, el cambio responde `422`
  - si `ChangeCloseAt` ya venció, el cambio responde `422`
  - si la política está abierta y `RequireLeaderApproval=true`, la solicitud crea membresía `PENDING`
  - si la política está abierta y `RequireLeaderApproval=false`, la solicitud crea membresía `APPROVED`
- Endpoints administrativos agregados:
  - `GET /api/v1/admin/quarterly-membership-policy/:quarterlyId`
  - `PUT /api/v1/admin/quarterly-membership-policy/:quarterlyId`

Actualización Paso 3 / Auditoría mínima (implementado):

- Tabla aditiva agregada:
  - `dbo.AuditEvents`
- Escritura de auditoría integrada para eventos críticos:
  - `ADMIN_USER_CREATED`
  - `ROLE_ASSIGNED`
  - `SMALL_GROUP_MEMBERSHIP_APPROVED`
  - `SMALL_GROUP_MEMBERSHIP_REJECTED`
- Endpoints instrumentados:
  - `POST /api/v1/users`
  - `POST /api/v1/users/:userId/roles`
  - `POST /api/v1/field-admin/pastors`
  - `POST /api/v1/church-admin/sabbath-directors`
  - `POST /api/v1/church-admin/small-group-leaders`
  - `POST /api/v1/small-groups/:smallGroupId/membership-requests/:requestId/approve`
  - `POST /api/v1/small-groups/:smallGroupId/membership-requests/:requestId/reject`
- Estrategia:
  - la auditoría es `best effort`
  - si falla la escritura de auditoría, no rompe la operación principal

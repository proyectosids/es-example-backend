-- =========================================
-- 1) META DE RECURSOS DEL SOURCE (ETag/Last-Modified)
-- =========================================
CREATE TABLE dbo.SourceResources (
  ResourceKey     NVARCHAR(300) NOT NULL PRIMARY KEY, -- ej: es/quarterlies/2026-01/index.json
  Url             NVARCHAR(700) NOT NULL,
  ETag            NVARCHAR(120) NULL,
  LastModified    NVARCHAR(120) NULL,
  ContentHash     VARBINARY(32) NULL,
  UpdatedAt       DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);

-- =========================================
-- 2) CONTENIDO CACHEADO (Quarterly/Lesson/DayRead/Media)
-- =========================================
CREATE TABLE dbo.Quarterlies (
  Lang          NVARCHAR(10) NOT NULL,
  QuarterlyId   NVARCHAR(30) NOT NULL, -- ej: 2026-01
  Title         NVARCHAR(250) NULL,
  CoverUrl      NVARCHAR(600) NULL,
  StartDate     DATE NULL,
  EndDate       DATE NULL,
  RawJson       NVARCHAR(MAX) NULL,
  UpdatedAt     DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
  CONSTRAINT PK_Quarterlies PRIMARY KEY (Lang, QuarterlyId)
);

CREATE TABLE dbo.Lessons (
  Lang        NVARCHAR(10) NOT NULL,
  QuarterlyId NVARCHAR(30) NOT NULL,
  LessonId    NVARCHAR(10) NOT NULL,  -- "01".."13"
  Title       NVARCHAR(250) NULL,
  StartDate   DATE NULL,
  EndDate     DATE NULL,
  RawJson     NVARCHAR(MAX) NULL,
  UpdatedAt   DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
  CONSTRAINT PK_Lessons PRIMARY KEY (Lang, QuarterlyId, LessonId)
);

CREATE TABLE dbo.DayReads (
  Lang        NVARCHAR(10) NOT NULL,
  QuarterlyId NVARCHAR(30) NOT NULL,
  LessonId    NVARCHAR(10) NOT NULL,
  DayId       NVARCHAR(10) NOT NULL,  -- "01".."07" (o los que existan)
  DayDate     DATE NULL,
  Title       NVARCHAR(250) NULL,
  ReadJson    NVARCHAR(MAX) NOT NULL, -- contenido de read/index.json
  UpdatedAt   DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
  CONSTRAINT PK_DayReads PRIMARY KEY (Lang, QuarterlyId, LessonId, DayId)
);

CREATE TABLE dbo.QuarterlyMedia (
  Lang        NVARCHAR(10) NOT NULL,
  QuarterlyId NVARCHAR(30) NOT NULL,
  MediaType   NVARCHAR(10) NOT NULL, -- 'audio' | 'video'
  RawJson     NVARCHAR(MAX) NOT NULL,
  UpdatedAt   DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
  CONSTRAINT PK_QuarterlyMedia PRIMARY KEY (Lang, QuarterlyId, MediaType)
);

CREATE INDEX IX_DayReads_UpdatedAt ON dbo.DayReads(UpdatedAt);
CREATE INDEX IX_Lessons_Quarterly ON dbo.Lessons(Lang, QuarterlyId);

-- ============================================================
-- 3) MULTI-TENANT + ESTRUCTURA ORGANIZACIONAL (SAAS)
-- ============================================================
-- Nota:
-- - El catalogo (Quarterlies/Lessons/DayReads) puede mantenerse compartido.
-- - Estas tablas agregan autenticacion/autorizacion y jerarquia de la organizacion.

CREATE TABLE dbo.Tenants (
  TenantId        UNIQUEIDENTIFIER NOT NULL
    CONSTRAINT DF_Tenants_TenantId DEFAULT NEWSEQUENTIALID(),
  Code            NVARCHAR(50) NOT NULL,  -- slug unico del cliente (ej: "union-centro")
  Name            NVARCHAR(200) NOT NULL,
  Status          NVARCHAR(20) NOT NULL
    CONSTRAINT DF_Tenants_Status DEFAULT 'ACTIVE',
  CreatedAt       DATETIME2 NOT NULL
    CONSTRAINT DF_Tenants_CreatedAt DEFAULT SYSUTCDATETIME(),
  UpdatedAt       DATETIME2 NOT NULL
    CONSTRAINT DF_Tenants_UpdatedAt DEFAULT SYSUTCDATETIME(),
  CONSTRAINT PK_Tenants PRIMARY KEY (TenantId),
  CONSTRAINT UQ_Tenants_Code UNIQUE (Code),
  CONSTRAINT CK_Tenants_Status CHECK (Status IN ('ACTIVE', 'INACTIVE'))
);

CREATE TABLE dbo.OrgUnitTypes (
  OrgUnitTypeCode NVARCHAR(40) NOT NULL, -- tipo jerarquico
  Name            NVARCHAR(120) NOT NULL,
  HierarchyLevel  INT NOT NULL,          -- menor = mas arriba
  CONSTRAINT PK_OrgUnitTypes PRIMARY KEY (OrgUnitTypeCode),
  CONSTRAINT UQ_OrgUnitTypes_Level UNIQUE (HierarchyLevel)
);

CREATE TABLE dbo.OrgUnits (
  OrgUnitId         UNIQUEIDENTIFIER NOT NULL
    CONSTRAINT DF_OrgUnits_OrgUnitId DEFAULT NEWSEQUENTIALID(),
  TenantId          UNIQUEIDENTIFIER NOT NULL,
  OrgUnitTypeCode   NVARCHAR(40) NOT NULL,
  ParentOrgUnitId   UNIQUEIDENTIFIER NULL,
  Code              NVARCHAR(80) NOT NULL,     -- codigo interno por nivel
  Name              NVARCHAR(200) NOT NULL,    -- nombre visible
  Path              NVARCHAR(900) NULL,        -- opcional: ruta materializada (ej: /GC/DIV1/UNI3)
  IsActive          BIT NOT NULL
    CONSTRAINT DF_OrgUnits_IsActive DEFAULT 1,
  CreatedAt         DATETIME2 NOT NULL
    CONSTRAINT DF_OrgUnits_CreatedAt DEFAULT SYSUTCDATETIME(),
  UpdatedAt         DATETIME2 NOT NULL
    CONSTRAINT DF_OrgUnits_UpdatedAt DEFAULT SYSUTCDATETIME(),
  CONSTRAINT PK_OrgUnits PRIMARY KEY (OrgUnitId),
  CONSTRAINT FK_OrgUnits_Tenant FOREIGN KEY (TenantId) REFERENCES dbo.Tenants(TenantId),
  CONSTRAINT FK_OrgUnits_Type FOREIGN KEY (OrgUnitTypeCode) REFERENCES dbo.OrgUnitTypes(OrgUnitTypeCode),
  CONSTRAINT FK_OrgUnits_Parent FOREIGN KEY (ParentOrgUnitId) REFERENCES dbo.OrgUnits(OrgUnitId),
  CONSTRAINT UQ_OrgUnits_Tenant_Type_Code UNIQUE (TenantId, OrgUnitTypeCode, Code)
);

CREATE INDEX IX_OrgUnits_Tenant_Parent ON dbo.OrgUnits(TenantId, ParentOrgUnitId);
CREATE INDEX IX_OrgUnits_Tenant_Type ON dbo.OrgUnits(TenantId, OrgUnitTypeCode);

-- Tabla de cierre para consultas rapidas de descendencia/alcance.
CREATE TABLE dbo.OrgUnitClosure (
  TenantId            UNIQUEIDENTIFIER NOT NULL,
  AncestorOrgUnitId   UNIQUEIDENTIFIER NOT NULL,
  DescendantOrgUnitId UNIQUEIDENTIFIER NOT NULL,
  Depth               INT NOT NULL, -- 0 = mismo nodo, 1 = hijo directo, etc.
  CONSTRAINT PK_OrgUnitClosure PRIMARY KEY (TenantId, AncestorOrgUnitId, DescendantOrgUnitId),
  CONSTRAINT FK_OrgUnitClosure_Tenant FOREIGN KEY (TenantId) REFERENCES dbo.Tenants(TenantId),
  CONSTRAINT FK_OrgUnitClosure_Ancestor FOREIGN KEY (AncestorOrgUnitId) REFERENCES dbo.OrgUnits(OrgUnitId),
  CONSTRAINT FK_OrgUnitClosure_Descendant FOREIGN KEY (DescendantOrgUnitId) REFERENCES dbo.OrgUnits(OrgUnitId),
  CONSTRAINT CK_OrgUnitClosure_Depth CHECK (Depth >= 0)
);

CREATE INDEX IX_OrgUnitClosure_Descendant ON dbo.OrgUnitClosure(TenantId, DescendantOrgUnitId, Depth);

-- ============================================================
-- 4) USUARIOS + ROLES + PERMISOS + PANTALLAS
-- ============================================================

CREATE TABLE dbo.Users (
  UserId            UNIQUEIDENTIFIER NOT NULL
    CONSTRAINT DF_Users_UserId DEFAULT NEWSEQUENTIALID(),
  TenantId          UNIQUEIDENTIFIER NOT NULL,
  Email             NVARCHAR(254) NOT NULL,
  EmailNormalized   NVARCHAR(254) NOT NULL,
  PasswordHash      NVARCHAR(255) NOT NULL,
  FirstName         NVARCHAR(120) NULL,
  LastName          NVARCHAR(120) NULL,
  DisplayName       NVARCHAR(200) NULL,
  Phone             NVARCHAR(40) NULL,
  IsActive          BIT NOT NULL
    CONSTRAINT DF_Users_IsActive DEFAULT 1,
  EmailVerifiedAt   DATETIME2 NULL,
  LastLoginAt       DATETIME2 NULL,
  CreatedAt         DATETIME2 NOT NULL
    CONSTRAINT DF_Users_CreatedAt DEFAULT SYSUTCDATETIME(),
  UpdatedAt         DATETIME2 NOT NULL
    CONSTRAINT DF_Users_UpdatedAt DEFAULT SYSUTCDATETIME(),
  CONSTRAINT PK_Users PRIMARY KEY (UserId),
  CONSTRAINT FK_Users_Tenant FOREIGN KEY (TenantId) REFERENCES dbo.Tenants(TenantId),
  CONSTRAINT UQ_Users_Tenant_Email UNIQUE (TenantId, EmailNormalized)
);

CREATE INDEX IX_Users_Tenant_Active ON dbo.Users(TenantId, IsActive);

CREATE TABLE dbo.Roles (
  RoleId            UNIQUEIDENTIFIER NOT NULL
    CONSTRAINT DF_Roles_RoleId DEFAULT NEWSEQUENTIALID(),
  Code              NVARCHAR(80) NOT NULL,  -- unico global del sistema
  Name              NVARCHAR(150) NOT NULL,
  Description       NVARCHAR(300) NULL,
  IsSystemRole      BIT NOT NULL
    CONSTRAINT DF_Roles_IsSystemRole DEFAULT 1,
  CreatedAt         DATETIME2 NOT NULL
    CONSTRAINT DF_Roles_CreatedAt DEFAULT SYSUTCDATETIME(),
  CONSTRAINT PK_Roles PRIMARY KEY (RoleId),
  CONSTRAINT UQ_Roles_Code UNIQUE (Code)
);

CREATE TABLE dbo.Permissions (
  PermissionId      UNIQUEIDENTIFIER NOT NULL
    CONSTRAINT DF_Permissions_PermissionId DEFAULT NEWSEQUENTIALID(),
  Code              NVARCHAR(120) NOT NULL, -- ej: app.catalog.read
  Name              NVARCHAR(160) NOT NULL,
  Description       NVARCHAR(300) NULL,
  CreatedAt         DATETIME2 NOT NULL
    CONSTRAINT DF_Permissions_CreatedAt DEFAULT SYSUTCDATETIME(),
  CONSTRAINT PK_Permissions PRIMARY KEY (PermissionId),
  CONSTRAINT UQ_Permissions_Code UNIQUE (Code)
);

CREATE TABLE dbo.RolePermissions (
  RoleId            UNIQUEIDENTIFIER NOT NULL,
  PermissionId      UNIQUEIDENTIFIER NOT NULL,
  CreatedAt         DATETIME2 NOT NULL
    CONSTRAINT DF_RolePermissions_CreatedAt DEFAULT SYSUTCDATETIME(),
  CONSTRAINT PK_RolePermissions PRIMARY KEY (RoleId, PermissionId),
  CONSTRAINT FK_RolePermissions_Role FOREIGN KEY (RoleId) REFERENCES dbo.Roles(RoleId),
  CONSTRAINT FK_RolePermissions_Permission FOREIGN KEY (PermissionId) REFERENCES dbo.Permissions(PermissionId)
);

CREATE TABLE dbo.Screens (
  ScreenId          UNIQUEIDENTIFIER NOT NULL
    CONSTRAINT DF_Screens_ScreenId DEFAULT NEWSEQUENTIALID(),
  ScreenKey         NVARCHAR(120) NOT NULL, -- ej: mobile.lesson_reader
  Name              NVARCHAR(160) NOT NULL,
  Description       NVARCHAR(300) NULL,
  CreatedAt         DATETIME2 NOT NULL
    CONSTRAINT DF_Screens_CreatedAt DEFAULT SYSUTCDATETIME(),
  CONSTRAINT PK_Screens PRIMARY KEY (ScreenId),
  CONSTRAINT UQ_Screens_ScreenKey UNIQUE (ScreenKey)
);

CREATE TABLE dbo.ScreenPermissions (
  ScreenId          UNIQUEIDENTIFIER NOT NULL,
  PermissionId      UNIQUEIDENTIFIER NOT NULL,
  CreatedAt         DATETIME2 NOT NULL
    CONSTRAINT DF_ScreenPermissions_CreatedAt DEFAULT SYSUTCDATETIME(),
  CONSTRAINT PK_ScreenPermissions PRIMARY KEY (ScreenId, PermissionId),
  CONSTRAINT FK_ScreenPermissions_Screen FOREIGN KEY (ScreenId) REFERENCES dbo.Screens(ScreenId),
  CONSTRAINT FK_ScreenPermissions_Permission FOREIGN KEY (PermissionId) REFERENCES dbo.Permissions(PermissionId)
);

-- Asignacion de roles por alcance (scope organizacional).
CREATE TABLE dbo.UserRoleAssignments (
  UserRoleAssignmentId UNIQUEIDENTIFIER NOT NULL
    CONSTRAINT DF_UserRoleAssignments_Id DEFAULT NEWSEQUENTIALID(),
  TenantId             UNIQUEIDENTIFIER NOT NULL,
  UserId               UNIQUEIDENTIFIER NOT NULL,
  RoleId               UNIQUEIDENTIFIER NOT NULL,
  ScopeOrgUnitId       UNIQUEIDENTIFIER NOT NULL,
  IsActive             BIT NOT NULL
    CONSTRAINT DF_UserRoleAssignments_IsActive DEFAULT 1,
  ValidFrom            DATETIME2 NULL,
  ValidTo              DATETIME2 NULL,
  AssignedByUserId     UNIQUEIDENTIFIER NULL,
  CreatedAt            DATETIME2 NOT NULL
    CONSTRAINT DF_UserRoleAssignments_CreatedAt DEFAULT SYSUTCDATETIME(),
  UpdatedAt            DATETIME2 NOT NULL
    CONSTRAINT DF_UserRoleAssignments_UpdatedAt DEFAULT SYSUTCDATETIME(),
  CONSTRAINT PK_UserRoleAssignments PRIMARY KEY (UserRoleAssignmentId),
  CONSTRAINT FK_UserRoleAssignments_Tenant FOREIGN KEY (TenantId) REFERENCES dbo.Tenants(TenantId),
  CONSTRAINT FK_UserRoleAssignments_User FOREIGN KEY (UserId) REFERENCES dbo.Users(UserId),
  CONSTRAINT FK_UserRoleAssignments_Role FOREIGN KEY (RoleId) REFERENCES dbo.Roles(RoleId),
  CONSTRAINT FK_UserRoleAssignments_ScopeOrgUnit FOREIGN KEY (ScopeOrgUnitId) REFERENCES dbo.OrgUnits(OrgUnitId),
  CONSTRAINT CK_UserRoleAssignments_ValidRange CHECK (ValidTo IS NULL OR ValidFrom IS NULL OR ValidTo >= ValidFrom)
);

CREATE INDEX IX_UserRoleAssignments_User ON dbo.UserRoleAssignments(TenantId, UserId, IsActive);
CREATE INDEX IX_UserRoleAssignments_Scope ON dbo.UserRoleAssignments(TenantId, ScopeOrgUnitId, IsActive);
CREATE UNIQUE INDEX UX_UserRoleAssignments_Active
  ON dbo.UserRoleAssignments(TenantId, UserId, RoleId, ScopeOrgUnitId)
  WHERE IsActive = 1;

-- Membresias directas del usuario en unidades (ej: miembro de iglesia, lider de GP).
CREATE TABLE dbo.UserOrgMemberships (
  UserOrgMembershipId UNIQUEIDENTIFIER NOT NULL
    CONSTRAINT DF_UserOrgMemberships_Id DEFAULT NEWSEQUENTIALID(),
  TenantId            UNIQUEIDENTIFIER NOT NULL,
  UserId              UNIQUEIDENTIFIER NOT NULL,
  OrgUnitId           UNIQUEIDENTIFIER NOT NULL,
  MembershipType      NVARCHAR(40) NOT NULL, -- MEMBER | LEADER | PASTOR | DIRECTOR
  IsPrimary           BIT NOT NULL
    CONSTRAINT DF_UserOrgMemberships_IsPrimary DEFAULT 0,
  IsActive            BIT NOT NULL
    CONSTRAINT DF_UserOrgMemberships_IsActive DEFAULT 1,
  CreatedAt           DATETIME2 NOT NULL
    CONSTRAINT DF_UserOrgMemberships_CreatedAt DEFAULT SYSUTCDATETIME(),
  UpdatedAt           DATETIME2 NOT NULL
    CONSTRAINT DF_UserOrgMemberships_UpdatedAt DEFAULT SYSUTCDATETIME(),
  CONSTRAINT PK_UserOrgMemberships PRIMARY KEY (UserOrgMembershipId),
  CONSTRAINT FK_UserOrgMemberships_Tenant FOREIGN KEY (TenantId) REFERENCES dbo.Tenants(TenantId),
  CONSTRAINT FK_UserOrgMemberships_User FOREIGN KEY (UserId) REFERENCES dbo.Users(UserId),
  CONSTRAINT FK_UserOrgMemberships_OrgUnit FOREIGN KEY (OrgUnitId) REFERENCES dbo.OrgUnits(OrgUnitId),
  CONSTRAINT CK_UserOrgMemberships_Type CHECK (MembershipType IN ('MEMBER', 'LEADER', 'PASTOR', 'DIRECTOR'))
);

CREATE INDEX IX_UserOrgMemberships_User ON dbo.UserOrgMemberships(TenantId, UserId, IsActive);
CREATE INDEX IX_UserOrgMemberships_OrgUnit ON dbo.UserOrgMemberships(TenantId, OrgUnitId, IsActive);

-- ============================================================
-- 5) CATALOGO BASE (TIPOS, ROLES, PERMISOS, PANTALLAS)
-- ============================================================

INSERT INTO dbo.OrgUnitTypes (OrgUnitTypeCode, Name, HierarchyLevel) VALUES
('GENERAL_CONFERENCE', 'Asociacion General', 1),
('DIVISION',           'Division',            2),
('UNION',              'Union',               3),
('FIELD',              'Asociacion/Mision',   4),
('DISTRICT',           'Distrito',            5),
('CHURCH',             'Iglesia',             6),
('SMALL_GROUP',        'Grupo Pequeno',       7);

INSERT INTO dbo.Roles (Code, Name, Description) VALUES
('GENERAL_SABBATH_DIRECTOR',  'Director ES Asociacion General', 'Director de Escuela Sabatica con alcance de Asociacion General'),
('DIVISION_SABBATH_DIRECTOR', 'Director ES Division',           'Director de Escuela Sabatica con alcance de Division'),
('UNION_SABBATH_DIRECTOR',    'Director ES Union',              'Director de Escuela Sabatica con alcance de Union'),
('FIELD_SABBATH_DIRECTOR',    'Director ES Asociacion/Mision',  'Director de Escuela Sabatica con alcance de Asociacion/Mision'),
('DISTRICT_SABBATH_DIRECTOR', 'Director ES Distrito',           'Director de Escuela Sabatica con alcance de Distrito'),
('CHURCH_SABBATH_DIRECTOR',   'Director ES Iglesia',            'Director de Escuela Sabatica con alcance de Iglesia'),
('PASTOR',                    'Pastor',                         'Mismos privilegios de Director ES de iglesia + administracion'),
('SMALL_GROUP_LEADER',        'Lider de Grupo Pequeno',         'Gestiona su grupo pequeno'),
('CHURCH_MEMBER',             'Miembro de Iglesia',             'Acceso al frontend de estudio personal');

INSERT INTO dbo.Permissions (Code, Name, Description) VALUES
('app.catalog.read',               'Leer catalogo',                 'Acceso a trimestres, lecciones y dias'),
('app.study_marks.write',          'Marcar estudio',                'Permite marcar dias estudiados'),
('app.group.members.read',         'Ver miembros de grupo',         'Consulta miembros del grupo pequeno'),
('app.group.members.manage',       'Gestionar miembros de grupo',   'Alta/baja/gestion de miembros del grupo pequeno'),
('app.reports.scope.read',         'Ver reportes por alcance',      'Consulta reportes agregados en su alcance'),
('app.reports.scope.export',       'Exportar reportes',             'Exporta reportes del alcance'),
('app.users.read',                 'Ver usuarios',                  'Consulta usuarios del alcance'),
('app.users.manage',               'Gestionar usuarios',            'Alta/edicion/bloqueo de usuarios del alcance'),
('app.roles.assign',               'Asignar roles',                 'Asignacion de roles en alcance'),
('app.org.manage',                 'Gestionar estructura',          'Gestion organizacional en el alcance'),
('app.sync.execute',               'Ejecutar sincronizacion',       'Ejecutar procesos de sincronizacion/carga');

INSERT INTO dbo.Screens (ScreenKey, Name, Description) VALUES
('mobile.quarterlies',         'Trimestres',            'Listado de trimestres disponibles'),
('mobile.lessons',             'Lecciones',             'Listado de lecciones por trimestre'),
('mobile.lesson_reader',       'Lector diario',         'Contenido diario de la leccion'),
('mobile.study_progress',      'Progreso personal',     'Pantallas de progreso estudiado'),
('admin.users',                'Administracion usuarios','Gestion de usuarios'),
('admin.roles',                'Administracion roles',  'Asignacion de roles'),
('admin.org_structure',        'Estructura organizacional','Gestion de unidades organizacionales'),
('admin.reports',              'Reportes',              'Reportes por alcance');

-- Relacion pantalla -> permisos minimos requeridos.
INSERT INTO dbo.ScreenPermissions (ScreenId, PermissionId)
SELECT s.ScreenId, p.PermissionId
FROM dbo.Screens s
JOIN dbo.Permissions p ON p.Code = 'app.catalog.read'
WHERE s.ScreenKey IN ('mobile.quarterlies', 'mobile.lessons', 'mobile.lesson_reader');

INSERT INTO dbo.ScreenPermissions (ScreenId, PermissionId)
SELECT s.ScreenId, p.PermissionId
FROM dbo.Screens s
JOIN dbo.Permissions p ON p.Code = 'app.study_marks.write'
WHERE s.ScreenKey IN ('mobile.study_progress', 'mobile.lesson_reader');

INSERT INTO dbo.ScreenPermissions (ScreenId, PermissionId)
SELECT s.ScreenId, p.PermissionId
FROM dbo.Screens s
JOIN dbo.Permissions p ON p.Code = 'app.users.read'
WHERE s.ScreenKey IN ('admin.users');

INSERT INTO dbo.ScreenPermissions (ScreenId, PermissionId)
SELECT s.ScreenId, p.PermissionId
FROM dbo.Screens s
JOIN dbo.Permissions p ON p.Code = 'app.roles.assign'
WHERE s.ScreenKey IN ('admin.roles');

INSERT INTO dbo.ScreenPermissions (ScreenId, PermissionId)
SELECT s.ScreenId, p.PermissionId
FROM dbo.Screens s
JOIN dbo.Permissions p ON p.Code = 'app.org.manage'
WHERE s.ScreenKey IN ('admin.org_structure');

INSERT INTO dbo.ScreenPermissions (ScreenId, PermissionId)
SELECT s.ScreenId, p.PermissionId
FROM dbo.Screens s
JOIN dbo.Permissions p ON p.Code = 'app.reports.scope.read'
WHERE s.ScreenKey IN ('admin.reports');

-- Matriz base de permisos por rol.
-- Miembro de iglesia: acceso total a estudio personal actual (frontend).
INSERT INTO dbo.RolePermissions (RoleId, PermissionId)
SELECT r.RoleId, p.PermissionId
FROM dbo.Roles r
JOIN dbo.Permissions p ON p.Code IN ('app.catalog.read', 'app.study_marks.write')
WHERE r.Code = 'CHURCH_MEMBER';

INSERT INTO dbo.RolePermissions (RoleId, PermissionId)
SELECT r.RoleId, p.PermissionId
FROM dbo.Roles r
JOIN dbo.Permissions p ON p.Code IN (
  'app.catalog.read',
  'app.study_marks.write',
  'app.group.members.read',
  'app.group.members.manage',
  'app.reports.scope.read'
)
WHERE r.Code = 'SMALL_GROUP_LEADER';

INSERT INTO dbo.RolePermissions (RoleId, PermissionId)
SELECT r.RoleId, p.PermissionId
FROM dbo.Roles r
JOIN dbo.Permissions p ON p.Code IN (
  'app.catalog.read',
  'app.study_marks.write',
  'app.reports.scope.read',
  'app.users.read'
)
WHERE r.Code = 'CHURCH_SABBATH_DIRECTOR';

INSERT INTO dbo.RolePermissions (RoleId, PermissionId)
SELECT r.RoleId, p.PermissionId
FROM dbo.Roles r
JOIN dbo.Permissions p ON p.Code IN (
  'app.catalog.read',
  'app.study_marks.write',
  'app.reports.scope.read',
  'app.reports.scope.export',
  'app.users.read',
  'app.users.manage',
  'app.roles.assign',
  'app.sync.execute'
)
WHERE r.Code = 'PASTOR';

INSERT INTO dbo.RolePermissions (RoleId, PermissionId)
SELECT r.RoleId, p.PermissionId
FROM dbo.Roles r
JOIN dbo.Permissions p ON p.Code IN (
  'app.catalog.read',
  'app.study_marks.write',
  'app.reports.scope.read',
  'app.reports.scope.export',
  'app.users.read',
  'app.roles.assign',
  'app.sync.execute'
)
WHERE r.Code IN (
  'DISTRICT_SABBATH_DIRECTOR',
  'FIELD_SABBATH_DIRECTOR',
  'UNION_SABBATH_DIRECTOR',
  'DIVISION_SABBATH_DIRECTOR',
  'GENERAL_SABBATH_DIRECTOR'
);

-- ============================================================
-- 6) VISTA DE PERMISOS EFECTIVOS POR ALCANCE
-- ============================================================
-- Regla:
-- - Si un usuario tiene rol asignado en ScopeOrgUnitId = X,
--   el permiso aplica para X y todos sus descendientes.
CREATE VIEW dbo.vwUserEffectivePermissions
AS
SELECT
  ura.TenantId,
  ura.UserId,
  oc.DescendantOrgUnitId AS EffectiveOrgUnitId,
  p.Code AS PermissionCode,
  r.Code AS RoleCode
FROM dbo.UserRoleAssignments ura
JOIN dbo.OrgUnitClosure oc
  ON oc.TenantId = ura.TenantId
 AND oc.AncestorOrgUnitId = ura.ScopeOrgUnitId
JOIN dbo.RolePermissions rp
  ON rp.RoleId = ura.RoleId
JOIN dbo.Permissions p
  ON p.PermissionId = rp.PermissionId
JOIN dbo.Roles r
  ON r.RoleId = ura.RoleId
WHERE ura.IsActive = 1
  AND (ura.ValidFrom IS NULL OR ura.ValidFrom <= SYSUTCDATETIME())
  AND (ura.ValidTo IS NULL OR ura.ValidTo >= SYSUTCDATETIME());

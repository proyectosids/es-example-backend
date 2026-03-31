SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
  BEGIN TRAN;

  -- ============================================================
  -- BE-1 (Aditivo): Gobierno de roles + membresias de grupo
  -- ============================================================

  -- ------------------------------------------------------------
  -- 1) RoleAssignmentRules
  -- ------------------------------------------------------------
  IF OBJECT_ID('dbo.RoleAssignmentRules', 'U') IS NULL
  BEGIN
    CREATE TABLE dbo.RoleAssignmentRules (
      RoleAssignmentRuleId   UNIQUEIDENTIFIER NOT NULL
        CONSTRAINT DF_RoleAssignmentRules_Id DEFAULT NEWSEQUENTIALID(),
      AssignerRoleCode       NVARCHAR(80) NOT NULL,
      AssignableRoleCode     NVARCHAR(80) NOT NULL,
      ScopeOrgUnitTypeCode   NVARCHAR(40) NOT NULL,
      RequiresSameChurch     BIT NOT NULL
        CONSTRAINT DF_RoleAssignmentRules_RequiresSameChurch DEFAULT 0,
      IsActive               BIT NOT NULL
        CONSTRAINT DF_RoleAssignmentRules_IsActive DEFAULT 1,
      CreatedAt              DATETIME2 NOT NULL
        CONSTRAINT DF_RoleAssignmentRules_CreatedAt DEFAULT SYSUTCDATETIME(),
      CONSTRAINT PK_RoleAssignmentRules PRIMARY KEY (RoleAssignmentRuleId),
      CONSTRAINT FK_RoleAssignmentRules_AssignerRole
        FOREIGN KEY (AssignerRoleCode) REFERENCES dbo.Roles(Code),
      CONSTRAINT FK_RoleAssignmentRules_AssignableRole
        FOREIGN KEY (AssignableRoleCode) REFERENCES dbo.Roles(Code),
      CONSTRAINT FK_RoleAssignmentRules_ScopeType
        FOREIGN KEY (ScopeOrgUnitTypeCode) REFERENCES dbo.OrgUnitTypes(OrgUnitTypeCode),
      CONSTRAINT UQ_RoleAssignmentRules
        UNIQUE (AssignerRoleCode, AssignableRoleCode, ScopeOrgUnitTypeCode)
    );
  END;

  -- ------------------------------------------------------------
  -- 2) SmallGroupMemberships
  -- ------------------------------------------------------------
  IF OBJECT_ID('dbo.SmallGroupMemberships', 'U') IS NULL
  BEGIN
    CREATE TABLE dbo.SmallGroupMemberships (
      SmallGroupMembershipId UNIQUEIDENTIFIER NOT NULL
        CONSTRAINT DF_SmallGroupMemberships_Id DEFAULT NEWSEQUENTIALID(),
      TenantId               UNIQUEIDENTIFIER NOT NULL,
      UserId                 UNIQUEIDENTIFIER NOT NULL,
      ChurchOrgUnitId        UNIQUEIDENTIFIER NOT NULL,
      SmallGroupOrgUnitId    UNIQUEIDENTIFIER NOT NULL,
      QuarterlyId            NVARCHAR(30) NOT NULL,
      Status                 NVARCHAR(20) NOT NULL,
      RequestedByUserId      UNIQUEIDENTIFIER NOT NULL,
      ApprovedByUserId       UNIQUEIDENTIFIER NULL,
      RequestedAt            DATETIME2 NOT NULL
        CONSTRAINT DF_SGM_RequestedAt DEFAULT SYSUTCDATETIME(),
      DecidedAt              DATETIME2 NULL,
      Notes                  NVARCHAR(500) NULL,
      IsActive               BIT NOT NULL
        CONSTRAINT DF_SGM_IsActive DEFAULT 1,
      CONSTRAINT PK_SmallGroupMemberships PRIMARY KEY (SmallGroupMembershipId),
      CONSTRAINT FK_SGM_Tenant FOREIGN KEY (TenantId) REFERENCES dbo.Tenants(TenantId),
      CONSTRAINT FK_SGM_User FOREIGN KEY (UserId) REFERENCES dbo.Users(UserId),
      CONSTRAINT FK_SGM_Church FOREIGN KEY (ChurchOrgUnitId) REFERENCES dbo.OrgUnits(OrgUnitId),
      CONSTRAINT FK_SGM_SmallGroup FOREIGN KEY (SmallGroupOrgUnitId) REFERENCES dbo.OrgUnits(OrgUnitId),
      CONSTRAINT FK_SGM_RequestedBy FOREIGN KEY (RequestedByUserId) REFERENCES dbo.Users(UserId),
      CONSTRAINT FK_SGM_ApprovedBy FOREIGN KEY (ApprovedByUserId) REFERENCES dbo.Users(UserId),
      CONSTRAINT CK_SGM_Status CHECK (Status IN ('PENDING','APPROVED','REJECTED','CANCELLED'))
    );
  END;

  IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.SmallGroupMemberships')
      AND name = 'IX_SGM_UserQuarter'
  )
  BEGIN
    CREATE INDEX IX_SGM_UserQuarter
      ON dbo.SmallGroupMemberships(TenantId, UserId, QuarterlyId, Status, IsActive);
  END;

  IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.SmallGroupMemberships')
      AND name = 'IX_SGM_GroupQuarter'
  )
  BEGIN
    CREATE INDEX IX_SGM_GroupQuarter
      ON dbo.SmallGroupMemberships(TenantId, SmallGroupOrgUnitId, QuarterlyId, Status, IsActive);
  END;

  IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.SmallGroupMemberships')
      AND name = 'UX_SGM_OneActiveApprovedPerQuarter'
  )
  BEGIN
    CREATE UNIQUE INDEX UX_SGM_OneActiveApprovedPerQuarter
      ON dbo.SmallGroupMemberships(TenantId, UserId, QuarterlyId)
      WHERE IsActive = 1 AND Status = 'APPROVED';
  END;

  IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.SmallGroupMemberships')
      AND name = 'UX_SGM_OneActivePendingPerQuarter'
  )
  BEGIN
    CREATE UNIQUE INDEX UX_SGM_OneActivePendingPerQuarter
      ON dbo.SmallGroupMemberships(TenantId, UserId, QuarterlyId)
      WHERE IsActive = 1 AND Status = 'PENDING';
  END;

  -- ------------------------------------------------------------
  -- 3) QuarterlyMembershipPolicy (opcional, recomendado)
  -- ------------------------------------------------------------
  IF OBJECT_ID('dbo.QuarterlyMembershipPolicy', 'U') IS NULL
  BEGIN
    CREATE TABLE dbo.QuarterlyMembershipPolicy (
      TenantId                 UNIQUEIDENTIFIER NOT NULL,
      QuarterlyId              NVARCHAR(30) NOT NULL,
      ChangeOpenAt             DATETIME2 NULL,
      ChangeCloseAt            DATETIME2 NULL,
      RequireLeaderApproval    BIT NOT NULL
        CONSTRAINT DF_QMP_RequireLeaderApproval DEFAULT 1,
      CreatedAt                DATETIME2 NOT NULL
        CONSTRAINT DF_QMP_CreatedAt DEFAULT SYSUTCDATETIME(),
      UpdatedAt                DATETIME2 NOT NULL
        CONSTRAINT DF_QMP_UpdatedAt DEFAULT SYSUTCDATETIME(),
      CONSTRAINT PK_QuarterlyMembershipPolicy PRIMARY KEY (TenantId, QuarterlyId),
      CONSTRAINT FK_QMP_Tenant FOREIGN KEY (TenantId) REFERENCES dbo.Tenants(TenantId)
    );
  END;

  -- ------------------------------------------------------------
  -- 4) Seed de reglas de asignacion de rol
  -- ------------------------------------------------------------
  IF EXISTS (SELECT 1 FROM dbo.Roles WHERE Code = 'FIELD_SABBATH_DIRECTOR')
     AND EXISTS (SELECT 1 FROM dbo.Roles WHERE Code = 'PASTOR')
     AND EXISTS (SELECT 1 FROM dbo.OrgUnitTypes WHERE OrgUnitTypeCode = 'CHURCH')
     AND NOT EXISTS (
       SELECT 1
       FROM dbo.RoleAssignmentRules
       WHERE AssignerRoleCode = 'FIELD_SABBATH_DIRECTOR'
         AND AssignableRoleCode = 'PASTOR'
         AND ScopeOrgUnitTypeCode = 'CHURCH'
     )
  BEGIN
    INSERT INTO dbo.RoleAssignmentRules (
      AssignerRoleCode,
      AssignableRoleCode,
      ScopeOrgUnitTypeCode,
      RequiresSameChurch,
      IsActive
    )
    VALUES (
      'FIELD_SABBATH_DIRECTOR',
      'PASTOR',
      'CHURCH',
      0,
      1
    );
  END;

  IF EXISTS (SELECT 1 FROM dbo.Roles WHERE Code = 'PASTOR')
     AND EXISTS (SELECT 1 FROM dbo.Roles WHERE Code = 'CHURCH_SABBATH_DIRECTOR')
     AND EXISTS (SELECT 1 FROM dbo.OrgUnitTypes WHERE OrgUnitTypeCode = 'CHURCH')
     AND NOT EXISTS (
       SELECT 1
       FROM dbo.RoleAssignmentRules
       WHERE AssignerRoleCode = 'PASTOR'
         AND AssignableRoleCode = 'CHURCH_SABBATH_DIRECTOR'
         AND ScopeOrgUnitTypeCode = 'CHURCH'
     )
  BEGIN
    INSERT INTO dbo.RoleAssignmentRules (
      AssignerRoleCode,
      AssignableRoleCode,
      ScopeOrgUnitTypeCode,
      RequiresSameChurch,
      IsActive
    )
    VALUES (
      'PASTOR',
      'CHURCH_SABBATH_DIRECTOR',
      'CHURCH',
      1,
      1
    );
  END;

  IF EXISTS (SELECT 1 FROM dbo.Roles WHERE Code = 'CHURCH_SABBATH_DIRECTOR')
     AND EXISTS (SELECT 1 FROM dbo.Roles WHERE Code = 'SMALL_GROUP_LEADER')
     AND EXISTS (SELECT 1 FROM dbo.OrgUnitTypes WHERE OrgUnitTypeCode = 'SMALL_GROUP')
     AND NOT EXISTS (
       SELECT 1
       FROM dbo.RoleAssignmentRules
       WHERE AssignerRoleCode = 'CHURCH_SABBATH_DIRECTOR'
         AND AssignableRoleCode = 'SMALL_GROUP_LEADER'
         AND ScopeOrgUnitTypeCode = 'SMALL_GROUP'
     )
  BEGIN
    INSERT INTO dbo.RoleAssignmentRules (
      AssignerRoleCode,
      AssignableRoleCode,
      ScopeOrgUnitTypeCode,
      RequiresSameChurch,
      IsActive
    )
    VALUES (
      'CHURCH_SABBATH_DIRECTOR',
      'SMALL_GROUP_LEADER',
      'SMALL_GROUP',
      1,
      1
    );
  END;

  COMMIT;

  SELECT 'BE-1 migration applied successfully' AS message;
END TRY
BEGIN CATCH
  IF @@TRANCOUNT > 0
    ROLLBACK;

  DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
  DECLARE @ErrNum INT = ERROR_NUMBER();
  DECLARE @ErrState INT = ERROR_STATE();

  RAISERROR('BE-1 migration failed (%d): %s', 16, 1, @ErrNum, @ErrMsg);
END CATCH;
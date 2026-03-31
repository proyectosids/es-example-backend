SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
  BEGIN TRAN;

  -- ============================================================
  -- BE-3: Auditoria minima de eventos criticos
  -- ============================================================

  IF OBJECT_ID('dbo.AuditEvents', 'U') IS NULL
  BEGIN
    CREATE TABLE dbo.AuditEvents (
      AuditEventId      UNIQUEIDENTIFIER NOT NULL
        CONSTRAINT DF_AuditEvents_Id DEFAULT NEWSEQUENTIALID(),
      TenantId          UNIQUEIDENTIFIER NOT NULL,
      ActorUserId       UNIQUEIDENTIFIER NULL,
      ActionCode        NVARCHAR(120) NOT NULL,
      EntityType        NVARCHAR(80) NOT NULL,
      EntityId          NVARCHAR(120) NULL,
      TargetOrgUnitId   UNIQUEIDENTIFIER NULL,
      Outcome           NVARCHAR(20) NOT NULL
        CONSTRAINT DF_AuditEvents_Outcome DEFAULT 'SUCCESS',
      MetadataJson      NVARCHAR(MAX) NULL,
      CreatedAt         DATETIME2 NOT NULL
        CONSTRAINT DF_AuditEvents_CreatedAt DEFAULT SYSUTCDATETIME(),
      CONSTRAINT PK_AuditEvents PRIMARY KEY (AuditEventId),
      CONSTRAINT FK_AuditEvents_Tenant
        FOREIGN KEY (TenantId) REFERENCES dbo.Tenants(TenantId),
      CONSTRAINT FK_AuditEvents_ActorUser
        FOREIGN KEY (ActorUserId) REFERENCES dbo.Users(UserId),
      CONSTRAINT FK_AuditEvents_TargetOrgUnit
        FOREIGN KEY (TargetOrgUnitId) REFERENCES dbo.OrgUnits(OrgUnitId),
      CONSTRAINT CK_AuditEvents_Outcome
        CHECK (Outcome IN ('SUCCESS', 'FAILURE'))
    );
  END;

  IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.AuditEvents')
      AND name = 'IX_AuditEvents_Tenant_CreatedAt'
  )
  BEGIN
    CREATE INDEX IX_AuditEvents_Tenant_CreatedAt
      ON dbo.AuditEvents(TenantId, CreatedAt DESC);
  END;

  IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.AuditEvents')
      AND name = 'IX_AuditEvents_Actor_Action'
  )
  BEGIN
    CREATE INDEX IX_AuditEvents_Actor_Action
      ON dbo.AuditEvents(TenantId, ActorUserId, ActionCode, CreatedAt DESC);
  END;

  COMMIT;

  SELECT 'BE-3 audit migration applied successfully' AS message;
END TRY
BEGIN CATCH
  IF @@TRANCOUNT > 0
    ROLLBACK;

  DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
  DECLARE @ErrNum INT = ERROR_NUMBER();

  RAISERROR('BE-3 audit migration failed (%d): %s', 16, 1, @ErrNum, @ErrMsg);
END CATCH;


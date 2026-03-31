SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
  BEGIN TRAN;

  -- ============================================================
  -- BE-2: Ajuste de matriz de permisos para endpoints especializados
  -- ============================================================
  -- Objetivo:
  -- 1) FIELD_SABBATH_DIRECTOR pueda crear/asignar pastor en iglesia
  --    (requiere app.users.manage + app.roles.assign)
  -- 2) CHURCH_SABBATH_DIRECTOR pueda asignar lideres de grupo pequeno
  --    (requiere app.roles.assign)

  IF EXISTS (SELECT 1 FROM dbo.Roles WHERE Code = 'FIELD_SABBATH_DIRECTOR')
     AND EXISTS (SELECT 1 FROM dbo.Permissions WHERE Code = 'app.users.manage')
     AND NOT EXISTS (
       SELECT 1
       FROM dbo.RolePermissions rp
       JOIN dbo.Roles r ON r.RoleId = rp.RoleId
       JOIN dbo.Permissions p ON p.PermissionId = rp.PermissionId
       WHERE r.Code = 'FIELD_SABBATH_DIRECTOR'
         AND p.Code = 'app.users.manage'
     )
  BEGIN
    INSERT INTO dbo.RolePermissions (RoleId, PermissionId)
    SELECT r.RoleId, p.PermissionId
    FROM dbo.Roles r
    JOIN dbo.Permissions p ON p.Code = 'app.users.manage'
    WHERE r.Code = 'FIELD_SABBATH_DIRECTOR';
  END;

  IF EXISTS (SELECT 1 FROM dbo.Roles WHERE Code = 'CHURCH_SABBATH_DIRECTOR')
     AND EXISTS (SELECT 1 FROM dbo.Permissions WHERE Code = 'app.roles.assign')
     AND NOT EXISTS (
       SELECT 1
       FROM dbo.RolePermissions rp
       JOIN dbo.Roles r ON r.RoleId = rp.RoleId
       JOIN dbo.Permissions p ON p.PermissionId = rp.PermissionId
       WHERE r.Code = 'CHURCH_SABBATH_DIRECTOR'
         AND p.Code = 'app.roles.assign'
     )
  BEGIN
    INSERT INTO dbo.RolePermissions (RoleId, PermissionId)
    SELECT r.RoleId, p.PermissionId
    FROM dbo.Roles r
    JOIN dbo.Permissions p ON p.Code = 'app.roles.assign'
    WHERE r.Code = 'CHURCH_SABBATH_DIRECTOR';
  END;

  COMMIT;
  SELECT 'BE-2 permission adjustments applied successfully' AS message;
END TRY
BEGIN CATCH
  IF @@TRANCOUNT > 0
    ROLLBACK;

  DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
  DECLARE @ErrNum INT = ERROR_NUMBER();
  RAISERROR('BE-2 permission adjustment failed (%d): %s', 16, 1, @ErrNum, @ErrMsg);
END CATCH;


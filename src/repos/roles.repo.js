import { getPool, sql } from "../db/pool.js";

export async function getRoleByCode(code) {
  const pool = await getPool();
  const res = await pool.request()
    .input("Code", sql.NVarChar(80), code)
    .query(`
      SELECT RoleId, Code, Name, Description
      FROM dbo.Roles
      WHERE Code=@Code
    `);
  return res.recordset[0] || null;
}

export async function listRoles() {
  const pool = await getPool();
  const res = await pool.request().query(`
    SELECT RoleId, Code, Name, Description, IsSystemRole
    FROM dbo.Roles
    ORDER BY Name
  `);
  return res.recordset;
}

export async function hasPermissionAtScope({ tenantId, userId, permissionCode, orgUnitId }) {
  const pool = await getPool();
  const res = await pool.request()
    .input("TenantId", sql.UniqueIdentifier, tenantId)
    .input("UserId", sql.UniqueIdentifier, userId)
    .input("PermissionCode", sql.NVarChar(120), permissionCode)
    .input("OrgUnitId", sql.UniqueIdentifier, orgUnitId)
    .query(`
      SELECT TOP 1 1 AS ok
      FROM dbo.vwUserEffectivePermissions
      WHERE TenantId=@TenantId
        AND UserId=@UserId
        AND PermissionCode=@PermissionCode
        AND EffectiveOrgUnitId=@OrgUnitId
    `);
  return res.recordset.length > 0;
}

export async function hasPermissionAnyScope({ tenantId, userId, permissionCode }) {
  const pool = await getPool();
  const res = await pool.request()
    .input("TenantId", sql.UniqueIdentifier, tenantId)
    .input("UserId", sql.UniqueIdentifier, userId)
    .input("PermissionCode", sql.NVarChar(120), permissionCode)
    .query(`
      SELECT TOP 1 1 AS ok
      FROM dbo.vwUserEffectivePermissions
      WHERE TenantId=@TenantId
        AND UserId=@UserId
        AND PermissionCode=@PermissionCode
    `);
  return res.recordset.length > 0;
}

export async function listEffectivePermissions({ tenantId, userId, orgUnitId = null }) {
  const pool = await getPool();
  const req = pool.request()
    .input("TenantId", sql.UniqueIdentifier, tenantId)
    .input("UserId", sql.UniqueIdentifier, userId);

  if (orgUnitId) {
    req.input("OrgUnitId", sql.UniqueIdentifier, orgUnitId);
  }

  const res = await req.query(`
    SELECT DISTINCT PermissionCode
    FROM dbo.vwUserEffectivePermissions
    WHERE TenantId=@TenantId
      AND UserId=@UserId
      ${orgUnitId ? "AND EffectiveOrgUnitId=@OrgUnitId" : ""}
    ORDER BY PermissionCode
  `);
  return res.recordset.map(r => r.PermissionCode);
}

export async function listEffectiveScreens({ tenantId, userId, orgUnitId = null }) {
  const pool = await getPool();
  const req = pool.request()
    .input("TenantId", sql.UniqueIdentifier, tenantId)
    .input("UserId", sql.UniqueIdentifier, userId);

  if (orgUnitId) {
    req.input("OrgUnitId", sql.UniqueIdentifier, orgUnitId);
  }

  const res = await req.query(`
    SELECT DISTINCT s.ScreenKey, s.Name
    FROM dbo.vwUserEffectivePermissions v
    JOIN dbo.Permissions p ON p.Code = v.PermissionCode
    JOIN dbo.ScreenPermissions sp ON sp.PermissionId = p.PermissionId
    JOIN dbo.Screens s ON s.ScreenId = sp.ScreenId
    WHERE v.TenantId=@TenantId
      AND v.UserId=@UserId
      ${orgUnitId ? "AND v.EffectiveOrgUnitId=@OrgUnitId" : ""}
    ORDER BY s.ScreenKey
  `);
  return res.recordset;
}

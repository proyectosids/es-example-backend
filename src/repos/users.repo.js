import { getPool, sql } from "../db/pool.js";

export function normalizeEmail(email) {
  return String(email || "").trim().toUpperCase();
}

export async function findUserForLogin({ tenantCode, emailNormalized }) {
  const pool = await getPool();
  const res = await pool.request()
    .input("TenantCode", sql.NVarChar(50), tenantCode)
    .input("EmailNormalized", sql.NVarChar(254), emailNormalized)
    .query(`
      SELECT TOP 1
        u.UserId,
        u.TenantId,
        u.Email,
        u.EmailNormalized,
        u.PasswordHash,
        u.DisplayName,
        u.FirstName,
        u.LastName,
        u.IsActive,
        t.Code AS TenantCode,
        t.Name AS TenantName
      FROM dbo.Users u
      JOIN dbo.Tenants t ON t.TenantId = u.TenantId
      WHERE t.Code=@TenantCode
        AND u.EmailNormalized=@EmailNormalized
        AND u.IsActive=1
        AND t.Status='ACTIVE'
    `);
  return res.recordset[0] || null;
}

export async function findUserByEmailNormalized({ tenantId, emailNormalized }) {
  const pool = await getPool();
  const res = await pool.request()
    .input("TenantId", sql.UniqueIdentifier, tenantId)
    .input("EmailNormalized", sql.NVarChar(254), emailNormalized)
    .query(`
      SELECT TOP 1
        UserId,
        TenantId,
        Email,
        EmailNormalized,
        DisplayName,
        FirstName,
        LastName,
        Phone,
        IsActive
      FROM dbo.Users
      WHERE TenantId=@TenantId
        AND EmailNormalized=@EmailNormalized
    `);
  return res.recordset[0] || null;
}

export async function getUserById({ tenantId, userId }) {
  const pool = await getPool();
  const res = await pool.request()
    .input("TenantId", sql.UniqueIdentifier, tenantId)
    .input("UserId", sql.UniqueIdentifier, userId)
    .query(`
      SELECT TOP 1
        UserId, TenantId, Email, DisplayName, FirstName, LastName,
        Phone, IsActive, EmailVerifiedAt, LastLoginAt, CreatedAt, UpdatedAt
      FROM dbo.Users
      WHERE TenantId=@TenantId AND UserId=@UserId
    `);
  return res.recordset[0] || null;
}

export async function touchLastLogin({ tenantId, userId }) {
  const pool = await getPool();
  await pool.request()
    .input("TenantId", sql.UniqueIdentifier, tenantId)
    .input("UserId", sql.UniqueIdentifier, userId)
    .query(`
      UPDATE dbo.Users
      SET LastLoginAt=SYSUTCDATETIME(), UpdatedAt=SYSUTCDATETIME()
      WHERE TenantId=@TenantId AND UserId=@UserId
    `);
}

export async function listUserMemberships({ tenantId, userId }) {
  const pool = await getPool();
  const res = await pool.request()
    .input("TenantId", sql.UniqueIdentifier, tenantId)
    .input("UserId", sql.UniqueIdentifier, userId)
    .query(`
      SELECT m.UserOrgMembershipId, m.OrgUnitId, m.MembershipType, m.IsPrimary, m.IsActive,
             o.Name AS OrgUnitName, o.OrgUnitTypeCode
      FROM dbo.UserOrgMemberships m
      JOIN dbo.OrgUnits o ON o.OrgUnitId = m.OrgUnitId
      WHERE m.TenantId=@TenantId AND m.UserId=@UserId
      ORDER BY m.IsPrimary DESC, o.Name
    `);
  return res.recordset;
}

export async function listUserRoleAssignments({ tenantId, userId }) {
  const pool = await getPool();
  const res = await pool.request()
    .input("TenantId", sql.UniqueIdentifier, tenantId)
    .input("UserId", sql.UniqueIdentifier, userId)
    .query(`
      SELECT ura.UserRoleAssignmentId, ura.RoleId, r.Code AS RoleCode, r.Name AS RoleName,
             ura.ScopeOrgUnitId, o.Name AS ScopeOrgUnitName, ura.IsActive, ura.ValidFrom, ura.ValidTo
      FROM dbo.UserRoleAssignments ura
      JOIN dbo.Roles r ON r.RoleId = ura.RoleId
      JOIN dbo.OrgUnits o ON o.OrgUnitId = ura.ScopeOrgUnitId
      WHERE ura.TenantId=@TenantId AND ura.UserId=@UserId
      ORDER BY ura.CreatedAt DESC
    `);
  return res.recordset;
}

export async function listUsersByScope({ tenantId, orgUnitId }) {
  const pool = await getPool();
  const res = await pool.request()
    .input("TenantId", sql.UniqueIdentifier, tenantId)
    .input("OrgUnitId", sql.UniqueIdentifier, orgUnitId)
    .query(`
      SELECT DISTINCT
        u.UserId, u.Email, u.DisplayName, u.FirstName, u.LastName, u.IsActive, u.LastLoginAt,
        m.OrgUnitId, o.Name AS OrgUnitName, o.OrgUnitTypeCode
      FROM dbo.Users u
      JOIN dbo.UserOrgMemberships m
        ON m.TenantId = u.TenantId AND m.UserId = u.UserId AND m.IsActive=1
      JOIN dbo.OrgUnitClosure c
        ON c.TenantId = m.TenantId AND c.DescendantOrgUnitId = m.OrgUnitId
      JOIN dbo.OrgUnits o ON o.OrgUnitId = m.OrgUnitId
      WHERE u.TenantId=@TenantId
        AND u.IsActive=1
        AND c.AncestorOrgUnitId=@OrgUnitId
      ORDER BY u.DisplayName, u.Email
    `);
  return res.recordset;
}

export async function createUser({
  tenantId,
  email,
  emailNormalized,
  passwordHash,
  firstName = null,
  lastName = null,
  displayName = null,
  phone = null
}) {
  const pool = await getPool();
  const res = await pool.request()
    .input("TenantId", sql.UniqueIdentifier, tenantId)
    .input("Email", sql.NVarChar(254), email)
    .input("EmailNormalized", sql.NVarChar(254), emailNormalized)
    .input("PasswordHash", sql.NVarChar(255), passwordHash)
    .input("FirstName", sql.NVarChar(120), firstName)
    .input("LastName", sql.NVarChar(120), lastName)
    .input("DisplayName", sql.NVarChar(200), displayName)
    .input("Phone", sql.NVarChar(40), phone)
    .query(`
      INSERT INTO dbo.Users (
        TenantId, Email, EmailNormalized, PasswordHash, FirstName, LastName, DisplayName, Phone
      )
      OUTPUT INSERTED.UserId, INSERTED.Email, INSERTED.DisplayName, INSERTED.IsActive
      VALUES (
        @TenantId, @Email, @EmailNormalized, @PasswordHash, @FirstName, @LastName, @DisplayName, @Phone
      )
    `);
  return res.recordset[0];
}

export async function addUserMembership({
  tenantId,
  userId,
  orgUnitId,
  membershipType = "MEMBER",
  isPrimary = false
}) {
  const pool = await getPool();
  const res = await pool.request()
    .input("TenantId", sql.UniqueIdentifier, tenantId)
    .input("UserId", sql.UniqueIdentifier, userId)
    .input("OrgUnitId", sql.UniqueIdentifier, orgUnitId)
    .input("MembershipType", sql.NVarChar(40), membershipType)
    .input("IsPrimary", sql.Bit, isPrimary ? 1 : 0)
    .query(`
      INSERT INTO dbo.UserOrgMemberships (
        TenantId, UserId, OrgUnitId, MembershipType, IsPrimary
      )
      OUTPUT INSERTED.UserOrgMembershipId
      VALUES (@TenantId, @UserId, @OrgUnitId, @MembershipType, @IsPrimary)
    `);
  return res.recordset[0];
}

export async function assignRoleToUser({
  tenantId,
  userId,
  roleId,
  scopeOrgUnitId,
  assignedByUserId = null,
  validFrom = null,
  validTo = null
}) {
  const pool = await getPool();
  const res = await pool.request()
    .input("TenantId", sql.UniqueIdentifier, tenantId)
    .input("UserId", sql.UniqueIdentifier, userId)
    .input("RoleId", sql.UniqueIdentifier, roleId)
    .input("ScopeOrgUnitId", sql.UniqueIdentifier, scopeOrgUnitId)
    .input("AssignedByUserId", sql.UniqueIdentifier, assignedByUserId)
    .input("ValidFrom", sql.DateTime2, validFrom ? new Date(validFrom) : null)
    .input("ValidTo", sql.DateTime2, validTo ? new Date(validTo) : null)
    .query(`
      INSERT INTO dbo.UserRoleAssignments (
        TenantId, UserId, RoleId, ScopeOrgUnitId, AssignedByUserId, ValidFrom, ValidTo
      )
      OUTPUT INSERTED.UserRoleAssignmentId
      VALUES (
        @TenantId, @UserId, @RoleId, @ScopeOrgUnitId, @AssignedByUserId, @ValidFrom, @ValidTo
      )
    `);
  return res.recordset[0];
}

export async function getRoleAssignmentById({ tenantId, assignmentId }) {
  const pool = await getPool();
  const res = await pool.request()
    .input("TenantId", sql.UniqueIdentifier, tenantId)
    .input("AssignmentId", sql.UniqueIdentifier, assignmentId)
    .query(`
      SELECT TOP 1 *
      FROM dbo.UserRoleAssignments
      WHERE TenantId=@TenantId AND UserRoleAssignmentId=@AssignmentId
    `);
  return res.recordset[0] || null;
}

export async function deactivateRoleAssignment({ tenantId, assignmentId }) {
  const pool = await getPool();
  await pool.request()
    .input("TenantId", sql.UniqueIdentifier, tenantId)
    .input("AssignmentId", sql.UniqueIdentifier, assignmentId)
    .query(`
      UPDATE dbo.UserRoleAssignments
      SET IsActive=0, UpdatedAt=SYSUTCDATETIME()
      WHERE TenantId=@TenantId AND UserRoleAssignmentId=@AssignmentId
    `);
}

export async function getUserPrimaryChurchMembership({ tenantId, userId }) {
  const pool = await getPool();
  const res = await pool.request()
    .input("TenantId", sql.UniqueIdentifier, tenantId)
    .input("UserId", sql.UniqueIdentifier, userId)
    .query(`
      SELECT TOP 1
        m.UserOrgMembershipId,
        m.OrgUnitId AS ChurchOrgUnitId,
        o.Name AS ChurchName,
        m.MembershipType,
        m.IsPrimary
      FROM dbo.UserOrgMemberships m
      JOIN dbo.OrgUnits o ON o.OrgUnitId = m.OrgUnitId
      WHERE m.TenantId=@TenantId
        AND m.UserId=@UserId
        AND m.IsActive=1
        AND o.OrgUnitTypeCode='CHURCH'
      ORDER BY m.IsPrimary DESC, m.CreatedAt ASC
    `);
  return res.recordset[0] || null;
}

export async function hasActiveMembershipInOrgUnit({ tenantId, userId, orgUnitId }) {
  const pool = await getPool();
  const res = await pool.request()
    .input("TenantId", sql.UniqueIdentifier, tenantId)
    .input("UserId", sql.UniqueIdentifier, userId)
    .input("OrgUnitId", sql.UniqueIdentifier, orgUnitId)
    .query(`
      SELECT TOP 1 1 AS ok
      FROM dbo.UserOrgMemberships
      WHERE TenantId=@TenantId
        AND UserId=@UserId
        AND OrgUnitId=@OrgUnitId
        AND IsActive=1
    `);
  return res.recordset.length > 0;
}

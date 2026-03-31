import { getPool, sql } from "../db/pool.js";

export async function listAssignmentRulesForTarget({
  assignableRoleCode,
  scopeOrgUnitTypeCode
}) {
  const pool = await getPool();
  const res = await pool.request()
    .input("AssignableRoleCode", sql.NVarChar(80), assignableRoleCode)
    .input("ScopeOrgUnitTypeCode", sql.NVarChar(40), scopeOrgUnitTypeCode)
    .query(`
      SELECT
        RoleAssignmentRuleId,
        AssignerRoleCode,
        AssignableRoleCode,
        ScopeOrgUnitTypeCode,
        RequiresSameChurch,
        IsActive
      FROM dbo.RoleAssignmentRules
      WHERE AssignableRoleCode=@AssignableRoleCode
        AND ScopeOrgUnitTypeCode=@ScopeOrgUnitTypeCode
        AND IsActive=1
    `);
  return res.recordset;
}

export async function listUserActiveRoleAssignmentsOverScope({
  tenantId,
  userId,
  roleCode,
  targetScopeOrgUnitId
}) {
  const pool = await getPool();
  const res = await pool.request()
    .input("TenantId", sql.UniqueIdentifier, tenantId)
    .input("UserId", sql.UniqueIdentifier, userId)
    .input("RoleCode", sql.NVarChar(80), roleCode)
    .input("TargetScopeOrgUnitId", sql.UniqueIdentifier, targetScopeOrgUnitId)
    .query(`
      SELECT
        ura.UserRoleAssignmentId,
        ura.ScopeOrgUnitId
      FROM dbo.UserRoleAssignments ura
      JOIN dbo.Roles r
        ON r.RoleId = ura.RoleId
      JOIN dbo.OrgUnitClosure oc
        ON oc.TenantId = ura.TenantId
       AND oc.AncestorOrgUnitId = ura.ScopeOrgUnitId
       AND oc.DescendantOrgUnitId = @TargetScopeOrgUnitId
      WHERE ura.TenantId=@TenantId
        AND ura.UserId=@UserId
        AND ura.IsActive=1
        AND (ura.ValidFrom IS NULL OR ura.ValidFrom <= SYSUTCDATETIME())
        AND (ura.ValidTo IS NULL OR ura.ValidTo >= SYSUTCDATETIME())
        AND r.Code=@RoleCode
    `);
  return res.recordset;
}

export async function getNearestChurchOrgUnitId({ tenantId, orgUnitId }) {
  const pool = await getPool();
  const res = await pool.request()
    .input("TenantId", sql.UniqueIdentifier, tenantId)
    .input("OrgUnitId", sql.UniqueIdentifier, orgUnitId)
    .query(`
      SELECT TOP 1 oc.AncestorOrgUnitId AS ChurchOrgUnitId
      FROM dbo.OrgUnitClosure oc
      JOIN dbo.OrgUnits o
        ON o.OrgUnitId = oc.AncestorOrgUnitId
      WHERE oc.TenantId=@TenantId
        AND oc.DescendantOrgUnitId=@OrgUnitId
        AND o.OrgUnitTypeCode='CHURCH'
      ORDER BY oc.Depth ASC
    `);
  return res.recordset[0]?.ChurchOrgUnitId || null;
}

export async function hasActiveRoleOverScope({
  tenantId,
  userId,
  roleCode,
  targetScopeOrgUnitId
}) {
  const assignments = await listUserActiveRoleAssignmentsOverScope({
    tenantId,
    userId,
    roleCode,
    targetScopeOrgUnitId
  });
  return assignments.length > 0;
}

export async function canUserAssignRoleAtScope({
  tenantId,
  assignerUserId,
  assignableRoleCode,
  targetScopeOrgUnitId
}) {
  const pool = await getPool();
  const targetRes = await pool.request()
    .input("TenantId", sql.UniqueIdentifier, tenantId)
    .input("OrgUnitId", sql.UniqueIdentifier, targetScopeOrgUnitId)
    .query(`
      SELECT TOP 1 OrgUnitId, OrgUnitTypeCode
      FROM dbo.OrgUnits
      WHERE TenantId=@TenantId
        AND OrgUnitId=@OrgUnitId
        AND IsActive=1
    `);
  const targetScope = targetRes.recordset[0];
  if (!targetScope) {
    return { ok: false, reason: "Scope org unit not found" };
  }

  const rules = await listAssignmentRulesForTarget({
    assignableRoleCode,
    scopeOrgUnitTypeCode: targetScope.OrgUnitTypeCode
  });
  if (!rules.length) {
    return { ok: true, enforced: false };
  }

  const targetChurchId = await getNearestChurchOrgUnitId({
    tenantId,
    orgUnitId: targetScopeOrgUnitId
  });

  for (const rule of rules) {
    const assignments = await listUserActiveRoleAssignmentsOverScope({
      tenantId,
      userId: assignerUserId,
      roleCode: rule.AssignerRoleCode,
      targetScopeOrgUnitId
    });
    if (!assignments.length) continue;

    if (!rule.RequiresSameChurch) {
      return { ok: true, enforced: true };
    }

    for (const assignment of assignments) {
      const assignerChurchId = await getNearestChurchOrgUnitId({
        tenantId,
        orgUnitId: assignment.ScopeOrgUnitId
      });
      if (
        assignerChurchId &&
        targetChurchId &&
        String(assignerChurchId).toLowerCase() === String(targetChurchId).toLowerCase()
      ) {
        return { ok: true, enforced: true };
      }
    }
  }

  return { ok: false, reason: "Assignment blocked by role governance rules", enforced: true };
}

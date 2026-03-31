import { getPool, sql } from "../db/pool.js";

export async function getQuarterlyMembershipPolicy({ tenantId, quarterlyId }) {
  const pool = await getPool();
  const res = await pool.request()
    .input("TenantId", sql.UniqueIdentifier, tenantId)
    .input("QuarterlyId", sql.NVarChar(30), quarterlyId)
    .query(`
      SELECT TOP 1
        TenantId,
        QuarterlyId,
        ChangeOpenAt,
        ChangeCloseAt,
        RequireLeaderApproval,
        CreatedAt,
        UpdatedAt
      FROM dbo.QuarterlyMembershipPolicy
      WHERE TenantId=@TenantId
        AND QuarterlyId=@QuarterlyId
    `);
  return res.recordset[0] || null;
}

export async function upsertQuarterlyMembershipPolicy({
  tenantId,
  quarterlyId,
  changeOpenAt = null,
  changeCloseAt = null,
  requireLeaderApproval = true
}) {
  const pool = await getPool();
  const res = await pool.request()
    .input("TenantId", sql.UniqueIdentifier, tenantId)
    .input("QuarterlyId", sql.NVarChar(30), quarterlyId)
    .input("ChangeOpenAt", sql.DateTime2, changeOpenAt ? new Date(changeOpenAt) : null)
    .input("ChangeCloseAt", sql.DateTime2, changeCloseAt ? new Date(changeCloseAt) : null)
    .input("RequireLeaderApproval", sql.Bit, requireLeaderApproval ? 1 : 0)
    .query(`
      MERGE dbo.QuarterlyMembershipPolicy AS target
      USING (
        SELECT
          @TenantId AS TenantId,
          @QuarterlyId AS QuarterlyId
      ) AS source
      ON target.TenantId = source.TenantId
      AND target.QuarterlyId = source.QuarterlyId
      WHEN MATCHED THEN
        UPDATE SET
          ChangeOpenAt=@ChangeOpenAt,
          ChangeCloseAt=@ChangeCloseAt,
          RequireLeaderApproval=@RequireLeaderApproval,
          UpdatedAt=SYSUTCDATETIME()
      WHEN NOT MATCHED THEN
        INSERT (
          TenantId,
          QuarterlyId,
          ChangeOpenAt,
          ChangeCloseAt,
          RequireLeaderApproval
        )
        VALUES (
          @TenantId,
          @QuarterlyId,
          @ChangeOpenAt,
          @ChangeCloseAt,
          @RequireLeaderApproval
        )
      OUTPUT
        INSERTED.TenantId,
        INSERTED.QuarterlyId,
        INSERTED.ChangeOpenAt,
        INSERTED.ChangeCloseAt,
        INSERTED.RequireLeaderApproval,
        INSERTED.CreatedAt,
        INSERTED.UpdatedAt;
    `);
  return res.recordset[0] || null;
}

export function evaluateQuarterlyMembershipPolicy(policy, now = new Date()) {
  if (!policy) {
    return {
      isConfigured: false,
      isOpen: true,
      status: "OPEN",
      reason: null,
      requireLeaderApproval: true
    };
  }

  const openAt = policy.ChangeOpenAt ? new Date(policy.ChangeOpenAt) : null;
  const closeAt = policy.ChangeCloseAt ? new Date(policy.ChangeCloseAt) : null;

  if (openAt && now < openAt) {
    return {
      isConfigured: true,
      isOpen: false,
      status: "NOT_OPEN_YET",
      reason: "Change window has not opened yet",
      requireLeaderApproval: Boolean(policy.RequireLeaderApproval)
    };
  }

  if (closeAt && now > closeAt) {
    return {
      isConfigured: true,
      isOpen: false,
      status: "CLOSED",
      reason: "Change window is closed",
      requireLeaderApproval: Boolean(policy.RequireLeaderApproval)
    };
  }

  return {
    isConfigured: true,
    isOpen: true,
    status: "OPEN",
    reason: null,
    requireLeaderApproval: Boolean(policy.RequireLeaderApproval)
  };
}


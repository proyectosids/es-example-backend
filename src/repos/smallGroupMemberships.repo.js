import { getPool, sql } from "../db/pool.js";

export async function getUserMembershipByQuarter({ tenantId, userId, quarterlyId }) {
  const pool = await getPool();
  const res = await pool.request()
    .input("TenantId", sql.UniqueIdentifier, tenantId)
    .input("UserId", sql.UniqueIdentifier, userId)
    .input("QuarterlyId", sql.NVarChar(30), quarterlyId)
    .query(`
      SELECT TOP 1
        SmallGroupMembershipId,
        TenantId,
        UserId,
        ChurchOrgUnitId,
        SmallGroupOrgUnitId,
        QuarterlyId,
        Status,
        RequestedByUserId,
        ApprovedByUserId,
        RequestedAt,
        DecidedAt,
        Notes,
        IsActive
      FROM dbo.SmallGroupMemberships
      WHERE TenantId=@TenantId
        AND UserId=@UserId
        AND QuarterlyId=@QuarterlyId
        AND IsActive=1
      ORDER BY
        CASE Status WHEN 'APPROVED' THEN 1 WHEN 'PENDING' THEN 2 ELSE 3 END,
        RequestedAt DESC
    `);
  return res.recordset[0] || null;
}

export async function createPendingMembershipRequest({
  tenantId,
  userId,
  churchOrgUnitId,
  smallGroupOrgUnitId,
  quarterlyId,
  requestedByUserId,
  status = "PENDING",
  approvedByUserId = null,
  decidedAt = null,
  notes = null
}) {
  const pool = await getPool();
  const res = await pool.request()
    .input("TenantId", sql.UniqueIdentifier, tenantId)
    .input("UserId", sql.UniqueIdentifier, userId)
    .input("ChurchOrgUnitId", sql.UniqueIdentifier, churchOrgUnitId)
    .input("SmallGroupOrgUnitId", sql.UniqueIdentifier, smallGroupOrgUnitId)
    .input("QuarterlyId", sql.NVarChar(30), quarterlyId)
    .input("RequestedByUserId", sql.UniqueIdentifier, requestedByUserId)
    .input("Status", sql.NVarChar(20), status)
    .input("ApprovedByUserId", sql.UniqueIdentifier, approvedByUserId)
    .input("DecidedAt", sql.DateTime2, decidedAt ? new Date(decidedAt) : null)
    .input("Notes", sql.NVarChar(500), notes)
    .query(`
      INSERT INTO dbo.SmallGroupMemberships (
        TenantId, UserId, ChurchOrgUnitId, SmallGroupOrgUnitId, QuarterlyId,
        Status, RequestedByUserId, ApprovedByUserId, DecidedAt, Notes
      )
      OUTPUT
        INSERTED.SmallGroupMembershipId,
        INSERTED.UserId,
        INSERTED.SmallGroupOrgUnitId,
        INSERTED.QuarterlyId,
        INSERTED.Status,
        INSERTED.RequestedAt,
        INSERTED.DecidedAt
      VALUES (
        @TenantId, @UserId, @ChurchOrgUnitId, @SmallGroupOrgUnitId, @QuarterlyId,
        @Status, @RequestedByUserId, @ApprovedByUserId, @DecidedAt, @Notes
      )
    `);
  return res.recordset[0];
}

export async function listPendingRequestsBySmallGroup({
  tenantId,
  smallGroupOrgUnitId,
  quarterlyId
}) {
  const pool = await getPool();
  const res = await pool.request()
    .input("TenantId", sql.UniqueIdentifier, tenantId)
    .input("SmallGroupOrgUnitId", sql.UniqueIdentifier, smallGroupOrgUnitId)
    .input("QuarterlyId", sql.NVarChar(30), quarterlyId)
    .query(`
      SELECT
        sgm.SmallGroupMembershipId,
        sgm.UserId,
        sgm.QuarterlyId,
        sgm.Status,
        sgm.RequestedAt,
        u.DisplayName,
        u.FirstName,
        u.LastName,
        u.Email
      FROM dbo.SmallGroupMemberships sgm
      JOIN dbo.Users u
        ON u.TenantId = sgm.TenantId
       AND u.UserId = sgm.UserId
      WHERE sgm.TenantId=@TenantId
        AND sgm.SmallGroupOrgUnitId=@SmallGroupOrgUnitId
        AND sgm.QuarterlyId=@QuarterlyId
        AND sgm.IsActive=1
        AND sgm.Status='PENDING'
      ORDER BY sgm.RequestedAt ASC
    `);
  return res.recordset;
}

export async function getRequestById({ tenantId, requestId }) {
  const pool = await getPool();
  const res = await pool.request()
    .input("TenantId", sql.UniqueIdentifier, tenantId)
    .input("RequestId", sql.UniqueIdentifier, requestId)
    .query(`
      SELECT TOP 1 *
      FROM dbo.SmallGroupMemberships
      WHERE TenantId=@TenantId
        AND SmallGroupMembershipId=@RequestId
        AND IsActive=1
    `);
  return res.recordset[0] || null;
}

export async function approveRequest({
  tenantId,
  requestId,
  approvedByUserId,
  notes = null
}) {
  const pool = await getPool();
  const tx = new sql.Transaction(pool);
  await tx.begin();
  try {
    const currentRes = await new sql.Request(tx)
      .input("TenantId", sql.UniqueIdentifier, tenantId)
      .input("RequestId", sql.UniqueIdentifier, requestId)
      .query(`
        SELECT TOP 1 *
        FROM dbo.SmallGroupMemberships
        WHERE TenantId=@TenantId
          AND SmallGroupMembershipId=@RequestId
          AND IsActive=1
      `);
    const request = currentRes.recordset[0];
    if (!request) {
      await tx.rollback();
      return null;
    }

    await new sql.Request(tx)
      .input("TenantId", sql.UniqueIdentifier, tenantId)
      .input("UserId", sql.UniqueIdentifier, request.UserId)
      .input("QuarterlyId", sql.NVarChar(30), request.QuarterlyId)
      .input("KeepRequestId", sql.UniqueIdentifier, request.SmallGroupMembershipId)
      .query(`
        UPDATE dbo.SmallGroupMemberships
        SET Status='CANCELLED',
            IsActive=0,
            DecidedAt=SYSUTCDATETIME()
        WHERE TenantId=@TenantId
          AND UserId=@UserId
          AND QuarterlyId=@QuarterlyId
          AND IsActive=1
          AND Status='PENDING'
          AND SmallGroupMembershipId<>@KeepRequestId
      `);

    const updateRes = await new sql.Request(tx)
      .input("TenantId", sql.UniqueIdentifier, tenantId)
      .input("RequestId", sql.UniqueIdentifier, requestId)
      .input("ApprovedByUserId", sql.UniqueIdentifier, approvedByUserId)
      .input("Notes", sql.NVarChar(500), notes)
      .query(`
        UPDATE dbo.SmallGroupMemberships
        SET Status='APPROVED',
            ApprovedByUserId=@ApprovedByUserId,
            DecidedAt=SYSUTCDATETIME(),
            Notes=COALESCE(@Notes, Notes)
        OUTPUT INSERTED.SmallGroupMembershipId, INSERTED.Status, INSERTED.DecidedAt
        WHERE TenantId=@TenantId
          AND SmallGroupMembershipId=@RequestId
          AND IsActive=1
          AND Status='PENDING'
      `);

    await tx.commit();
    return updateRes.recordset[0] || null;
  } catch (err) {
    await tx.rollback();
    throw err;
  }
}

export async function rejectRequest({
  tenantId,
  requestId,
  approvedByUserId,
  notes = null
}) {
  const pool = await getPool();
  const res = await pool.request()
    .input("TenantId", sql.UniqueIdentifier, tenantId)
    .input("RequestId", sql.UniqueIdentifier, requestId)
    .input("ApprovedByUserId", sql.UniqueIdentifier, approvedByUserId)
    .input("Notes", sql.NVarChar(500), notes)
    .query(`
      UPDATE dbo.SmallGroupMemberships
      SET Status='REJECTED',
          ApprovedByUserId=@ApprovedByUserId,
          DecidedAt=SYSUTCDATETIME(),
          Notes=COALESCE(@Notes, Notes)
      OUTPUT INSERTED.SmallGroupMembershipId, INSERTED.Status, INSERTED.DecidedAt
      WHERE TenantId=@TenantId
        AND SmallGroupMembershipId=@RequestId
        AND IsActive=1
        AND Status='PENDING'
    `);
  return res.recordset[0] || null;
}

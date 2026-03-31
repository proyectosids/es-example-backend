import { getPool, sql } from "../db/pool.js";

export async function recordAuditEvent({
  tenantId,
  actorUserId = null,
  actionCode,
  entityType,
  entityId = null,
  targetOrgUnitId = null,
  outcome = "SUCCESS",
  metadata = null
}) {
  const pool = await getPool();
  const metadataJson = metadata ? JSON.stringify(metadata) : null;

  const res = await pool.request()
    .input("TenantId", sql.UniqueIdentifier, tenantId)
    .input("ActorUserId", sql.UniqueIdentifier, actorUserId)
    .input("ActionCode", sql.NVarChar(120), actionCode)
    .input("EntityType", sql.NVarChar(80), entityType)
    .input("EntityId", sql.NVarChar(120), entityId)
    .input("TargetOrgUnitId", sql.UniqueIdentifier, targetOrgUnitId)
    .input("Outcome", sql.NVarChar(20), outcome)
    .input("MetadataJson", sql.NVarChar(sql.MAX), metadataJson)
    .query(`
      INSERT INTO dbo.AuditEvents (
        TenantId,
        ActorUserId,
        ActionCode,
        EntityType,
        EntityId,
        TargetOrgUnitId,
        Outcome,
        MetadataJson
      )
      OUTPUT INSERTED.AuditEventId, INSERTED.ActionCode, INSERTED.EntityType, INSERTED.CreatedAt
      VALUES (
        @TenantId,
        @ActorUserId,
        @ActionCode,
        @EntityType,
        @EntityId,
        @TargetOrgUnitId,
        @Outcome,
        @MetadataJson
      )
    `);
  return res.recordset[0] || null;
}

export async function listAuditEvents({
  tenantId,
  actionCode = null,
  actorUserId = null,
  entityType = null,
  entityId = null,
  top = 100
}) {
  const pool = await getPool();
  const req = pool.request()
    .input("TenantId", sql.UniqueIdentifier, tenantId)
    .input("TopN", sql.Int, top);

  if (actionCode) req.input("ActionCode", sql.NVarChar(120), actionCode);
  if (actorUserId) req.input("ActorUserId", sql.UniqueIdentifier, actorUserId);
  if (entityType) req.input("EntityType", sql.NVarChar(80), entityType);
  if (entityId) req.input("EntityId", sql.NVarChar(120), entityId);

  const res = await req.query(`
    SELECT TOP (@TopN)
      AuditEventId,
      TenantId,
      ActorUserId,
      ActionCode,
      EntityType,
      EntityId,
      TargetOrgUnitId,
      Outcome,
      MetadataJson,
      CreatedAt
    FROM dbo.AuditEvents
    WHERE TenantId=@TenantId
      ${actionCode ? "AND ActionCode=@ActionCode" : ""}
      ${actorUserId ? "AND ActorUserId=@ActorUserId" : ""}
      ${entityType ? "AND EntityType=@EntityType" : ""}
      ${entityId ? "AND EntityId=@EntityId" : ""}
    ORDER BY CreatedAt DESC
  `);
  return res.recordset;
}


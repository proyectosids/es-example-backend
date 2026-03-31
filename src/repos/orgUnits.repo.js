import { getPool, sql } from "../db/pool.js";

export async function getOrgUnitById({ tenantId, orgUnitId }) {
  const pool = await getPool();
  const res = await pool.request()
    .input("TenantId", sql.UniqueIdentifier, tenantId)
    .input("OrgUnitId", sql.UniqueIdentifier, orgUnitId)
    .query(`
      SELECT TOP 1 *
      FROM dbo.OrgUnits
      WHERE TenantId=@TenantId AND OrgUnitId=@OrgUnitId
    `);
  return res.recordset[0] || null;
}

export async function listOrgUnits({ tenantId, parentOrgUnitId = null, orgUnitTypeCode = null }) {
  const pool = await getPool();
  const req = pool.request()
    .input("TenantId", sql.UniqueIdentifier, tenantId);

  if (parentOrgUnitId) req.input("ParentOrgUnitId", sql.UniqueIdentifier, parentOrgUnitId);
  if (orgUnitTypeCode) req.input("OrgUnitTypeCode", sql.NVarChar(40), orgUnitTypeCode);

  const res = await req.query(`
    SELECT OrgUnitId, TenantId, OrgUnitTypeCode, ParentOrgUnitId, Code, Name, Path, IsActive, CreatedAt, UpdatedAt
    FROM dbo.OrgUnits
    WHERE TenantId=@TenantId
      ${parentOrgUnitId ? "AND ParentOrgUnitId=@ParentOrgUnitId" : ""}
      ${orgUnitTypeCode ? "AND OrgUnitTypeCode=@OrgUnitTypeCode" : ""}
    ORDER BY Name
  `);
  return res.recordset;
}

export async function createOrgUnit({
  tenantId,
  orgUnitTypeCode,
  parentOrgUnitId = null,
  code,
  name,
  path = null
}) {
  const pool = await getPool();
  const tx = new sql.Transaction(pool);
  await tx.begin();
  try {
    const insertRes = await new sql.Request(tx)
      .input("TenantId", sql.UniqueIdentifier, tenantId)
      .input("OrgUnitTypeCode", sql.NVarChar(40), orgUnitTypeCode)
      .input("ParentOrgUnitId", sql.UniqueIdentifier, parentOrgUnitId)
      .input("Code", sql.NVarChar(80), code)
      .input("Name", sql.NVarChar(200), name)
      .input("Path", sql.NVarChar(900), path)
      .query(`
        INSERT INTO dbo.OrgUnits (TenantId, OrgUnitTypeCode, ParentOrgUnitId, Code, Name, Path)
        OUTPUT INSERTED.OrgUnitId, INSERTED.TenantId, INSERTED.OrgUnitTypeCode, INSERTED.ParentOrgUnitId, INSERTED.Code, INSERTED.Name, INSERTED.Path, INSERTED.IsActive
        VALUES (@TenantId, @OrgUnitTypeCode, @ParentOrgUnitId, @Code, @Name, @Path)
      `);

    const created = insertRes.recordset[0];

    await new sql.Request(tx)
      .input("TenantId", sql.UniqueIdentifier, tenantId)
      .input("NewOrgUnitId", sql.UniqueIdentifier, created.OrgUnitId)
      .query(`
        INSERT INTO dbo.OrgUnitClosure (TenantId, AncestorOrgUnitId, DescendantOrgUnitId, Depth)
        VALUES (@TenantId, @NewOrgUnitId, @NewOrgUnitId, 0)
      `);

    if (parentOrgUnitId) {
      await new sql.Request(tx)
        .input("TenantId", sql.UniqueIdentifier, tenantId)
        .input("ParentOrgUnitId", sql.UniqueIdentifier, parentOrgUnitId)
        .input("NewOrgUnitId", sql.UniqueIdentifier, created.OrgUnitId)
        .query(`
          INSERT INTO dbo.OrgUnitClosure (TenantId, AncestorOrgUnitId, DescendantOrgUnitId, Depth)
          SELECT TenantId, AncestorOrgUnitId, @NewOrgUnitId, Depth + 1
          FROM dbo.OrgUnitClosure
          WHERE TenantId=@TenantId AND DescendantOrgUnitId=@ParentOrgUnitId
        `);
    }

    await tx.commit();
    return created;
  } catch (err) {
    await tx.rollback();
    throw err;
  }
}

export async function updateOrgUnit({
  tenantId,
  orgUnitId,
  name = null,
  isActive = null,
  path = null
}) {
  const pool = await getPool();
  const req = pool.request()
    .input("TenantId", sql.UniqueIdentifier, tenantId)
    .input("OrgUnitId", sql.UniqueIdentifier, orgUnitId)
    .input("Name", sql.NVarChar(200), name)
    .input("IsActive", sql.Bit, isActive === null ? null : (isActive ? 1 : 0))
    .input("Path", sql.NVarChar(900), path);

  const res = await req.query(`
    UPDATE dbo.OrgUnits
      SET Name = COALESCE(@Name, Name),
          Path = COALESCE(@Path, Path),
          IsActive = COALESCE(@IsActive, IsActive),
          UpdatedAt = SYSUTCDATETIME()
    OUTPUT INSERTED.OrgUnitId, INSERTED.Name, INSERTED.IsActive, INSERTED.Path, INSERTED.UpdatedAt
    WHERE TenantId=@TenantId AND OrgUnitId=@OrgUnitId
  `);
  return res.recordset[0] || null;
}

export async function listOrgUnitsByTypeAndParent({
  tenantId,
  orgUnitTypeCode,
  parentOrgUnitId = null
}) {
  const pool = await getPool();
  const req = pool.request()
    .input("TenantId", sql.UniqueIdentifier, tenantId)
    .input("OrgUnitTypeCode", sql.NVarChar(40), orgUnitTypeCode);

  if (parentOrgUnitId) {
    req.input("ParentOrgUnitId", sql.UniqueIdentifier, parentOrgUnitId);
  }

  const res = await req.query(`
    SELECT OrgUnitId, OrgUnitTypeCode, ParentOrgUnitId, Code, Name, Path, IsActive
    FROM dbo.OrgUnits
    WHERE TenantId=@TenantId
      AND OrgUnitTypeCode=@OrgUnitTypeCode
      AND IsActive=1
      ${parentOrgUnitId ? "AND ParentOrgUnitId=@ParentOrgUnitId" : "AND ParentOrgUnitId IS NULL"}
    ORDER BY Name
  `);
  return res.recordset;
}

export async function getOrgUnitByIdAndType({ tenantId, orgUnitId, orgUnitTypeCode }) {
  const pool = await getPool();
  const res = await pool.request()
    .input("TenantId", sql.UniqueIdentifier, tenantId)
    .input("OrgUnitId", sql.UniqueIdentifier, orgUnitId)
    .input("OrgUnitTypeCode", sql.NVarChar(40), orgUnitTypeCode)
    .query(`
      SELECT TOP 1 OrgUnitId, TenantId, OrgUnitTypeCode, ParentOrgUnitId, Code, Name, Path, IsActive
      FROM dbo.OrgUnits
      WHERE TenantId=@TenantId
        AND OrgUnitId=@OrgUnitId
        AND OrgUnitTypeCode=@OrgUnitTypeCode
        AND IsActive=1
    `);
  return res.recordset[0] || null;
}

export async function isOrgUnitDescendantOf({
  tenantId,
  ancestorOrgUnitId,
  descendantOrgUnitId
}) {
  const pool = await getPool();
  const res = await pool.request()
    .input("TenantId", sql.UniqueIdentifier, tenantId)
    .input("AncestorOrgUnitId", sql.UniqueIdentifier, ancestorOrgUnitId)
    .input("DescendantOrgUnitId", sql.UniqueIdentifier, descendantOrgUnitId)
    .query(`
      SELECT TOP 1 1 AS ok
      FROM dbo.OrgUnitClosure
      WHERE TenantId=@TenantId
        AND AncestorOrgUnitId=@AncestorOrgUnitId
        AND DescendantOrgUnitId=@DescendantOrgUnitId
    `);
  return res.recordset.length > 0;
}

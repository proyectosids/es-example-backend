import { getPool, sql } from "../db/pool.js";

export async function findActiveTenantByCode(tenantCode) {
  const pool = await getPool();
  const res = await pool.request()
    .input("Code", sql.NVarChar(50), String(tenantCode || "").trim())
    .query(`
      SELECT TOP 1 TenantId, Code, Name, Status
      FROM dbo.Tenants
      WHERE Code=@Code
        AND Status='ACTIVE'
    `);
  return res.recordset[0] || null;
}


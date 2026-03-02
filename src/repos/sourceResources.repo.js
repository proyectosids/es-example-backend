import { getPool, sql } from "../db/pool.js";

// export async function getSourceMeta(resourceKey) {
//     const pool = await getPool();
//     const res = await pool.request()
//         .input("ResourceKey", sql.NVarChar(300), resourceKey)
//         .query(`SELECT TOP 1 * FROM dbo.SourceResources WHERE ResourceKey=@ResourceKey`);
//     return res.recordset[0] || null;
// }

export async function getSourceMeta(resourceKey) {
  const pool = await getPool();
  const res = await pool.request()
    .input("ResourceKey", sql.NVarChar(300), resourceKey)
    .query(`
      SELECT *
      FROM dbo.SourceResources
      WHERE ResourceKey = @ResourceKey
    `);

  return res.recordset[0] || null;
}


export async function upsertSourceMeta({ resourceKey, url, etag, lastModified, contentHash, rawJson }) {
  const pool = await getPool();
  await pool.request()
    .input("ResourceKey", sql.NVarChar(300), resourceKey)
    .input("Url", sql.NVarChar(700), url)
    .input("ETag", sql.NVarChar(120), etag)
    .input("LastModified", sql.NVarChar(120), lastModified)
    .input("ContentHash", sql.VarBinary(32), contentHash)
    .input("RawJson", sql.NVarChar(sql.MAX), rawJson)
    .query(`
      MERGE dbo.SourceResources AS T
      USING (SELECT @ResourceKey AS ResourceKey) AS S
      ON (T.ResourceKey = S.ResourceKey)
      WHEN MATCHED THEN
        UPDATE SET Url=@Url, ETag=@ETag, LastModified=@LastModified, ContentHash=@ContentHash, RawJson = @RawJson, UpdatedAt=SYSUTCDATETIME()
      WHEN NOT MATCHED THEN
        INSERT (ResourceKey, Url, ETag, LastModified, ContentHash,RawJson)
        VALUES (@ResourceKey, @Url, @ETag, @LastModified, @ContentHash, @RawJson);
    `);
}

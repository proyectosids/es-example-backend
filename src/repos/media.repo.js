import { getPool, sql } from "../db/pool.js";

export async function upsertMedia({ lang, quarterlyId, mediaType, rawJson }) {
    const pool = await getPool();
    await pool.request()
        .input("Lang", sql.NVarChar(10), lang)
        .input("QuarterlyId", sql.NVarChar(30), quarterlyId)
        .input("MediaType", sql.NVarChar(10), mediaType)
        .input("RawJson", sql.NVarChar(sql.MAX), rawJson)
        .query(`
      MERGE dbo.QuarterlyMedia AS T
      USING (SELECT @Lang AS Lang, @QuarterlyId AS QuarterlyId, @MediaType AS MediaType) AS S
      ON (T.Lang=S.Lang AND T.QuarterlyId=S.QuarterlyId AND T.MediaType=S.MediaType)
      WHEN MATCHED THEN
        UPDATE SET RawJson=@RawJson, UpdatedAt=SYSUTCDATETIME()
      WHEN NOT MATCHED THEN
        INSERT (Lang, QuarterlyId, MediaType, RawJson)
        VALUES (@Lang, @QuarterlyId, @MediaType, @RawJson);
    `);
}

export async function getMedia(lang, quarterlyId, mediaType) {
    const pool = await getPool();
    const res = await pool.request()
        .input("Lang", sql.NVarChar(10), lang)
        .input("QuarterlyId", sql.NVarChar(30), quarterlyId)
        .input("MediaType", sql.NVarChar(10), mediaType)
        .query(`
      SELECT * FROM dbo.QuarterlyMedia
      WHERE Lang=@Lang AND QuarterlyId=@QuarterlyId AND MediaType=@MediaType
    `);
    return res.recordset[0] || null;
}

import { getPool, sql } from "../db/pool.js";

export async function upsertQuarterly({ lang, quarterlyId, title, coverUrl, startDate, endDate, rawJson }) {
    const pool = await getPool();
    await pool.request()
        .input("Lang", sql.NVarChar(10), lang)
        .input("QuarterlyId", sql.NVarChar(30), quarterlyId)
        .input("Title", sql.NVarChar(250), title)
        .input("CoverUrl", sql.NVarChar(600), coverUrl)
        .input("StartDate", sql.Date, startDate)
        .input("EndDate", sql.Date, endDate)
        .input("RawJson", sql.NVarChar(sql.MAX), rawJson)
        .query(`
      MERGE dbo.Quarterlies AS T
      USING (SELECT @Lang AS Lang, @QuarterlyId AS QuarterlyId) AS S
      ON (T.Lang=S.Lang AND T.QuarterlyId=S.QuarterlyId)
      WHEN MATCHED THEN
        UPDATE SET Title=@Title, CoverUrl=@CoverUrl, StartDate=@StartDate, EndDate=@EndDate, RawJson=@RawJson, UpdatedAt=SYSUTCDATETIME()
      WHEN NOT MATCHED THEN
        INSERT (Lang, QuarterlyId, Title, CoverUrl, StartDate, EndDate, RawJson)
        VALUES (@Lang, @QuarterlyId, @Title, @CoverUrl, @StartDate, @EndDate, @RawJson);
    `);
}

export async function listQuarterlies(lang) {
    const pool = await getPool();
    const res = await pool.request()
        .input("Lang", sql.NVarChar(10), lang)
        .query(`
      SELECT QuarterlyId, Title, CoverUrl, StartDate, EndDate, UpdatedAt
      FROM dbo.Quarterlies
      WHERE Lang=@Lang
      ORDER BY StartDate DESC
    `);
    return res.recordset;
}

export async function getQuarterly(lang, quarterlyId) {
    const pool = await getPool();
    const res = await pool.request()
        .input("Lang", sql.NVarChar(10), lang)
        .input("QuarterlyId", sql.NVarChar(30), quarterlyId)
        .query(`SELECT * FROM dbo.Quarterlies WHERE Lang=@Lang AND QuarterlyId=@QuarterlyId`);
    return res.recordset[0] || null;
}

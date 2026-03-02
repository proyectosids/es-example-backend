import { getPool, sql } from "../db/pool.js";

export async function upsertDayRead({ lang, quarterlyId, lessonId, dayId, dayDate, title, readJson }) {
    const pool = await getPool();
    await pool.request()
        .input("Lang", sql.NVarChar(10), lang)
        .input("QuarterlyId", sql.NVarChar(30), quarterlyId)
        .input("LessonId", sql.NVarChar(10), lessonId)
        .input("DayId", sql.NVarChar(10), dayId)
        .input("DayDate", sql.Date, dayDate)
        .input("Title", sql.NVarChar(250), title)
        .input("ReadJson", sql.NVarChar(sql.MAX), readJson)
        .query(`
      MERGE dbo.DayReads AS T
      USING (SELECT @Lang AS Lang, @QuarterlyId AS QuarterlyId, @LessonId AS LessonId, @DayId AS DayId) AS S
      ON (T.Lang=S.Lang AND T.QuarterlyId=S.QuarterlyId AND T.LessonId=S.LessonId AND T.DayId=S.DayId)
      WHEN MATCHED THEN
        UPDATE SET DayDate=@DayDate, Title=@Title, ReadJson=@ReadJson, UpdatedAt=SYSUTCDATETIME()
      WHEN NOT MATCHED THEN
        INSERT (Lang, QuarterlyId, LessonId, DayId, DayDate, Title, ReadJson)
        VALUES (@Lang, @QuarterlyId, @LessonId, @DayId, @DayDate, @Title, @ReadJson);
    `);
}

export async function listDays(lang, quarterlyId, lessonId) {
    const pool = await getPool();
    const res = await pool.request()
        .input("Lang", sql.NVarChar(10), lang)
        .input("QuarterlyId", sql.NVarChar(30), quarterlyId)
        .input("LessonId", sql.NVarChar(10), lessonId)
        .query(`
      SELECT DayId, DayDate, Title, UpdatedAt
      FROM dbo.DayReads
      WHERE Lang=@Lang AND QuarterlyId=@QuarterlyId AND LessonId=@LessonId
      ORDER BY DayId
    `);
    return res.recordset;
}

export async function getDayRead(lang, quarterlyId, lessonId, dayId) {
    const pool = await getPool();
    const res = await pool.request()
        .input("Lang", sql.NVarChar(10), lang)
        .input("QuarterlyId", sql.NVarChar(30), quarterlyId)
        .input("LessonId", sql.NVarChar(10), lessonId)
        .input("DayId", sql.NVarChar(10), dayId)
        .query(`
      SELECT * FROM dbo.DayReads
      WHERE Lang=@Lang AND QuarterlyId=@QuarterlyId AND LessonId=@LessonId AND DayId=@DayId
    `);
    return res.recordset[0] || null;
}

export async function getChangedDayReads(lang, sinceIso) {
    const pool = await getPool();
    const res = await pool.request()
        .input("Lang", sql.NVarChar(10), lang)
        .input("Since", sql.DateTime2, new Date(sinceIso))
        .query(`
      SELECT QuarterlyId, LessonId, DayId, UpdatedAt
      FROM dbo.DayReads
      WHERE Lang=@Lang AND UpdatedAt > @Since
      ORDER BY UpdatedAt ASC
    `);
    return res.recordset;
}

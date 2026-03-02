import { getPool, sql } from "../db/pool.js";

export async function upsertLesson({ lang, quarterlyId, lessonId, title, startDate, endDate, rawJson }) {
    const pool = await getPool();
    await pool.request()
        .input("Lang", sql.NVarChar(10), lang)
        .input("QuarterlyId", sql.NVarChar(30), quarterlyId)
        .input("LessonId", sql.NVarChar(10), lessonId)
        .input("Title", sql.NVarChar(250), title)
        .input("StartDate", sql.Date, startDate)
        .input("EndDate", sql.Date, endDate)
        .input("RawJson", sql.NVarChar(sql.MAX), rawJson)
        .query(`
      MERGE dbo.Lessons AS T
      USING (SELECT @Lang AS Lang, @QuarterlyId AS QuarterlyId, @LessonId AS LessonId) AS S
      ON (T.Lang=S.Lang AND T.QuarterlyId=S.QuarterlyId AND T.LessonId=S.LessonId)
      WHEN MATCHED THEN
        UPDATE SET Title=@Title, StartDate=@StartDate, EndDate=@EndDate, RawJson=@RawJson, UpdatedAt=SYSUTCDATETIME()
      WHEN NOT MATCHED THEN
        INSERT (Lang, QuarterlyId, LessonId, Title, StartDate, EndDate, RawJson)
        VALUES (@Lang, @QuarterlyId, @LessonId, @Title, @StartDate, @EndDate, @RawJson);
    `);
}

export async function listLessons(lang, quarterlyId) {
    const pool = await getPool();
    const res = await pool.request()
        .input("Lang", sql.NVarChar(10), lang)
        .input("QuarterlyId", sql.NVarChar(30), quarterlyId)
        .query(`
      SELECT LessonId, Title, StartDate, EndDate, UpdatedAt
      FROM dbo.Lessons
      WHERE Lang=@Lang AND QuarterlyId=@QuarterlyId
      ORDER BY LessonId
    `);
    return res.recordset;
}

export async function getLesson(lang, quarterlyId, lessonId) {
    const pool = await getPool();
    const res = await pool.request()
        .input("Lang", sql.NVarChar(10), lang)
        .input("QuarterlyId", sql.NVarChar(30), quarterlyId)
        .input("LessonId", sql.NVarChar(10), lessonId)
        .query(`SELECT * FROM dbo.Lessons WHERE Lang=@Lang AND QuarterlyId=@QuarterlyId AND LessonId=@LessonId`);
    return res.recordset[0] || null;
}

import express from "express";
import { getChangedDayReads } from "../repos/dayReads.repo.js";
import { getQuarterly } from "../repos/quarterlies.repo.js";
import { listLessons } from "../repos/lessons.repo.js";
import { listDays, getDayRead } from "../repos/dayReads.repo.js";

const router = express.Router();

// Cambios desde timestamp (para sync incremental en Flutter)
router.get("/changes", async (req, res) => {
    const lang = req.query.lang ?? "es";
    const since = req.query.since ?? "1970-01-01T00:00:00Z";
    const items = await getChangedDayReads(lang, since);
    res.json({ lang, since, items });
});

// Bulk trimestral (para primer sync offline)
router.get("/bulk", async (req, res) => {
    const lang = req.query.lang ?? "es";
    const quarterlyId = req.query.quarterlyId;
    if (!quarterlyId) return res.status(400).json({ message: "quarterlyId is required" });

    const q = await getQuarterly(lang, quarterlyId);
    if (!q) return res.status(404).json({ message: "Quarterly not found. Run sync first." });

    const lessons = await listLessons(lang, quarterlyId);

    const payload = {
        quarterly: {
            quarterlyId,
            lang,
            title: q.Title,
            coverUrl: q.CoverUrl,
            startDate: q.StartDate,
            endDate: q.EndDate,
            updatedAt: q.UpdatedAt
        },
        lessons: []
    };

    for (const l of lessons) {
        const days = await listDays(lang, quarterlyId, l.LessonId);
        const dayReads = [];
        for (const d of days) {
            const full = await getDayRead(lang, quarterlyId, l.LessonId, d.DayId);
            if (full) {
                dayReads.push({
                    dayId: d.DayId,
                    dayDate: d.DayDate,
                    title: d.Title,
                    updatedAt: d.UpdatedAt,
                    read: JSON.parse(full.ReadJson)
                });
            }
        }

        payload.lessons.push({
            lessonId: l.LessonId,
            title: l.Title,
            startDate: l.StartDate,
            endDate: l.EndDate,
            updatedAt: l.UpdatedAt,
            days: dayReads
        });
    }

    res.json(payload);
});

export default router;

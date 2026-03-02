import express from "express";
import { listQuarterlies, getQuarterly } from "../repos/quarterlies.repo.js";
import { listLessons, getLesson } from "../repos/lessons.repo.js";
import { listDays, getDayRead } from "../repos/dayReads.repo.js";
import { getMedia } from "../repos/media.repo.js";

const router = express.Router();

router.get("/quarterlies", async (req, res) => {
    const lang = req.query.lang ?? "es";
    const data = await listQuarterlies(lang);
    res.json(data);
});

router.get("/quarterlies/:quarterlyId", async (req, res) => {
    const lang = req.query.lang ?? "es";
    const q = await getQuarterly(lang, req.params.quarterlyId);
    if (!q) return res.status(404).json({ message: "Quarterly not found" });
    res.json({
        ...q,
        raw: q.RawJson ? JSON.parse(q.RawJson) : null
    });
});

router.get("/quarterlies/:quarterlyId/lessons", async (req, res) => {
    const lang = req.query.lang ?? "es";
    const data = await listLessons(lang, req.params.quarterlyId);
    res.json(data);
});

router.get("/quarterlies/:quarterlyId/lessons/:lessonId", async (req, res) => {
    const lang = req.query.lang ?? "es";
    const l = await getLesson(lang, req.params.quarterlyId, req.params.lessonId);
    if (!l) return res.status(404).json({ message: "Lesson not found" });
    res.json({
        ...l,
        raw: l.RawJson ? JSON.parse(l.RawJson) : null
    });
});

router.get("/quarterlies/:quarterlyId/lessons/:lessonId/days", async (req, res) => {
    const lang = req.query.lang ?? "es";
    const data = await listDays(lang, req.params.quarterlyId, req.params.lessonId);
    res.json(data);
});

router.get("/quarterlies/:quarterlyId/lessons/:lessonId/days/:dayId/read", async (req, res) => {
    const lang = req.query.lang ?? "es";
    const d = await getDayRead(lang, req.params.quarterlyId, req.params.lessonId, req.params.dayId);
    if (!d) return res.status(404).json({ message: "Day read not found" });
    res.json(JSON.parse(d.ReadJson));
});

// router.get("/quarterlies/:quarterlyId/:mediaType(audio|video)", async (req, res) => {
//     const lang = req.query.lang ?? "es";
//     const m = await getMedia(lang, req.params.quarterlyId, req.params.mediaType);
//     if (!m) return res.status(404).json({ message: "Media not found" });
//     res.json(JSON.parse(m.RawJson));
// });
router.get(
    "/quarterlies/:quarterlyId/:mediaType",
    async (req, res) => {
        const { quarterlyId, mediaType } = req.params;
        const lang = req.query.lang ?? "es";

        if (!["audio", "video"].includes(mediaType)) {
            return res.status(400).json({
                message: "Invalid mediaType. Use 'audio' or 'video'"
            });
        }

        const media = await getMedia(lang, quarterlyId, mediaType);

        if (!media) {
            return res.status(404).json({ message: "Media not found" });
        }

        res.json(JSON.parse(media.RawJson));
    }
);


export default router;

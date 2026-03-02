import express from "express";
import { syncQuarterly, syncAll } from "../services/sync.service.js";

const router = express.Router();

/**
 * =====================================
 * Sync de UN trimestre
 * =====================================
 * POST /api/v1/admin/sync/quarterly/:quarterlyId
 * body opcional: { lang: "es" }
 */
router.post("/sync/quarterly/:quarterlyId", async (req, res) => {
    try {
        const lang = req.body?.lang ?? "es";
        const quarterlyId = req.params.quarterlyId;

        const result = await syncQuarterly({ lang, quarterlyId });

        res.json({
            ok: true,
            message: "Quarterly sync completed",
            result
        });
    } catch (err) {
        console.error("❌ Error syncing quarterly:", err);
        res.status(500).json({
            ok: false,
            message: "Error syncing quarterly",
            error: err.message
        });
    }
});

/**
 * =====================================
 * Sync GLOBAL (todos los trimestres)
 * =====================================
 * POST /api/v1/admin/sync/all
 * body opcional: { lang: "es" }
 */
router.post("/sync/all", async (req, res) => {
    try {
        const lang = req.body?.lang ?? "es";

        const result = await syncAll({ lang });

        res.json({
            ok: true,
            message: "Global sync completed",
            result
        });
    } catch (err) {
        console.error("❌ Error syncing all:", err);
        res.status(500).json({
            ok: false,
            message: "Error syncing all",
            error: err.message
        });
    }
});

export default router;

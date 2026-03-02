import { fetchJsonCached } from "./sourceClient.js";
import { upsertQuarterly } from "../repos/quarterlies.repo.js";
import { upsertLesson } from "../repos/lessons.repo.js";
import { upsertDayRead } from "../repos/dayReads.repo.js";
import { upsertMedia } from "../repos/media.repo.js";

/**
 * =========================
 * Helpers generales
 * =========================
 */

function pick(obj, keys) {
    const out = {};
    for (const k of keys) out[k] = obj?.[k];
    return out;
}

function safeParseSqlDate(value) {
    if (!value) return null;

    // Si ya es Date
    if (value instanceof Date && !isNaN(value)) {
        return value;
    }

    // Si es string, intenta parsear
    if (typeof value === "string") {
        const d = new Date(value);
        if (!isNaN(d)) return d;
    }

    // Cualquier otro caso → NULL
    return null;
}

function parseDateDMY(dmy) {
    if (!dmy || typeof dmy !== "string") return null;

    const [dd, mm, yyyy] = dmy.split("/");
    if (!dd || !mm || !yyyy) return null;

    return `${yyyy}-${mm}-${dd}`; // ISO yyyy-mm-dd
}


/**
 * =========================
 * Parsers tolerantes
 * (los JSON pueden cambiar)
 * =========================
 */

// function parseQuarterlyMeta(quarterlyId, data) {
//     return {
//         title: data?.title ?? data?.name ?? null,
//         coverUrl: data?.cover ?? data?.cover_url ?? data?.image ?? null,
//         startDate: data?.start_date ?? data?.startDate ?? null,
//         endDate: data?.end_date ?? data?.endDate ?? null
//     };
// }

// function parseQuarterlyMeta(quarterlyId, data) {
//     return {
//         // Título real
//         title: data?.name ?? data?.title ?? null,

//         // Portada: intenta varias rutas comunes
//         coverUrl:
//             data?.resources?.cover?.portrait ??
//             data?.resources?.cover?.landscape ??
//             data?.cover ??
//             null,

//         // Fechas: normalmente NO vienen explícitas → se dejan NULL
//         startDate: null,
//         endDate: null
//     };
// }

function parseQuarterlyMeta(quarterlyId, data) {
    const q = data?.quarterly ?? {};

    return {
        title: q.title ?? null,
        coverUrl: q.cover ?? q.image ?? null,
        startDate: parseDateDMY(q.start_date),
        endDate: parseDateDMY(q.end_date)
    };
}


// function parseLessonMeta(data) {
//     return {
//         title: data?.title ?? data?.name ?? null,
//         startDate: data?.start_date ?? data?.startDate ?? null,
//         endDate: data?.end_date ?? data?.endDate ?? null
//     };
// }



function parseLessonMeta(data) {
    const l = data?.lesson ?? {};

    return {
        title: l.title ?? null,
        startDate: parseDateDMY(l.start_date),
        endDate: parseDateDMY(l.end_date)
    };
}



function parseDayRead(data) {
    return {
        title: data?.title ?? data?.name ?? null,
        dayDate: data?.date ?? data?.day_date ?? null
    };
}

/**
 * =========================
 * Extractores de IDs
 * =========================
 */

// Desde quarterlies/index.json
function extractQuarterlyIds(indexData) {
    const arr = Array.isArray(indexData)
        ? indexData
        : (indexData?.quarterlies ?? indexData?.items ?? []);

    return arr
        .map(x => x?.id ?? x?.quarterly ?? x?.path ?? x?.slug)
        .filter(Boolean);
}

// Desde quarterly/index.json
function extractLessonIds(quarterlyIndexData) {
    const arr = quarterlyIndexData?.lessons ?? quarterlyIndexData?.items ?? [];
    const ids = arr.map(x => x?.id ?? x?.lesson ?? x?.index).filter(Boolean);

    if (ids.length) {
        return ids.map(x => String(x).padStart(2, "0"));
    }

    // Fallback defensivo
    return Array.from({ length: 13 }, (_, i) =>
        String(i + 1).padStart(2, "0")
    );
}

// Desde lesson/index.json
function extractDayIds(lessonIndexData) {
    const arr = lessonIndexData?.days ?? lessonIndexData?.items ?? [];
    const ids = arr.map(x => x?.id ?? x?.day ?? x?.index).filter(Boolean);

    if (ids.length) {
        return ids.map(x => String(x).padStart(2, "0"));
    }

    // Fallback defensivo
    return Array.from({ length: 7 }, (_, i) =>
        String(i + 1).padStart(2, "0")
    );
}

/**
 * =========================
 * Helper CLAVE: fetch seguro
 * para días (404 permitido)
 * =========================
 */

async function safeFetchDayRead({ lang, quarterlyId, lessonId, dayId }) {
    const resourceKey =
        `${lang}/quarterlies/${quarterlyId}/lessons/${lessonId}/days/${dayId}/read/index.json`;

    try {
        return await fetchJsonCached(resourceKey);
    } catch (err) {
        // 404 es NORMAL (día no existe)
        if (err.response?.status === 404) {
            console.warn(`⚠️ Día no existe, se omite: ${resourceKey}`);
            return { changed: false, data: null, notFound: true };
        }

        // Otros errores sí deben romper el proceso
        throw err;
    }
}

/**
 * =========================
 * Servicio principal
 * =========================
 */

export async function syncQuarterly({ lang = "es", quarterlyId }) {

    /**
     * 1) Índice del trimestre
     */
    const qKey = `${lang}/quarterlies/${quarterlyId}/index.json`;
    const qRes = await fetchJsonCached(qKey);

    console.log("🔎 QUARTERLY RAW JSON KEYS:", Object.keys(qRes.data || {}));
    console.log("🔎 QUARTERLY RAW JSON SAMPLE:", JSON.stringify(qRes.data, null, 2).slice(0, 500));


    // if (qRes.changed && qRes.data) {
    //     const meta = parseQuarterlyMeta(quarterlyId, qRes.data);
    //     await upsertQuarterly({
    //         lang,
    //         quarterlyId,
    //         ...meta,
    //         rawJson: JSON.stringify(qRes.data)
    //     });
    // }

    if (qRes.data) {
        const meta = parseQuarterlyMeta(quarterlyId, qRes.data);

        await upsertQuarterly({
            lang,
            quarterlyId,
            ...meta,
            rawJson: JSON.stringify(qRes.data)
        });
    }

    /**
     * 2) Media (audio / video)
     */
    for (const mediaType of ["audio", "video"]) {
        const mKey = `${lang}/quarterlies/${quarterlyId}/${mediaType}.json`;
        const mRes = await fetchJsonCached(mKey);

        if (mRes.changed && mRes.data) {
            await upsertMedia({
                lang,
                quarterlyId,
                mediaType,
                rawJson: JSON.stringify(mRes.data)
            });
        }
    }

    /**
     * 3) Lecciones del trimestre
     */
    const qIndexData = qRes.data ?? null;
    const lessonIds = qIndexData
        ? extractLessonIds(qIndexData)
        : Array.from({ length: 13 }, (_, i) => String(i + 1).padStart(2, "0"));

    /**
     * 4) Por cada lección → índice + días
     */
    for (const lessonId of lessonIds) {

        // 4.1 índice de lección
        const lKey = `${lang}/quarterlies/${quarterlyId}/lessons/${lessonId}/index.json`;
        const lRes = await fetchJsonCached(lKey);

        if (lRes.data) {
            console.log("🔎 LESSON RAW JSON KEYS:", Object.keys(lRes.data));
            console.log("🔎 LESSON RAW JSON SAMPLE:", JSON.stringify(lRes.data).slice(0, 300));
        }

        if (lRes.data) {
            const meta = parseLessonMeta(lRes.data);
            await upsertLesson({
                lang,
                quarterlyId,
                lessonId,
                ...meta,
                rawJson: JSON.stringify(lRes.data)
            });
        }

        // 4.2 días de la lección
        const lIndexData = lRes.data ?? null;
        const dayIds = lIndexData
            ? extractDayIds(lIndexData)
            : Array.from({ length: 7 }, (_, i) => String(i + 1).padStart(2, "0"));

        for (const dayId of dayIds) {
            const dRes = await safeFetchDayRead({
                lang,
                quarterlyId,
                lessonId,
                dayId
            });

            if (dRes.notFound) {
                continue; // día no existe → seguimos
            }

            //if (dRes.changed && dRes.data) {
            if (dRes.data) {
                const meta = parseDayRead(dRes.data);
                await upsertDayRead({
                    lang,
                    quarterlyId,
                    lessonId,
                    dayId,
                    //dayDate: meta.dayDate,
                    dayDate: safeParseSqlDate(meta.dayDate),
                    title: meta.title,
                    readJson: JSON.stringify(dRes.data)
                });
            }
        }
    }

    return { ok: true, lang, quarterlyId };
}

/**
 * =========================
 * Sync global
 * =========================
 */

export async function syncAll({ lang = "es" }) {
    const idxKey = `${lang}/quarterlies/index.json`;
    const idxRes = await fetchJsonCached(idxKey);

    if (!idxRes.data) {
        return {
            ok: true,
            note: "index.json not changed (304). Use DB quarterlies or force sync."
        };
    }

    const quarterlyIds = extractQuarterlyIds(idxRes.data);

    for (const qid of quarterlyIds) {
        await syncQuarterly({ lang, quarterlyId: qid });
    }

    return { ok: true, lang, count: quarterlyIds.length };
}

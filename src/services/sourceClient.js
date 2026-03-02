import axios from "axios";
import crypto from "crypto";
import { getSourceMeta, upsertSourceMeta } from "../repos/sourceResources.repo.js";

function sha256Buffer(str) {
    return crypto.createHash("sha256").update(str, "utf8").digest();
}

export async function fetchJsonCached(resourceKey) {
    const base = process.env.SOURCE_BASE;
    const url = `${base}/${resourceKey}`;

    const prev = await getSourceMeta(resourceKey);
    const headers = {};

    if (prev?.ETag) headers["If-None-Match"] = prev.ETag;
    if (prev?.LastModified) headers["If-Modified-Since"] = prev.LastModified;

    const res = await axios.get(url, {
        headers,
        timeout: 30000,
        validateStatus: (s) => [200, 304].includes(s)
    });

    // 🔑 CASO CLAVE: 304 → devolver JSON cacheado
    if (res.status === 304) {
        return {
            changed: false,
            data: prev?.RawJson ? JSON.parse(prev.RawJson) : null,
            url
        };
    }

    // 200 → guardar nuevo JSON
    const bodyStr = JSON.stringify(res.data);

    await upsertSourceMeta({
        resourceKey,
        url,
        etag: res.headers.etag ?? null,
        lastModified: res.headers["last-modified"] ?? null,
        contentHash: sha256Buffer(bodyStr),
        rawJson: bodyStr
    });

    return {
        changed: true,
        data: res.data,
        url
    };
}


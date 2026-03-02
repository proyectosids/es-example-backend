import "dotenv/config";
import { syncQuarterly } from "../src/services/sync.service.js";

const lang = process.argv[2] || "es";
const quarterlyId = process.argv[3]; // ej: 2026-01

if (!quarterlyId) {
    console.error("Usage: npm run sync:quarterly -- es 2026-01");
    process.exit(1);
}

await syncQuarterly({ lang, quarterlyId });
console.log("Done ✅");

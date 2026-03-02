import "dotenv/config";
import { syncAll } from "../src/services/sync.service.js";

const lang = process.argv[2] || "es";
await syncAll({ lang });
console.log("Done ✅");

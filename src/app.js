import "dotenv/config";
import express from "express";

import catalogRoutes from "./routes/catalog.routes.js";
import syncRoutes from "./routes/sync.routes.js";
import adminSyncRoutes from "./routes/admin-sync.routes.js";

const app = express();
app.use(express.json());

app.get("/health", (_, res) => res.json({ ok: true }));

// API pública (Flutter)
app.use("/api/v1", catalogRoutes);
app.use("/api/v1/sync", syncRoutes);

// API administrativa (sync)
app.use("/api/v1/admin", adminSyncRoutes);

const port = process.env.PORT || 3000;
app.listen(port, () => console.log(`API running on http://localhost:${port}`));

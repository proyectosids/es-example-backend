import "dotenv/config";
import express from "express";

import catalogRoutes from "./routes/catalog.routes.js";
import syncRoutes from "./routes/sync.routes.js";
import adminSyncRoutes from "./routes/admin-sync.routes.js";
import authRoutes from "./routes/auth.routes.js";
import meRoutes from "./routes/me.routes.js";
import usersRoutes from "./routes/users.routes.js";
import orgRoutes from "./routes/org.routes.js";
import publicRoutes from "./routes/public.routes.js";
import smallGroupsRoutes from "./routes/small-groups.routes.js";
import specializedAdminRoutes from "./routes/specialized-admin.routes.js";
import quarterlyPoliciesRoutes from "./routes/quarterly-policies.routes.js";

const app = express();
app.use(express.json());

app.get("/health", (_, res) => res.json({ ok: true }));

// API pública (Flutter)
app.use("/api/v1", catalogRoutes);
app.use("/api/v1/sync", syncRoutes);

// API administrativa (sync)
app.use("/api/v1/admin", adminSyncRoutes);

// API autenticacion/autorizacion (RBAC)
app.use("/api/v1", authRoutes);
app.use("/api/v1", meRoutes);
app.use("/api/v1", usersRoutes);
app.use("/api/v1", orgRoutes);
app.use("/api/v1", publicRoutes);
app.use("/api/v1", smallGroupsRoutes);
app.use("/api/v1", specializedAdminRoutes);
app.use("/api/v1", quarterlyPoliciesRoutes);

const port = process.env.PORT || 3000;
app.listen(port, () => console.log(`API running on http://localhost:${port}`));

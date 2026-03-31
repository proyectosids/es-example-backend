import express from "express";

import { authenticate } from "../middleware/auth.middleware.js";
import { requirePermission } from "../middleware/permission.middleware.js";
import { createOrgUnit, getOrgUnitById, listOrgUnits, updateOrgUnit } from "../repos/orgUnits.repo.js";
import { listRoles } from "../repos/roles.repo.js";

const router = express.Router();
router.use(authenticate);

router.get(
  "/org-units",
  requirePermission("app.users.read", req => req.query.parentOrgUnitId || req.query.orgUnitId),
  async (req, res) => {
    try {
      const parentOrgUnitId = req.query.parentOrgUnitId ? String(req.query.parentOrgUnitId) : null;
      const orgUnitTypeCode = req.query.orgUnitTypeCode ? String(req.query.orgUnitTypeCode) : null;
      const items = await listOrgUnits({
        tenantId: req.auth.tenantId,
        parentOrgUnitId,
        orgUnitTypeCode
      });
      return res.json(items);
    } catch (err) {
      return res.status(500).json({ message: "Error listing org units", error: err.message });
    }
  }
);

router.get(
  "/org-units/:orgUnitId",
  requirePermission("app.users.read", req => req.params.orgUnitId),
  async (req, res) => {
    try {
      const item = await getOrgUnitById({
        tenantId: req.auth.tenantId,
        orgUnitId: req.params.orgUnitId
      });
      if (!item) return res.status(404).json({ message: "Org unit not found" });
      return res.json(item);
    } catch (err) {
      return res.status(500).json({ message: "Error loading org unit", error: err.message });
    }
  }
);

router.post(
  "/org-units",
  requirePermission("app.org.manage", req => req.body?.parentOrgUnitId),
  async (req, res) => {
    try {
      const {
        orgUnitTypeCode,
        parentOrgUnitId = null,
        code,
        name,
        path = null
      } = req.body || {};

      if (!orgUnitTypeCode || !code || !name) {
        return res.status(400).json({ message: "orgUnitTypeCode, code and name are required" });
      }

      const created = await createOrgUnit({
        tenantId: req.auth.tenantId,
        orgUnitTypeCode,
        parentOrgUnitId,
        code,
        name,
        path
      });
      return res.status(201).json(created);
    } catch (err) {
      return res.status(500).json({ message: "Error creating org unit", error: err.message });
    }
  }
);

router.patch(
  "/org-units/:orgUnitId",
  requirePermission("app.org.manage", req => req.params.orgUnitId),
  async (req, res) => {
    try {
      const updated = await updateOrgUnit({
        tenantId: req.auth.tenantId,
        orgUnitId: req.params.orgUnitId,
        name: req.body?.name,
        isActive: typeof req.body?.isActive === "boolean" ? req.body.isActive : null,
        path: req.body?.path
      });
      if (!updated) return res.status(404).json({ message: "Org unit not found" });
      return res.json(updated);
    } catch (err) {
      return res.status(500).json({ message: "Error updating org unit", error: err.message });
    }
  }
);

router.get("/roles", async (_req, res) => {
  try {
    const roles = await listRoles();
    return res.json(roles);
  } catch (err) {
    return res.status(500).json({ message: "Error listing roles", error: err.message });
  }
});

export default router;

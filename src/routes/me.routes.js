import express from "express";

import { authenticate } from "../middleware/auth.middleware.js";
import { listEffectivePermissions, listEffectiveScreens } from "../repos/roles.repo.js";
import { getUserById, listUserMemberships, listUserRoleAssignments } from "../repos/users.repo.js";

const router = express.Router();

router.use(authenticate);

router.get("/me", async (req, res) => {
  try {
    const { tenantId, userId } = req.auth;
    const [user, memberships, roles] = await Promise.all([
      getUserById({ tenantId, userId }),
      listUserMemberships({ tenantId, userId }),
      listUserRoleAssignments({ tenantId, userId })
    ]);

    if (!user) return res.status(404).json({ message: "User not found" });

    return res.json({
      user,
      memberships,
      roleAssignments: roles
    });
  } catch (err) {
    return res.status(500).json({ message: "Error loading profile", error: err.message });
  }
});

router.get("/me/permissions", async (req, res) => {
  try {
    const { tenantId, userId } = req.auth;
    const orgUnitId = req.query.orgUnitId ? String(req.query.orgUnitId) : null;
    const permissions = await listEffectivePermissions({ tenantId, userId, orgUnitId });
    return res.json({ orgUnitId, permissions });
  } catch (err) {
    return res.status(500).json({ message: "Error loading permissions", error: err.message });
  }
});

router.get("/me/screens", async (req, res) => {
  try {
    const { tenantId, userId } = req.auth;
    const orgUnitId = req.query.orgUnitId ? String(req.query.orgUnitId) : null;
    const screens = await listEffectiveScreens({ tenantId, userId, orgUnitId });
    return res.json({ orgUnitId, screens });
  } catch (err) {
    return res.status(500).json({ message: "Error loading screens", error: err.message });
  }
});

export default router;

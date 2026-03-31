import express from "express";
import bcrypt from "bcryptjs";

import { authenticate } from "../middleware/auth.middleware.js";
import { requirePermission } from "../middleware/permission.middleware.js";
import { getRoleByCode, hasPermissionAtScope } from "../repos/roles.repo.js";
import {
  canUserAssignRoleAtScope
} from "../repos/roleAssignmentRules.repo.js";
import {
  addUserMembership,
  assignRoleToUser,
  createUser,
  deactivateRoleAssignment,
  getRoleAssignmentById,
  listUsersByScope,
  normalizeEmail
} from "../repos/users.repo.js";
import { safeAudit } from "../utils/audit.js";

const router = express.Router();

router.use(authenticate);

router.get(
  "/users",
  requirePermission("app.users.read", req => req.query.orgUnitId),
  async (req, res) => {
    try {
      const orgUnitId = String(req.query.orgUnitId || "");
      if (!orgUnitId) return res.status(400).json({ message: "orgUnitId is required" });

      const items = await listUsersByScope({
        tenantId: req.auth.tenantId,
        orgUnitId
      });
      return res.json(items);
    } catch (err) {
      return res.status(500).json({ message: "Error listing users", error: err.message });
    }
  }
);

router.post(
  "/users",
  requirePermission("app.users.manage", req => req.body?.membershipOrgUnitId || req.body?.scopeOrgUnitId),
  async (req, res) => {
    try {
      const tenantId = req.auth.tenantId;
      const {
        email,
        password,
        firstName = null,
        lastName = null,
        displayName = null,
        phone = null,
        membershipOrgUnitId = null,
        membershipType = "MEMBER",
        roleCode = null,
        scopeOrgUnitId = null
      } = req.body || {};

      if (!email || !password) {
        return res.status(400).json({ message: "email and password are required" });
      }

      let roleForCreation = null;
      if (roleCode && scopeOrgUnitId) {
        roleForCreation = await getRoleByCode(String(roleCode));
        if (!roleForCreation) return res.status(400).json({ message: "Invalid roleCode" });

        const ruleValidation = await canUserAssignRoleAtScope({
          tenantId,
          assignerUserId: req.auth.userId,
          assignableRoleCode: String(roleCode),
          targetScopeOrgUnitId: scopeOrgUnitId
        });
        if (!ruleValidation.ok) {
          return res.status(403).json({ message: ruleValidation.reason || "Forbidden by assignment rules" });
        }
      }

      const passwordHash = await bcrypt.hash(String(password), 10);
      const user = await createUser({
        tenantId,
        email: String(email).trim(),
        emailNormalized: normalizeEmail(email),
        passwordHash,
        firstName,
        lastName,
        displayName,
        phone
      });

      if (membershipOrgUnitId) {
        await addUserMembership({
          tenantId,
          userId: user.UserId,
          orgUnitId: membershipOrgUnitId,
          membershipType
        });
      }

      let roleAssignment = null;
      if (roleCode && scopeOrgUnitId) {
        roleAssignment = await assignRoleToUser({
          tenantId,
          userId: user.UserId,
          roleId: roleForCreation.RoleId,
          scopeOrgUnitId,
          assignedByUserId: req.auth.userId
        });
      }

      await safeAudit({
        tenantId,
        actorUserId: req.auth.userId,
        actionCode: "ADMIN_USER_CREATED",
        entityType: "USER",
        entityId: String(user.UserId),
        targetOrgUnitId: membershipOrgUnitId || scopeOrgUnitId || null,
        metadata: {
          email: user.Email,
          membershipOrgUnitId,
          membershipType,
          roleCode
        }
      });

      if (roleAssignment) {
        await safeAudit({
          tenantId,
          actorUserId: req.auth.userId,
          actionCode: "ROLE_ASSIGNED",
          entityType: "USER_ROLE_ASSIGNMENT",
          entityId: String(roleAssignment.UserRoleAssignmentId),
          targetOrgUnitId: scopeOrgUnitId,
          metadata: {
            userId: user.UserId,
            roleCode,
            scopeOrgUnitId
          }
        });
      }

      return res.status(201).json({ user, roleAssignment });
    } catch (err) {
      return res.status(500).json({ message: "Error creating user", error: err.message });
    }
  }
);

router.post(
  "/users/:userId/roles",
  requirePermission("app.roles.assign", req => req.body?.scopeOrgUnitId),
  async (req, res) => {
    try {
      const tenantId = req.auth.tenantId;
      const userId = req.params.userId;
      const { roleCode, scopeOrgUnitId, validFrom = null, validTo = null } = req.body || {};

      if (!roleCode || !scopeOrgUnitId) {
        return res.status(400).json({ message: "roleCode and scopeOrgUnitId are required" });
      }

      const role = await getRoleByCode(String(roleCode));
      if (!role) return res.status(400).json({ message: "Invalid roleCode" });

      const ruleValidation = await canUserAssignRoleAtScope({
        tenantId,
        assignerUserId: req.auth.userId,
        assignableRoleCode: String(roleCode),
        targetScopeOrgUnitId: scopeOrgUnitId
      });
      if (!ruleValidation.ok) {
        return res.status(403).json({ message: ruleValidation.reason || "Forbidden by assignment rules" });
      }

      const out = await assignRoleToUser({
        tenantId,
        userId,
        roleId: role.RoleId,
        scopeOrgUnitId,
        assignedByUserId: req.auth.userId,
        validFrom,
        validTo
      });

      await safeAudit({
        tenantId,
        actorUserId: req.auth.userId,
        actionCode: "ROLE_ASSIGNED",
        entityType: "USER_ROLE_ASSIGNMENT",
        entityId: String(out.UserRoleAssignmentId),
        targetOrgUnitId: scopeOrgUnitId,
        metadata: {
          userId,
          roleCode,
          scopeOrgUnitId,
          validFrom,
          validTo
        }
      });

      return res.status(201).json(out);
    } catch (err) {
      return res.status(500).json({ message: "Error assigning role", error: err.message });
    }
  }
);

router.delete("/users/role-assignments/:assignmentId", async (req, res) => {
  try {
    const tenantId = req.auth.tenantId;
    const userId = req.auth.userId;
    const assignmentId = req.params.assignmentId;

    const assignment = await getRoleAssignmentById({ tenantId, assignmentId });
    if (!assignment) return res.status(404).json({ message: "Role assignment not found" });

    const canAssign = await hasPermissionAtScope({
      tenantId,
      userId,
      permissionCode: "app.roles.assign",
      orgUnitId: assignment.ScopeOrgUnitId
    });
    if (!canAssign) return res.status(403).json({ message: "Forbidden" });

    await deactivateRoleAssignment({ tenantId, assignmentId });
    return res.json({ ok: true });
  } catch (err) {
    return res.status(500).json({ message: "Error removing role assignment", error: err.message });
  }
});

export default router;

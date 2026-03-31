import express from "express";
import bcrypt from "bcryptjs";

import { authenticate } from "../middleware/auth.middleware.js";
import { requirePermission } from "../middleware/permission.middleware.js";
import { getOrgUnitById, isOrgUnitDescendantOf } from "../repos/orgUnits.repo.js";
import { canUserAssignRoleAtScope, hasActiveRoleOverScope } from "../repos/roleAssignmentRules.repo.js";
import { getRoleByCode } from "../repos/roles.repo.js";
import {
  addUserMembership,
  assignRoleToUser,
  createUser,
  findUserByEmailNormalized,
  hasActiveMembershipInOrgUnit,
  normalizeEmail
} from "../repos/users.repo.js";
import { safeAudit } from "../utils/audit.js";

const router = express.Router();
router.use(authenticate);

async function resolveOrCreateUser({
  tenantId,
  userId = null,
  email = null,
  password = null,
  firstName = null,
  lastName = null,
  displayName = null,
  phone = null
}) {
  if (userId) {
    return { user: { UserId: userId }, created: false };
  }

  if (!email) {
    throw new Error("email is required when userId is not provided");
  }

  const normalized = normalizeEmail(email);
  const existing = await findUserByEmailNormalized({
    tenantId,
    emailNormalized: normalized
  });
  if (existing) {
    return { user: existing, created: false };
  }

  if (!password) {
    throw new Error("password is required for a new user");
  }

  const passwordHash = await bcrypt.hash(String(password), 10);
  const created = await createUser({
    tenantId,
    email: String(email).trim(),
    emailNormalized: normalized,
    passwordHash,
    firstName,
    lastName,
    displayName,
    phone
  });
  return { user: created, created: true };
}

async function ensureMembershipInChurch({ tenantId, userId, churchOrgUnitId, membershipType = "MEMBER" }) {
  const exists = await hasActiveMembershipInOrgUnit({
    tenantId,
    userId,
    orgUnitId: churchOrgUnitId
  });
  if (exists) return;
  await addUserMembership({
    tenantId,
    userId,
    orgUnitId: churchOrgUnitId,
    membershipType,
    isPrimary: false
  });
}

router.post(
  "/field-admin/pastors",
  requirePermission("app.users.manage", req => req.body?.churchOrgUnitId),
  async (req, res) => {
    try {
      const tenantId = req.auth.tenantId;
      const actorUserId = req.auth.userId;
      const {
        churchOrgUnitId,
        userId = null,
        email = null,
        password = null,
        firstName = null,
        lastName = null,
        displayName = null,
        phone = null,
        validFrom = null,
        validTo = null
      } = req.body || {};

      if (!churchOrgUnitId) {
        return res.status(400).json({ message: "churchOrgUnitId is required" });
      }

      const church = await getOrgUnitById({ tenantId, orgUnitId: churchOrgUnitId });
      if (!church || church.OrgUnitTypeCode !== "CHURCH") {
        return res.status(400).json({ message: "churchOrgUnitId must be an active CHURCH org unit" });
      }

      const hasFieldDirectorRole = await hasActiveRoleOverScope({
        tenantId,
        userId: actorUserId,
        roleCode: "FIELD_SABBATH_DIRECTOR",
        targetScopeOrgUnitId: churchOrgUnitId
      });
      if (!hasFieldDirectorRole) {
        return res.status(403).json({ message: "Forbidden: requires FIELD_SABBATH_DIRECTOR over church scope" });
      }

      const governance = await canUserAssignRoleAtScope({
        tenantId,
        assignerUserId: actorUserId,
        assignableRoleCode: "PASTOR",
        targetScopeOrgUnitId: churchOrgUnitId
      });
      if (!governance.ok) {
        return res.status(403).json({ message: governance.reason || "Forbidden by assignment rules" });
      }

      const { user, created } = await resolveOrCreateUser({
        tenantId,
        userId,
        email,
        password,
        firstName,
        lastName,
        displayName,
        phone
      });

      await ensureMembershipInChurch({
        tenantId,
        userId: user.UserId,
        churchOrgUnitId,
        membershipType: "PASTOR"
      });

      const pastorRole = await getRoleByCode("PASTOR");
      if (!pastorRole) return res.status(500).json({ message: "Role PASTOR not configured" });

      const assignment = await assignRoleToUser({
        tenantId,
        userId: user.UserId,
        roleId: pastorRole.RoleId,
        scopeOrgUnitId: churchOrgUnitId,
        assignedByUserId: actorUserId,
        validFrom,
        validTo
      });

      if (created) {
        await safeAudit({
          tenantId,
          actorUserId,
          actionCode: "ADMIN_USER_CREATED",
          entityType: "USER",
          entityId: String(user.UserId),
          targetOrgUnitId: churchOrgUnitId,
          metadata: {
            email: user.Email || email,
            createdVia: "field-admin/pastors",
            roleCode: "PASTOR"
          }
        });
      }

      await safeAudit({
        tenantId,
        actorUserId,
        actionCode: "ROLE_ASSIGNED",
        entityType: "USER_ROLE_ASSIGNMENT",
        entityId: String(assignment.UserRoleAssignmentId),
        targetOrgUnitId: churchOrgUnitId,
        metadata: {
          userId: user.UserId,
          roleCode: "PASTOR",
          scopeOrgUnitId: churchOrgUnitId,
          validFrom,
          validTo
        }
      });

      return res.status(201).json({ created, userId: user.UserId, assignment });
    } catch (err) {
      if (err?.number === 2601 || err?.number === 2627) {
        return res.status(409).json({ message: "Role already assigned or duplicated data" });
      }
      if (String(err?.message || "").includes("password is required")) {
        return res.status(400).json({ message: err.message });
      }
      return res.status(500).json({ message: "Error creating pastor", error: err.message });
    }
  }
);

router.post(
  "/church-admin/sabbath-directors",
  requirePermission("app.users.manage", req => req.body?.churchOrgUnitId),
  async (req, res) => {
    try {
      const tenantId = req.auth.tenantId;
      const actorUserId = req.auth.userId;
      const {
        churchOrgUnitId,
        userId = null,
        email = null,
        password = null,
        firstName = null,
        lastName = null,
        displayName = null,
        phone = null,
        validFrom = null,
        validTo = null
      } = req.body || {};

      if (!churchOrgUnitId) {
        return res.status(400).json({ message: "churchOrgUnitId is required" });
      }

      const church = await getOrgUnitById({ tenantId, orgUnitId: churchOrgUnitId });
      if (!church || church.OrgUnitTypeCode !== "CHURCH") {
        return res.status(400).json({ message: "churchOrgUnitId must be an active CHURCH org unit" });
      }

      const hasPastorRole = await hasActiveRoleOverScope({
        tenantId,
        userId: actorUserId,
        roleCode: "PASTOR",
        targetScopeOrgUnitId: churchOrgUnitId
      });
      if (!hasPastorRole) {
        return res.status(403).json({ message: "Forbidden: requires PASTOR role at church scope" });
      }

      const governance = await canUserAssignRoleAtScope({
        tenantId,
        assignerUserId: actorUserId,
        assignableRoleCode: "CHURCH_SABBATH_DIRECTOR",
        targetScopeOrgUnitId: churchOrgUnitId
      });
      if (!governance.ok) {
        return res.status(403).json({ message: governance.reason || "Forbidden by assignment rules" });
      }

      const { user, created } = await resolveOrCreateUser({
        tenantId,
        userId,
        email,
        password,
        firstName,
        lastName,
        displayName,
        phone
      });

      await ensureMembershipInChurch({
        tenantId,
        userId: user.UserId,
        churchOrgUnitId,
        membershipType: "DIRECTOR"
      });

      const directorRole = await getRoleByCode("CHURCH_SABBATH_DIRECTOR");
      if (!directorRole) return res.status(500).json({ message: "Role CHURCH_SABBATH_DIRECTOR not configured" });

      const assignment = await assignRoleToUser({
        tenantId,
        userId: user.UserId,
        roleId: directorRole.RoleId,
        scopeOrgUnitId: churchOrgUnitId,
        assignedByUserId: actorUserId,
        validFrom,
        validTo
      });

      if (created) {
        await safeAudit({
          tenantId,
          actorUserId,
          actionCode: "ADMIN_USER_CREATED",
          entityType: "USER",
          entityId: String(user.UserId),
          targetOrgUnitId: churchOrgUnitId,
          metadata: {
            email: user.Email || email,
            createdVia: "church-admin/sabbath-directors",
            roleCode: "CHURCH_SABBATH_DIRECTOR"
          }
        });
      }

      await safeAudit({
        tenantId,
        actorUserId,
        actionCode: "ROLE_ASSIGNED",
        entityType: "USER_ROLE_ASSIGNMENT",
        entityId: String(assignment.UserRoleAssignmentId),
        targetOrgUnitId: churchOrgUnitId,
        metadata: {
          userId: user.UserId,
          roleCode: "CHURCH_SABBATH_DIRECTOR",
          scopeOrgUnitId: churchOrgUnitId,
          validFrom,
          validTo
        }
      });

      return res.status(201).json({ created, userId: user.UserId, assignment });
    } catch (err) {
      if (err?.number === 2601 || err?.number === 2627) {
        return res.status(409).json({ message: "Role already assigned or duplicated data" });
      }
      if (String(err?.message || "").includes("password is required")) {
        return res.status(400).json({ message: err.message });
      }
      return res.status(500).json({ message: "Error creating sabbath director", error: err.message });
    }
  }
);

router.post(
  "/church-admin/small-group-leaders",
  requirePermission("app.roles.assign", req => req.body?.smallGroupOrgUnitId),
  async (req, res) => {
    try {
      const tenantId = req.auth.tenantId;
      const actorUserId = req.auth.userId;
      const { userId, smallGroupOrgUnitId, validFrom = null, validTo = null } = req.body || {};

      if (!userId || !smallGroupOrgUnitId) {
        return res.status(400).json({ message: "userId and smallGroupOrgUnitId are required" });
      }

      const smallGroup = await getOrgUnitById({ tenantId, orgUnitId: smallGroupOrgUnitId });
      if (!smallGroup || smallGroup.OrgUnitTypeCode !== "SMALL_GROUP") {
        return res.status(400).json({ message: "smallGroupOrgUnitId must be an active SMALL_GROUP org unit" });
      }

      const hasChurchDirectorRole = await hasActiveRoleOverScope({
        tenantId,
        userId: actorUserId,
        roleCode: "CHURCH_SABBATH_DIRECTOR",
        targetScopeOrgUnitId: smallGroupOrgUnitId
      });
      if (!hasChurchDirectorRole) {
        return res.status(403).json({ message: "Forbidden: requires CHURCH_SABBATH_DIRECTOR over small group scope" });
      }

      const governance = await canUserAssignRoleAtScope({
        tenantId,
        assignerUserId: actorUserId,
        assignableRoleCode: "SMALL_GROUP_LEADER",
        targetScopeOrgUnitId: smallGroupOrgUnitId
      });
      if (!governance.ok) {
        return res.status(403).json({ message: governance.reason || "Forbidden by assignment rules" });
      }

      const churchRes = await getOrgUnitById({ tenantId, orgUnitId: smallGroup.ParentOrgUnitId });
      if (!churchRes || churchRes.OrgUnitTypeCode !== "CHURCH") {
        return res.status(400).json({ message: "smallGroupOrgUnitId is not linked to a CHURCH" });
      }

      const memberInChurch = await hasActiveMembershipInOrgUnit({
        tenantId,
        userId,
        orgUnitId: churchRes.OrgUnitId
      });
      if (!memberInChurch) {
        return res.status(400).json({ message: "Target user is not a member of the church owning this small group" });
      }

      const targetInGroupChurch = await isOrgUnitDescendantOf({
        tenantId,
        ancestorOrgUnitId: churchRes.OrgUnitId,
        descendantOrgUnitId: smallGroupOrgUnitId
      });
      if (!targetInGroupChurch) {
        return res.status(400).json({ message: "smallGroupOrgUnitId does not belong to resolved church scope" });
      }

      const leaderRole = await getRoleByCode("SMALL_GROUP_LEADER");
      if (!leaderRole) return res.status(500).json({ message: "Role SMALL_GROUP_LEADER not configured" });

      const assignment = await assignRoleToUser({
        tenantId,
        userId,
        roleId: leaderRole.RoleId,
        scopeOrgUnitId: smallGroupOrgUnitId,
        assignedByUserId: actorUserId,
        validFrom,
        validTo
      });

      await safeAudit({
        tenantId,
        actorUserId,
        actionCode: "ROLE_ASSIGNED",
        entityType: "USER_ROLE_ASSIGNMENT",
        entityId: String(assignment.UserRoleAssignmentId),
        targetOrgUnitId: smallGroupOrgUnitId,
        metadata: {
          userId,
          roleCode: "SMALL_GROUP_LEADER",
          scopeOrgUnitId: smallGroupOrgUnitId,
          validFrom,
          validTo
        }
      });

      return res.status(201).json({ userId, assignment });
    } catch (err) {
      if (err?.number === 2601 || err?.number === 2627) {
        return res.status(409).json({ message: "Role already assigned or duplicated data" });
      }
      return res.status(500).json({ message: "Error assigning small group leader", error: err.message });
    }
  }
);

export default router;

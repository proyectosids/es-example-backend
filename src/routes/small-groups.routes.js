import express from "express";

import { authenticate } from "../middleware/auth.middleware.js";
import { requirePermission } from "../middleware/permission.middleware.js";
import {
  getOrgUnitByIdAndType,
  isOrgUnitDescendantOf
} from "../repos/orgUnits.repo.js";
import { getCurrentOrLatestQuarterlyId } from "../repos/quarterlies.repo.js";
import {
  approveRequest,
  createPendingMembershipRequest,
  getRequestById,
  getUserMembershipByQuarter,
  listPendingRequestsBySmallGroup,
  rejectRequest
} from "../repos/smallGroupMemberships.repo.js";
import {
  evaluateQuarterlyMembershipPolicy,
  getQuarterlyMembershipPolicy
} from "../repos/quarterlyMembershipPolicy.repo.js";
import { getUserPrimaryChurchMembership } from "../repos/users.repo.js";
import { safeAudit } from "../utils/audit.js";

const router = express.Router();
router.use(authenticate);

router.get("/me/small-group-membership", async (req, res) => {
  try {
    const tenantId = req.auth.tenantId;
    const userId = req.auth.userId;
    const requestedQuarterly = String(req.query.quarterlyId || "").trim();
    const quarterlyId = requestedQuarterly || (await getCurrentOrLatestQuarterlyId("es"));

    if (!quarterlyId) {
      return res.status(404).json({ message: "No quarterly available" });
    }

    const [current, policy] = await Promise.all([
      getUserMembershipByQuarter({ tenantId, userId, quarterlyId }),
      getQuarterlyMembershipPolicy({ tenantId, quarterlyId })
    ]);
    const policyState = evaluateQuarterlyMembershipPolicy(policy);

    let canRequestChange = true;
    let blockReason = null;
    if (!policyState.isOpen) {
      canRequestChange = false;
      blockReason = policyState.reason;
    } else if (current?.Status === "APPROVED") {
      canRequestChange = false;
      blockReason = "Membership already approved for this quarterly";
    } else if (current?.Status === "PENDING") {
      canRequestChange = false;
      blockReason = "There is already a pending request for this quarterly";
    }

    return res.json({
      quarterlyId,
      membership: current,
      policy: {
        quarterlyId,
        changeOpenAt: policy?.ChangeOpenAt || null,
        changeCloseAt: policy?.ChangeCloseAt || null,
        requireLeaderApproval: policyState.requireLeaderApproval,
        isConfigured: policyState.isConfigured,
        status: policyState.status,
        isOpen: policyState.isOpen
      },
      canRequestChange,
      blockReason
    });
  } catch (err) {
    return res.status(500).json({ message: "Error loading membership", error: err.message });
  }
});

router.post("/me/small-group-change-requests", async (req, res) => {
  try {
    const tenantId = req.auth.tenantId;
    const userId = req.auth.userId;
    const { quarterlyId, smallGroupOrgUnitId, notes = null } = req.body || {};

    if (!quarterlyId || !smallGroupOrgUnitId) {
      return res.status(400).json({ message: "quarterlyId and smallGroupOrgUnitId are required" });
    }

    const churchMembership = await getUserPrimaryChurchMembership({ tenantId, userId });
    if (!churchMembership) {
      return res.status(400).json({ message: "User has no active church membership" });
    }

    const existing = await getUserMembershipByQuarter({ tenantId, userId, quarterlyId: String(quarterlyId) });
    if (existing?.Status === "APPROVED") {
      return res.status(409).json({ message: "Membership already approved for this quarterly" });
    }
    if (existing?.Status === "PENDING") {
      return res.status(409).json({ message: "There is already a pending request for this quarterly" });
    }

    const smallGroup = await getOrgUnitByIdAndType({
      tenantId,
      orgUnitId: smallGroupOrgUnitId,
      orgUnitTypeCode: "SMALL_GROUP"
    });
    if (!smallGroup) return res.status(404).json({ message: "smallGroupOrgUnitId not found" });

    const belongsToChurch = await isOrgUnitDescendantOf({
      tenantId,
      ancestorOrgUnitId: churchMembership.ChurchOrgUnitId,
      descendantOrgUnitId: smallGroupOrgUnitId
    });
    if (!belongsToChurch) {
      return res.status(400).json({ message: "smallGroupOrgUnitId does not belong to user church" });
    }

    const policy = await getQuarterlyMembershipPolicy({
      tenantId,
      quarterlyId: String(quarterlyId)
    });
    const policyState = evaluateQuarterlyMembershipPolicy(policy);
    if (!policyState.isOpen) {
      return res.status(422).json({
        message: policyState.reason,
        policy: {
          quarterlyId: String(quarterlyId),
          changeOpenAt: policy?.ChangeOpenAt || null,
          changeCloseAt: policy?.ChangeCloseAt || null,
          requireLeaderApproval: policyState.requireLeaderApproval,
          status: policyState.status
        }
      });
    }

    const created = await createPendingMembershipRequest({
      tenantId,
      userId,
      churchOrgUnitId: churchMembership.ChurchOrgUnitId,
      smallGroupOrgUnitId,
      quarterlyId: String(quarterlyId),
      requestedByUserId: userId,
      status: policyState.requireLeaderApproval ? "PENDING" : "APPROVED",
      approvedByUserId: policyState.requireLeaderApproval ? null : userId,
      decidedAt: policyState.requireLeaderApproval ? null : new Date(),
      notes
    });
    return res.status(201).json({
      ...created,
      requireLeaderApproval: policyState.requireLeaderApproval
    });
  } catch (err) {
    if (err?.number === 2601 || err?.number === 2627) {
      return res.status(409).json({ message: "A pending/approved request already exists for this quarterly" });
    }
    return res.status(500).json({ message: "Error creating request", error: err.message });
  }
});

router.get(
  "/small-groups/:smallGroupId/membership-requests",
  requirePermission("app.group.members.manage", req => req.params.smallGroupId),
  async (req, res) => {
    try {
      const tenantId = req.auth.tenantId;
      const smallGroupId = req.params.smallGroupId;
      const quarterlyId = String(req.query.quarterlyId || "").trim();

      if (!quarterlyId) return res.status(400).json({ message: "quarterlyId is required" });

      const group = await getOrgUnitByIdAndType({
        tenantId,
        orgUnitId: smallGroupId,
        orgUnitTypeCode: "SMALL_GROUP"
      });
      if (!group) return res.status(404).json({ message: "smallGroupId not found" });

      const items = await listPendingRequestsBySmallGroup({
        tenantId,
        smallGroupOrgUnitId: smallGroupId,
        quarterlyId
      });
      return res.json(items);
    } catch (err) {
      return res.status(500).json({ message: "Error listing requests", error: err.message });
    }
  }
);

router.post(
  "/small-groups/:smallGroupId/membership-requests/:requestId/approve",
  requirePermission("app.group.members.manage", req => req.params.smallGroupId),
  async (req, res) => {
    try {
      const tenantId = req.auth.tenantId;
      const requestId = req.params.requestId;
      const smallGroupId = req.params.smallGroupId;

      const request = await getRequestById({ tenantId, requestId });
      if (!request) return res.status(404).json({ message: "Request not found" });
      if (String(request.SmallGroupOrgUnitId).toLowerCase() !== String(smallGroupId).toLowerCase()) {
        return res.status(400).json({ message: "Request does not belong to provided smallGroupId" });
      }
      if (request.Status !== "PENDING") {
        return res.status(409).json({ message: "Request is not pending" });
      }

      const existing = await getUserMembershipByQuarter({
        tenantId,
        userId: request.UserId,
        quarterlyId: request.QuarterlyId
      });
      if (existing && existing.Status === "APPROVED" && existing.SmallGroupMembershipId !== requestId) {
        return res.status(409).json({ message: "User already has approved group for this quarterly" });
      }

      const out = await approveRequest({
        tenantId,
        requestId,
        approvedByUserId: req.auth.userId,
        notes: req.body?.notes || null
      });
      if (!out) return res.status(409).json({ message: "Request is not pending" });

      await safeAudit({
        tenantId,
        actorUserId: req.auth.userId,
        actionCode: "SMALL_GROUP_MEMBERSHIP_APPROVED",
        entityType: "SMALL_GROUP_MEMBERSHIP",
        entityId: String(requestId),
        targetOrgUnitId: smallGroupId,
        metadata: {
          requestId,
          smallGroupOrgUnitId: smallGroupId,
          targetUserId: request.UserId,
          quarterlyId: request.QuarterlyId,
          notes: req.body?.notes || null
        }
      });

      return res.json(out);
    } catch (err) {
      if (err?.number === 2601 || err?.number === 2627) {
        return res.status(409).json({ message: "User already has approved membership for this quarterly" });
      }
      return res.status(500).json({ message: "Error approving request", error: err.message });
    }
  }
);

router.post(
  "/small-groups/:smallGroupId/membership-requests/:requestId/reject",
  requirePermission("app.group.members.manage", req => req.params.smallGroupId),
  async (req, res) => {
    try {
      const tenantId = req.auth.tenantId;
      const requestId = req.params.requestId;
      const smallGroupId = req.params.smallGroupId;

      const request = await getRequestById({ tenantId, requestId });
      if (!request) return res.status(404).json({ message: "Request not found" });
      if (String(request.SmallGroupOrgUnitId).toLowerCase() !== String(smallGroupId).toLowerCase()) {
        return res.status(400).json({ message: "Request does not belong to provided smallGroupId" });
      }
      if (request.Status !== "PENDING") {
        return res.status(409).json({ message: "Request is not pending" });
      }

      const out = await rejectRequest({
        tenantId,
        requestId,
        approvedByUserId: req.auth.userId,
        notes: req.body?.notes || null
      });
      if (!out) return res.status(409).json({ message: "Request is not pending" });

      await safeAudit({
        tenantId,
        actorUserId: req.auth.userId,
        actionCode: "SMALL_GROUP_MEMBERSHIP_REJECTED",
        entityType: "SMALL_GROUP_MEMBERSHIP",
        entityId: String(requestId),
        targetOrgUnitId: smallGroupId,
        metadata: {
          requestId,
          smallGroupOrgUnitId: smallGroupId,
          targetUserId: request.UserId,
          quarterlyId: request.QuarterlyId,
          notes: req.body?.notes || null
        }
      });

      return res.json(out);
    } catch (err) {
      return res.status(500).json({ message: "Error rejecting request", error: err.message });
    }
  }
);

export default router;

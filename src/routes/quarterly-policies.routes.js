import express from "express";

import { authenticate } from "../middleware/auth.middleware.js";
import { requirePermission } from "../middleware/permission.middleware.js";
import {
  evaluateQuarterlyMembershipPolicy,
  getQuarterlyMembershipPolicy,
  upsertQuarterlyMembershipPolicy
} from "../repos/quarterlyMembershipPolicy.repo.js";

const router = express.Router();
router.use(authenticate);

router.get(
  "/admin/quarterly-membership-policy/:quarterlyId",
  requirePermission("app.org.manage"),
  async (req, res) => {
    try {
      const tenantId = req.auth.tenantId;
      const quarterlyId = String(req.params.quarterlyId || "").trim();
      if (!quarterlyId) return res.status(400).json({ message: "quarterlyId is required" });

      const policy = await getQuarterlyMembershipPolicy({ tenantId, quarterlyId });
      const evaluated = evaluateQuarterlyMembershipPolicy(policy);
      return res.json({
        quarterlyId,
        policy: policy
          ? {
              quarterlyId,
              changeOpenAt: policy.ChangeOpenAt,
              changeCloseAt: policy.ChangeCloseAt,
              requireLeaderApproval: Boolean(policy.RequireLeaderApproval),
              createdAt: policy.CreatedAt,
              updatedAt: policy.UpdatedAt
            }
          : null,
        evaluation: evaluated
      });
    } catch (err) {
      return res.status(500).json({ message: "Error loading quarterly membership policy", error: err.message });
    }
  }
);

router.put(
  "/admin/quarterly-membership-policy/:quarterlyId",
  requirePermission("app.org.manage"),
  async (req, res) => {
    try {
      const tenantId = req.auth.tenantId;
      const quarterlyId = String(req.params.quarterlyId || "").trim();
      const {
        changeOpenAt = null,
        changeCloseAt = null,
        requireLeaderApproval = true
      } = req.body || {};

      if (!quarterlyId) return res.status(400).json({ message: "quarterlyId is required" });

      if (changeOpenAt && Number.isNaN(Date.parse(changeOpenAt))) {
        return res.status(400).json({ message: "changeOpenAt must be a valid date" });
      }
      if (changeCloseAt && Number.isNaN(Date.parse(changeCloseAt))) {
        return res.status(400).json({ message: "changeCloseAt must be a valid date" });
      }
      if (changeOpenAt && changeCloseAt && new Date(changeCloseAt) < new Date(changeOpenAt)) {
        return res.status(400).json({ message: "changeCloseAt must be greater than or equal to changeOpenAt" });
      }

      const policy = await upsertQuarterlyMembershipPolicy({
        tenantId,
        quarterlyId,
        changeOpenAt,
        changeCloseAt,
        requireLeaderApproval: Boolean(requireLeaderApproval)
      });
      const evaluation = evaluateQuarterlyMembershipPolicy(policy);
      return res.json({
        quarterlyId,
        policy: {
          quarterlyId,
          changeOpenAt: policy.ChangeOpenAt,
          changeCloseAt: policy.ChangeCloseAt,
          requireLeaderApproval: Boolean(policy.RequireLeaderApproval),
          createdAt: policy.CreatedAt,
          updatedAt: policy.UpdatedAt
        },
        evaluation
      });
    } catch (err) {
      return res.status(500).json({ message: "Error saving quarterly membership policy", error: err.message });
    }
  }
);

export default router;


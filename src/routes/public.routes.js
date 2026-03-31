import express from "express";
import bcrypt from "bcryptjs";

import { findActiveTenantByCode } from "../repos/tenants.repo.js";
import {
  getOrgUnitByIdAndType,
  isOrgUnitDescendantOf,
  listOrgUnitsByTypeAndParent
} from "../repos/orgUnits.repo.js";
import { getCurrentOrLatestQuarterlyId } from "../repos/quarterlies.repo.js";
import { getRoleByCode } from "../repos/roles.repo.js";
import {
  addUserMembership,
  assignRoleToUser,
  createUser,
  normalizeEmail
} from "../repos/users.repo.js";
import { createPendingMembershipRequest } from "../repos/smallGroupMemberships.repo.js";

const router = express.Router();

function mapOrgUnit(org) {
  return {
    orgUnitId: org.OrgUnitId,
    orgUnitTypeCode: org.OrgUnitTypeCode,
    parentOrgUnitId: org.ParentOrgUnitId,
    code: org.Code,
    name: org.Name,
    path: org.Path
  };
}

async function resolveTenantOr400(res, tenantCode) {
  if (!tenantCode) {
    res.status(400).json({ message: "tenantCode is required" });
    return null;
  }
  const tenant = await findActiveTenantByCode(tenantCode);
  if (!tenant) {
    res.status(404).json({ message: "Tenant not found or inactive" });
    return null;
  }
  return tenant;
}

async function validateChain({
  tenantId,
  unionOrgUnitId,
  fieldOrgUnitId,
  districtOrgUnitId,
  churchOrgUnitId,
  smallGroupOrgUnitId = null
}) {
  const sameId = (a, b) => String(a || "").toLowerCase() === String(b || "").toLowerCase();

  const [union, field, district, church] = await Promise.all([
    getOrgUnitByIdAndType({ tenantId, orgUnitId: unionOrgUnitId, orgUnitTypeCode: "UNION" }),
    getOrgUnitByIdAndType({ tenantId, orgUnitId: fieldOrgUnitId, orgUnitTypeCode: "FIELD" }),
    getOrgUnitByIdAndType({ tenantId, orgUnitId: districtOrgUnitId, orgUnitTypeCode: "DISTRICT" }),
    getOrgUnitByIdAndType({ tenantId, orgUnitId: churchOrgUnitId, orgUnitTypeCode: "CHURCH" })
  ]);

  if (!union || !field || !district || !church) {
    return { ok: false, message: "Invalid org hierarchy selection" };
  }

  if (!sameId(field.ParentOrgUnitId, union.OrgUnitId)) {
    return { ok: false, message: "fieldOrgUnitId does not belong to unionOrgUnitId" };
  }
  if (!sameId(district.ParentOrgUnitId, field.OrgUnitId)) {
    return { ok: false, message: "districtOrgUnitId does not belong to fieldOrgUnitId" };
  }
  if (!sameId(church.ParentOrgUnitId, district.OrgUnitId)) {
    return { ok: false, message: "churchOrgUnitId does not belong to districtOrgUnitId" };
  }

  if (smallGroupOrgUnitId) {
    const smallGroup = await getOrgUnitByIdAndType({
      tenantId,
      orgUnitId: smallGroupOrgUnitId,
      orgUnitTypeCode: "SMALL_GROUP"
    });
    if (!smallGroup) {
      return { ok: false, message: "Invalid smallGroupOrgUnitId" };
    }
    const inChurch = await isOrgUnitDescendantOf({
      tenantId,
      ancestorOrgUnitId: churchOrgUnitId,
      descendantOrgUnitId: smallGroupOrgUnitId
    });
    if (!inChurch) {
      return { ok: false, message: "smallGroupOrgUnitId does not belong to churchOrgUnitId" };
    }
  }

  return { ok: true };
}

router.get("/public/org/unions", async (req, res) => {
  try {
    const tenant = await resolveTenantOr400(res, String(req.query.tenantCode || "").trim());
    if (!tenant) return;

    const items = await listOrgUnitsByTypeAndParent({
      tenantId: tenant.TenantId,
      orgUnitTypeCode: "UNION",
      parentOrgUnitId: null
    });
    return res.json(items.map(mapOrgUnit));
  } catch (err) {
    return res.status(500).json({ message: "Error listing unions", error: err.message });
  }
});

router.get("/public/org/fields", async (req, res) => {
  try {
    const tenant = await resolveTenantOr400(res, String(req.query.tenantCode || "").trim());
    if (!tenant) return;

    const unionId = String(req.query.unionId || "");
    if (!unionId) return res.status(400).json({ message: "unionId is required" });

    const union = await getOrgUnitByIdAndType({
      tenantId: tenant.TenantId,
      orgUnitId: unionId,
      orgUnitTypeCode: "UNION"
    });
    if (!union) return res.status(404).json({ message: "unionId not found" });

    const items = await listOrgUnitsByTypeAndParent({
      tenantId: tenant.TenantId,
      orgUnitTypeCode: "FIELD",
      parentOrgUnitId: unionId
    });
    return res.json(items.map(mapOrgUnit));
  } catch (err) {
    return res.status(500).json({ message: "Error listing fields", error: err.message });
  }
});

router.get("/public/org/districts", async (req, res) => {
  try {
    const tenant = await resolveTenantOr400(res, String(req.query.tenantCode || "").trim());
    if (!tenant) return;

    const fieldId = String(req.query.fieldId || "");
    if (!fieldId) return res.status(400).json({ message: "fieldId is required" });

    const field = await getOrgUnitByIdAndType({
      tenantId: tenant.TenantId,
      orgUnitId: fieldId,
      orgUnitTypeCode: "FIELD"
    });
    if (!field) return res.status(404).json({ message: "fieldId not found" });

    const items = await listOrgUnitsByTypeAndParent({
      tenantId: tenant.TenantId,
      orgUnitTypeCode: "DISTRICT",
      parentOrgUnitId: fieldId
    });
    return res.json(items.map(mapOrgUnit));
  } catch (err) {
    return res.status(500).json({ message: "Error listing districts", error: err.message });
  }
});

router.get("/public/org/churches", async (req, res) => {
  try {
    const tenant = await resolveTenantOr400(res, String(req.query.tenantCode || "").trim());
    if (!tenant) return;

    const districtId = String(req.query.districtId || "");
    if (!districtId) return res.status(400).json({ message: "districtId is required" });

    const district = await getOrgUnitByIdAndType({
      tenantId: tenant.TenantId,
      orgUnitId: districtId,
      orgUnitTypeCode: "DISTRICT"
    });
    if (!district) return res.status(404).json({ message: "districtId not found" });

    const items = await listOrgUnitsByTypeAndParent({
      tenantId: tenant.TenantId,
      orgUnitTypeCode: "CHURCH",
      parentOrgUnitId: districtId
    });
    return res.json(items.map(mapOrgUnit));
  } catch (err) {
    return res.status(500).json({ message: "Error listing churches", error: err.message });
  }
});

router.get("/public/org/small-groups", async (req, res) => {
  try {
    const tenant = await resolveTenantOr400(res, String(req.query.tenantCode || "").trim());
    if (!tenant) return;

    const churchId = String(req.query.churchId || "");
    if (!churchId) return res.status(400).json({ message: "churchId is required" });

    const church = await getOrgUnitByIdAndType({
      tenantId: tenant.TenantId,
      orgUnitId: churchId,
      orgUnitTypeCode: "CHURCH"
    });
    if (!church) return res.status(404).json({ message: "churchId not found" });

    const items = await listOrgUnitsByTypeAndParent({
      tenantId: tenant.TenantId,
      orgUnitTypeCode: "SMALL_GROUP",
      parentOrgUnitId: churchId
    });
    return res.json(items.map(mapOrgUnit));
  } catch (err) {
    return res.status(500).json({ message: "Error listing small groups", error: err.message });
  }
});

router.post("/public/auth/register-member", async (req, res) => {
  try {
    const {
      tenantCode,
      email,
      password,
      firstName = null,
      lastName = null,
      displayName = null,
      phone = null,
      unionOrgUnitId,
      fieldOrgUnitId,
      districtOrgUnitId,
      churchOrgUnitId,
      smallGroupOrgUnitId = null,
      quarterlyId = null,
      notes = null
    } = req.body || {};

    if (
      !tenantCode || !email || !password ||
      !unionOrgUnitId || !fieldOrgUnitId || !districtOrgUnitId || !churchOrgUnitId
    ) {
      return res.status(400).json({
        message: "tenantCode, email, password, unionOrgUnitId, fieldOrgUnitId, districtOrgUnitId and churchOrgUnitId are required"
      });
    }

    const tenant = await findActiveTenantByCode(String(tenantCode).trim());
    if (!tenant) return res.status(404).json({ message: "Tenant not found or inactive" });

    const chain = await validateChain({
      tenantId: tenant.TenantId,
      unionOrgUnitId,
      fieldOrgUnitId,
      districtOrgUnitId,
      churchOrgUnitId,
      smallGroupOrgUnitId
    });
    if (!chain.ok) return res.status(400).json({ message: chain.message });

    const memberRole = await getRoleByCode("CHURCH_MEMBER");
    if (!memberRole) {
      return res.status(500).json({ message: "Role CHURCH_MEMBER not configured" });
    }

    let resolvedQuarterlyId = null;
    if (smallGroupOrgUnitId) {
      resolvedQuarterlyId = String(
        quarterlyId || (await getCurrentOrLatestQuarterlyId("es")) || ""
      ).trim();
      if (!resolvedQuarterlyId) {
        return res.status(400).json({
          message: "quarterlyId is required when smallGroupOrgUnitId is provided and no quarterly is available"
        });
      }
    }

    const passwordHash = await bcrypt.hash(String(password), 10);
    const user = await createUser({
      tenantId: tenant.TenantId,
      email: String(email).trim(),
      emailNormalized: normalizeEmail(email),
      passwordHash,
      firstName,
      lastName,
      displayName,
      phone
    });

    await addUserMembership({
      tenantId: tenant.TenantId,
      userId: user.UserId,
      orgUnitId: churchOrgUnitId,
      membershipType: "MEMBER",
      isPrimary: true
    });

    await assignRoleToUser({
      tenantId: tenant.TenantId,
      userId: user.UserId,
      roleId: memberRole.RoleId,
      scopeOrgUnitId: churchOrgUnitId
    });

    let smallGroupRequestStatus = null;
    if (smallGroupOrgUnitId) {
      await createPendingMembershipRequest({
        tenantId: tenant.TenantId,
        userId: user.UserId,
        churchOrgUnitId,
        smallGroupOrgUnitId,
        quarterlyId: resolvedQuarterlyId,
        requestedByUserId: user.UserId,
        notes
      });
      smallGroupRequestStatus = "PENDING";
    }

    return res.status(201).json({
      userId: user.UserId,
      status: "REGISTERED",
      smallGroupRequestStatus
    });
  } catch (err) {
    if (err?.number === 2627 || err?.number === 2601) {
      return res.status(409).json({ message: "Email already exists in this tenant" });
    }
    return res.status(500).json({ message: "Error registering member", error: err.message });
  }
});

export default router;

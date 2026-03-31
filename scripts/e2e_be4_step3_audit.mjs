import "dotenv/config";
import axios from "axios";
import bcrypt from "bcryptjs";
import { getPool, sql } from "../src/db/pool.js";

const baseUrl = process.env.E2E_BASE_URL || "http://localhost:3000";
const tenantCode = process.env.E2E_TENANT_CODE || "ulv-demo";

function logSection(title) {
  console.log(`\n=== ${title} ===`);
}

async function http(method, url, token = null, data = null) {
  const res = await axios({
    method,
    url,
    data,
    headers: token ? { Authorization: `Bearer ${token}` } : undefined,
    validateStatus: () => true
  });
  return res;
}

function assertCondition(label, condition, detail = null) {
  if (condition) {
    console.log(`[OK]   ${label}`);
    return true;
  }
  console.log(`[FAIL] ${label}`);
  if (detail) console.log(detail);
  return false;
}

async function getTenant(pool) {
  const res = await pool.request()
    .input("Code", sql.NVarChar(50), tenantCode)
    .query(`
      SELECT TOP 1 TenantId, Code
      FROM dbo.Tenants
      WHERE Code=@Code AND Status='ACTIVE'
    `);
  return res.recordset[0] || null;
}

async function getRoleId(pool, roleCode) {
  const res = await pool.request()
    .input("Code", sql.NVarChar(80), roleCode)
    .query(`SELECT TOP 1 RoleId FROM dbo.Roles WHERE Code=@Code`);
  return res.recordset[0]?.RoleId || null;
}

async function getScope(pool, tenantId) {
  const churchRes = await pool.request()
    .input("TenantId", sql.UniqueIdentifier, tenantId)
    .query(`
      SELECT TOP 1 OrgUnitId, Name
      FROM dbo.OrgUnits
      WHERE TenantId=@TenantId
        AND OrgUnitTypeCode='CHURCH'
        AND IsActive=1
      ORDER BY Name
    `);
  const church = churchRes.recordset[0];
  if (!church) throw new Error("No CHURCH available");

  const fieldRes = await pool.request()
    .input("TenantId", sql.UniqueIdentifier, tenantId)
    .input("ChurchId", sql.UniqueIdentifier, church.OrgUnitId)
    .query(`
      SELECT TOP 1 o.OrgUnitId, o.Name
      FROM dbo.OrgUnitClosure oc
      JOIN dbo.OrgUnits o ON o.OrgUnitId = oc.AncestorOrgUnitId
      WHERE oc.TenantId=@TenantId
        AND oc.DescendantOrgUnitId=@ChurchId
        AND o.OrgUnitTypeCode='FIELD'
      ORDER BY oc.Depth ASC
    `);
  const field = fieldRes.recordset[0];
  if (!field) throw new Error("No FIELD for selected CHURCH");

  const smallGroupRes = await pool.request()
    .input("TenantId", sql.UniqueIdentifier, tenantId)
    .input("ChurchId", sql.UniqueIdentifier, church.OrgUnitId)
    .query(`
      SELECT TOP 1 OrgUnitId, Name
      FROM dbo.OrgUnits
      WHERE TenantId=@TenantId
        AND OrgUnitTypeCode='SMALL_GROUP'
        AND ParentOrgUnitId=@ChurchId
        AND IsActive=1
      ORDER BY Name
    `);
  const smallGroup = smallGroupRes.recordset[0];
  if (!smallGroup) throw new Error("No SMALL_GROUP for selected CHURCH");

  return { church, field, smallGroup };
}

async function upsertUser(pool, tenantId, { email, password, displayName }) {
  const normalized = String(email).trim().toUpperCase();
  const existing = await pool.request()
    .input("TenantId", sql.UniqueIdentifier, tenantId)
    .input("EmailNormalized", sql.NVarChar(254), normalized)
    .query(`
      SELECT TOP 1 UserId, Email
      FROM dbo.Users
      WHERE TenantId=@TenantId AND EmailNormalized=@EmailNormalized
    `);
  if (existing.recordset[0]) return existing.recordset[0];

  const hash = await bcrypt.hash(password, 10);
  const created = await pool.request()
    .input("TenantId", sql.UniqueIdentifier, tenantId)
    .input("Email", sql.NVarChar(254), email)
    .input("EmailNormalized", sql.NVarChar(254), normalized)
    .input("PasswordHash", sql.NVarChar(255), hash)
    .input("DisplayName", sql.NVarChar(200), displayName)
    .query(`
      INSERT INTO dbo.Users (TenantId, Email, EmailNormalized, PasswordHash, DisplayName)
      OUTPUT INSERTED.UserId, INSERTED.Email
      VALUES (@TenantId, @Email, @EmailNormalized, @PasswordHash, @DisplayName)
    `);
  return created.recordset[0];
}

async function ensureMembership(pool, tenantId, userId, orgUnitId, membershipType = "MEMBER") {
  const res = await pool.request()
    .input("TenantId", sql.UniqueIdentifier, tenantId)
    .input("UserId", sql.UniqueIdentifier, userId)
    .input("OrgUnitId", sql.UniqueIdentifier, orgUnitId)
    .query(`
      SELECT TOP 1 1 AS ok
      FROM dbo.UserOrgMemberships
      WHERE TenantId=@TenantId
        AND UserId=@UserId
        AND OrgUnitId=@OrgUnitId
        AND IsActive=1
    `);
  if (res.recordset.length) return;

  await pool.request()
    .input("TenantId", sql.UniqueIdentifier, tenantId)
    .input("UserId", sql.UniqueIdentifier, userId)
    .input("OrgUnitId", sql.UniqueIdentifier, orgUnitId)
    .input("MembershipType", sql.NVarChar(40), membershipType)
    .query(`
      INSERT INTO dbo.UserOrgMemberships (TenantId, UserId, OrgUnitId, MembershipType, IsPrimary)
      VALUES (@TenantId, @UserId, @OrgUnitId, @MembershipType, 0)
    `);
}

async function ensureRole(pool, tenantId, userId, roleId, scopeOrgUnitId) {
  const res = await pool.request()
    .input("TenantId", sql.UniqueIdentifier, tenantId)
    .input("UserId", sql.UniqueIdentifier, userId)
    .input("RoleId", sql.UniqueIdentifier, roleId)
    .input("ScopeOrgUnitId", sql.UniqueIdentifier, scopeOrgUnitId)
    .query(`
      SELECT TOP 1 1 AS ok
      FROM dbo.UserRoleAssignments
      WHERE TenantId=@TenantId
        AND UserId=@UserId
        AND RoleId=@RoleId
        AND ScopeOrgUnitId=@ScopeOrgUnitId
        AND IsActive=1
    `);
  if (res.recordset.length) return;

  await pool.request()
    .input("TenantId", sql.UniqueIdentifier, tenantId)
    .input("UserId", sql.UniqueIdentifier, userId)
    .input("RoleId", sql.UniqueIdentifier, roleId)
    .input("ScopeOrgUnitId", sql.UniqueIdentifier, scopeOrgUnitId)
    .query(`
      INSERT INTO dbo.UserRoleAssignments (TenantId, UserId, RoleId, ScopeOrgUnitId)
      VALUES (@TenantId, @UserId, @RoleId, @ScopeOrgUnitId)
    `);
  }

async function login(email, password) {
  const res = await http("post", `${baseUrl}/api/v1/auth/login`, null, {
    tenantCode,
    email,
    password
  });
  if (res.status !== 200 || !res.data?.accessToken) {
    throw new Error(`Login failed for ${email}: ${res.status}`);
  }
  return res.data.accessToken;
}

async function countAuditEvents(pool, tenantId, actionCode, actorUserId = null) {
  const req = pool.request()
    .input("TenantId", sql.UniqueIdentifier, tenantId)
    .input("ActionCode", sql.NVarChar(120), actionCode);
  let extra = "";
  if (actorUserId) {
    req.input("ActorUserId", sql.UniqueIdentifier, actorUserId);
    extra = "AND ActorUserId=@ActorUserId";
  }
  const res = await req.query(`
    SELECT COUNT(1) AS Total
    FROM dbo.AuditEvents
    WHERE TenantId=@TenantId
      AND ActionCode=@ActionCode
      ${extra}
  `);
  return Number(res.recordset[0]?.Total || 0);
}

async function getLatestAuditEvent(pool, tenantId, actionCode) {
  const res = await pool.request()
    .input("TenantId", sql.UniqueIdentifier, tenantId)
    .input("ActionCode", sql.NVarChar(120), actionCode)
    .query(`
      SELECT TOP 1 AuditEventId, ActionCode, EntityType, EntityId, TargetOrgUnitId, MetadataJson, CreatedAt
      FROM dbo.AuditEvents
      WHERE TenantId=@TenantId
        AND ActionCode=@ActionCode
      ORDER BY CreatedAt DESC
    `);
  return res.recordset[0] || null;
}

async function main() {
  logSection("Health");
  const health = await http("get", `${baseUrl}/health`);
  if (health.status !== 200 || health.data?.ok !== true) {
    throw new Error("Backend health failed");
  }

  const pool = await getPool();
  const tenant = await getTenant(pool);
  if (!tenant) throw new Error(`Tenant ${tenantCode} not found`);
  const scope = await getScope(pool, tenant.TenantId);

  const creds = {
    field: { email: "field_audit@demo.local", pass: "Temp12345!", name: "Field Audit" },
    pastor: { email: "pastor_audit@demo.local", pass: "Temp12345!", name: "Pastor Audit" },
    leader: { email: "leader_audit@demo.local", pass: "Temp12345!", name: "Leader Audit" },
    memberA: { email: "member_audit_a@demo.local", pass: "Temp12345!", name: "Member Audit A" },
    memberB: { email: "member_audit_b@demo.local", pass: "Temp12345!", name: "Member Audit B" }
  };

  logSection("Bootstrap actors");
  const [fieldUser, pastorUser, leaderUser, memberA, memberB] = await Promise.all([
    upsertUser(pool, tenant.TenantId, { email: creds.field.email, password: creds.field.pass, displayName: creds.field.name }),
    upsertUser(pool, tenant.TenantId, { email: creds.pastor.email, password: creds.pastor.pass, displayName: creds.pastor.name }),
    upsertUser(pool, tenant.TenantId, { email: creds.leader.email, password: creds.leader.pass, displayName: creds.leader.name }),
    upsertUser(pool, tenant.TenantId, { email: creds.memberA.email, password: creds.memberA.pass, displayName: creds.memberA.name }),
    upsertUser(pool, tenant.TenantId, { email: creds.memberB.email, password: creds.memberB.pass, displayName: creds.memberB.name })
  ]);

  await Promise.all([
    ensureMembership(pool, tenant.TenantId, pastorUser.UserId, scope.church.OrgUnitId, "PASTOR"),
    ensureMembership(pool, tenant.TenantId, leaderUser.UserId, scope.church.OrgUnitId, "LEADER"),
    ensureMembership(pool, tenant.TenantId, memberA.UserId, scope.church.OrgUnitId, "MEMBER"),
    ensureMembership(pool, tenant.TenantId, memberB.UserId, scope.church.OrgUnitId, "MEMBER")
  ]);

  const [fieldRoleId, pastorRoleId, groupLeaderRoleId] = await Promise.all([
    getRoleId(pool, "FIELD_SABBATH_DIRECTOR"),
    getRoleId(pool, "PASTOR"),
    getRoleId(pool, "SMALL_GROUP_LEADER")
  ]);
  if (!fieldRoleId || !pastorRoleId || !groupLeaderRoleId) {
    throw new Error("Required roles missing");
  }

  await Promise.all([
    ensureRole(pool, tenant.TenantId, fieldUser.UserId, fieldRoleId, scope.field.OrgUnitId),
    ensureRole(pool, tenant.TenantId, pastorUser.UserId, pastorRoleId, scope.church.OrgUnitId),
    ensureRole(pool, tenant.TenantId, leaderUser.UserId, groupLeaderRoleId, scope.smallGroup.OrgUnitId)
  ]);

  const [fieldToken, leaderToken, memberAToken, memberBToken] = await Promise.all([
    login(creds.field.email, creds.field.pass),
    login(creds.leader.email, creds.leader.pass),
    login(creds.memberA.email, creds.memberA.pass),
    login(creds.memberB.email, creds.memberB.pass)
  ]);

  let ok = 0;
  let fail = 0;
  const check = (label, condition, detail = null) => {
    const result = assertCondition(label, condition, detail);
    if (result) ok += 1;
    else fail += 1;
  };

  const beforeAdminCreated = await countAuditEvents(pool, tenant.TenantId, "ADMIN_USER_CREATED");
  const beforeRoleAssigned = await countAuditEvents(pool, tenant.TenantId, "ROLE_ASSIGNED");
  const beforeApproved = await countAuditEvents(pool, tenant.TenantId, "SMALL_GROUP_MEMBERSHIP_APPROVED");
  const beforeRejected = await countAuditEvents(pool, tenant.TenantId, "SMALL_GROUP_MEMBERSHIP_REJECTED");

  logSection("Action 1 create pastor through specialized endpoint");
  const newPastorEmail = `pastor_audit_new_${Date.now()}@demo.local`;
  const a1 = await http("post", `${baseUrl}/api/v1/field-admin/pastors`, fieldToken, {
    churchOrgUnitId: scope.church.OrgUnitId,
    email: newPastorEmail,
    password: "Temp12345!",
    firstName: "Pastor",
    lastName: "Audit",
    displayName: "Pastor Audit New"
  });
  check("A1 create pastor returned 201", a1.status === 201, a1.data);

  const afterAdminCreated = await countAuditEvents(pool, tenant.TenantId, "ADMIN_USER_CREATED");
  const afterRoleAssigned1 = await countAuditEvents(pool, tenant.TenantId, "ROLE_ASSIGNED");
  check("A2 ADMIN_USER_CREATED audit inserted", afterAdminCreated === beforeAdminCreated + 1, { beforeAdminCreated, afterAdminCreated });
  check("A3 ROLE_ASSIGNED audit inserted for pastor", afterRoleAssigned1 === beforeRoleAssigned + 1, { beforeRoleAssigned, afterRoleAssigned1 });

  logSection("Action 2 create pending requests and approve/reject");
  const quarterlyId = `2099-AUD-${Date.now()}`;
  const r1 = await http("post", `${baseUrl}/api/v1/me/small-group-change-requests`, memberAToken, {
    quarterlyId,
    smallGroupOrgUnitId: scope.smallGroup.OrgUnitId
  });
  check("B1 member A request created", r1.status === 201, r1.data);

  const r2 = await http("post", `${baseUrl}/api/v1/me/small-group-change-requests`, memberBToken, {
    quarterlyId: `${quarterlyId}-R`,
    smallGroupOrgUnitId: scope.smallGroup.OrgUnitId
  });
  check("B2 member B request created", r2.status === 201, r2.data);

  const approveResp = await http(
    "post",
    `${baseUrl}/api/v1/small-groups/${scope.smallGroup.OrgUnitId}/membership-requests/${r1.data.SmallGroupMembershipId}/approve`,
    leaderToken,
    { notes: "approved in audit e2e" }
  );
  check("B3 approve request returned 200", approveResp.status === 200, approveResp.data);

  const rejectResp = await http(
    "post",
    `${baseUrl}/api/v1/small-groups/${scope.smallGroup.OrgUnitId}/membership-requests/${r2.data.SmallGroupMembershipId}/reject`,
    leaderToken,
    { notes: "rejected in audit e2e" }
  );
  check("B4 reject request returned 200", rejectResp.status === 200, rejectResp.data);

  const afterApproved = await countAuditEvents(pool, tenant.TenantId, "SMALL_GROUP_MEMBERSHIP_APPROVED");
  const afterRejected = await countAuditEvents(pool, tenant.TenantId, "SMALL_GROUP_MEMBERSHIP_REJECTED");
  check("B5 approval audit inserted", afterApproved === beforeApproved + 1, { beforeApproved, afterApproved });
  check("B6 rejection audit inserted", afterRejected === beforeRejected + 1, { beforeRejected, afterRejected });

  const latestApproval = await getLatestAuditEvent(pool, tenant.TenantId, "SMALL_GROUP_MEMBERSHIP_APPROVED");
  const latestRejection = await getLatestAuditEvent(pool, tenant.TenantId, "SMALL_GROUP_MEMBERSHIP_REJECTED");
  check(
    "B7 approval audit metadata references request id",
    Boolean(latestApproval?.MetadataJson && latestApproval.MetadataJson.includes(r1.data.SmallGroupMembershipId)),
    latestApproval
  );
  check(
    "B8 rejection audit metadata references request id",
    Boolean(latestRejection?.MetadataJson && latestRejection.MetadataJson.includes(r2.data.SmallGroupMembershipId)),
    latestRejection
  );

  logSection("Summary");
  console.log({ ok, fail });
  process.exit(fail > 0 ? 1 : 0);
}

main().catch((err) => {
  console.error("E2E step3 failed:", err.message);
  process.exit(1);
});


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

function assertStatus(caseName, expected, response) {
  const ok = response.status === expected;
  if (ok) {
    console.log(`[OK]   ${caseName} -> ${response.status}`);
  } else {
    console.log(`[FAIL] ${caseName} -> esperado ${expected}, actual ${response.status}`);
    console.log("Body:", response.data);
  }
  return ok;
}

async function getTenant(pool) {
  const res = await pool.request()
    .input("Code", sql.NVarChar(50), tenantCode)
    .query(`
      SELECT TOP 1 TenantId, Code
      FROM dbo.Tenants
      WHERE Code=@Code
        AND Status='ACTIVE'
    `);
  return res.recordset[0] || null;
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

async function ensureMembership(pool, tenantId, userId, churchOrgUnitId) {
  const res = await pool.request()
    .input("TenantId", sql.UniqueIdentifier, tenantId)
    .input("UserId", sql.UniqueIdentifier, userId)
    .input("OrgUnitId", sql.UniqueIdentifier, churchOrgUnitId)
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
    .input("OrgUnitId", sql.UniqueIdentifier, churchOrgUnitId)
    .query(`
      INSERT INTO dbo.UserOrgMemberships (TenantId, UserId, OrgUnitId, MembershipType, IsPrimary)
      VALUES (@TenantId, @UserId, @OrgUnitId, 'MEMBER', 1)
    `);
}

async function getRoleId(pool, roleCode) {
  const res = await pool.request()
    .input("Code", sql.NVarChar(80), roleCode)
    .query(`SELECT TOP 1 RoleId FROM dbo.Roles WHERE Code=@Code`);
  return res.recordset[0]?.RoleId || null;
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
  if (!smallGroup) throw new Error("No SMALL_GROUP available");
  return { church, smallGroup };
}

async function login(email, password) {
  const res = await http("post", `${baseUrl}/api/v1/auth/login`, null, {
    tenantCode,
    email,
    password
  });
  if (res.status !== 200 || !res.data?.accessToken) {
    throw new Error(`Login failed ${email}: ${res.status} ${JSON.stringify(res.data)}`);
  }
  return res.data.accessToken;
}

async function cleanupMembershipByQuarter(pool, tenantId, userId, quarterlyId) {
  await pool.request()
    .input("TenantId", sql.UniqueIdentifier, tenantId)
    .input("UserId", sql.UniqueIdentifier, userId)
    .input("QuarterlyId", sql.NVarChar(30), quarterlyId)
    .query(`
      DELETE FROM dbo.SmallGroupMemberships
      WHERE TenantId=@TenantId
        AND UserId=@UserId
        AND QuarterlyId=@QuarterlyId
    `);
}

async function main() {
  logSection("Health");
  const health = await http("get", `${baseUrl}/health`);
  if (health.status !== 200 || health.data?.ok !== true) {
    throw new Error(`Health failed: ${health.status}`);
  }

  const pool = await getPool();
  const tenant = await getTenant(pool);
  if (!tenant) throw new Error(`Tenant ${tenantCode} not found`);
  const scope = await getScope(pool, tenant.TenantId);
  const quarterlyId = "2099-01";

  const adminCreds = {
    email: "org_manager_policy@demo.local",
    pass: "Temp12345!",
    name: "Org Manager Policy"
  };
  const memberCreds = {
    email: "member_policy@demo.local",
    pass: "Temp12345!",
    name: "Member Policy"
  };

  logSection("Bootstrap policy actors");
  const [adminUser, memberUser] = await Promise.all([
    upsertUser(pool, tenant.TenantId, { email: adminCreds.email, password: adminCreds.pass, displayName: adminCreds.name }),
    upsertUser(pool, tenant.TenantId, { email: memberCreds.email, password: memberCreds.pass, displayName: memberCreds.name })
  ]);
  await ensureMembership(pool, tenant.TenantId, memberUser.UserId, scope.church.OrgUnitId);

  const pastorRoleId = await getRoleId(pool, "PASTOR");
  if (!pastorRoleId) throw new Error("PASTOR role missing");
  await ensureRole(pool, tenant.TenantId, adminUser.UserId, pastorRoleId, scope.church.OrgUnitId);

  const adminToken = await login(adminCreds.email, adminCreds.pass);
  const memberToken = await login(memberCreds.email, memberCreds.pass);

  let ok = 0;
  let fail = 0;
  const check = (name, expected, resp) => {
    const result = assertStatus(name, expected, resp);
    if (result) ok += 1;
    else fail += 1;
  };

  await cleanupMembershipByQuarter(pool, tenant.TenantId, memberUser.UserId, quarterlyId);

  logSection("P1 policy not open yet");
  const futureOpen = new Date(Date.now() + 2 * 24 * 60 * 60 * 1000).toISOString();
  const futureClose = new Date(Date.now() + 5 * 24 * 60 * 60 * 1000).toISOString();
  const p1 = await http("put", `${baseUrl}/api/v1/admin/quarterly-membership-policy/${quarterlyId}`, adminToken, {
    changeOpenAt: futureOpen,
    changeCloseAt: futureClose,
    requireLeaderApproval: true
  });
  check("P1 save future-open policy", 200, p1);

  const p2 = await http("post", `${baseUrl}/api/v1/me/small-group-change-requests`, memberToken, {
    quarterlyId,
    smallGroupOrgUnitId: scope.smallGroup.OrgUnitId
  });
  check("P2 request blocked before open", 422, p2);

  logSection("P2 policy open with leader approval");
  const openAt = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
  const closeAt = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();
  const p3 = await http("put", `${baseUrl}/api/v1/admin/quarterly-membership-policy/${quarterlyId}`, adminToken, {
    changeOpenAt: openAt,
    changeCloseAt: closeAt,
    requireLeaderApproval: true
  });
  check("P3 save open policy", 200, p3);

  await cleanupMembershipByQuarter(pool, tenant.TenantId, memberUser.UserId, quarterlyId);
  const p4 = await http("post", `${baseUrl}/api/v1/me/small-group-change-requests`, memberToken, {
    quarterlyId,
    smallGroupOrgUnitId: scope.smallGroup.OrgUnitId
  });
  check("P4 request allowed in open window", 201, p4);
  if (p4.status === 201 && p4.data?.Status !== "PENDING") {
    console.log("[FAIL] P4 expected Status=PENDING");
    fail += 1;
  } else if (p4.status === 201) {
    console.log("[OK]   P4 status payload is PENDING");
    ok += 1;
  }

  const p5 = await http("get", `${baseUrl}/api/v1/me/small-group-membership?quarterlyId=${quarterlyId}`, memberToken);
  check("P5 membership payload includes policy", 200, p5);
  if (p5.status === 200 && p5.data?.policy?.status === "OPEN" && p5.data?.canRequestChange === false) {
    console.log("[OK]   P5 payload reflects open policy + pending block");
    ok += 1;
  } else if (p5.status === 200) {
    console.log("[FAIL] P5 payload did not reflect expected policy/membership state", p5.data);
    fail += 1;
  }

  logSection("P3 policy closed");
  await cleanupMembershipByQuarter(pool, tenant.TenantId, memberUser.UserId, quarterlyId);
  const closedOpen = new Date(Date.now() - 5 * 24 * 60 * 60 * 1000).toISOString();
  const closedClose = new Date(Date.now() - 2 * 24 * 60 * 60 * 1000).toISOString();
  const p6 = await http("put", `${baseUrl}/api/v1/admin/quarterly-membership-policy/${quarterlyId}`, adminToken, {
    changeOpenAt: closedOpen,
    changeCloseAt: closedClose,
    requireLeaderApproval: true
  });
  check("P6 save closed policy", 200, p6);

  const p7 = await http("post", `${baseUrl}/api/v1/me/small-group-change-requests`, memberToken, {
    quarterlyId,
    smallGroupOrgUnitId: scope.smallGroup.OrgUnitId
  });
  check("P7 request blocked after close", 422, p7);

  logSection("P4 auto-approve");
  await cleanupMembershipByQuarter(pool, tenant.TenantId, memberUser.UserId, quarterlyId);
  const p8 = await http("put", `${baseUrl}/api/v1/admin/quarterly-membership-policy/${quarterlyId}`, adminToken, {
    changeOpenAt: openAt,
    changeCloseAt: closeAt,
    requireLeaderApproval: false
  });
  check("P8 save auto-approve policy", 200, p8);

  const p9 = await http("post", `${baseUrl}/api/v1/me/small-group-change-requests`, memberToken, {
    quarterlyId,
    smallGroupOrgUnitId: scope.smallGroup.OrgUnitId
  });
  check("P9 request auto-approved", 201, p9);
  if (p9.status === 201 && p9.data?.Status !== "APPROVED") {
    console.log("[FAIL] P9 expected Status=APPROVED");
    fail += 1;
  } else if (p9.status === 201) {
    console.log("[OK]   P9 status payload is APPROVED");
    ok += 1;
  }

  logSection("Summary");
  console.log({ ok, fail });
  process.exit(fail > 0 ? 1 : 0);
}

main().catch((err) => {
  console.error("E2E step2 failed:", err.message);
  process.exit(1);
});


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
  try {
    const res = await axios({
      method,
      url,
      data,
      headers: token ? { Authorization: `Bearer ${token}` } : undefined,
      validateStatus: () => true
    });
    return res;
  } catch (err) {
    return { status: 0, data: { message: err.message } };
  }
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
      SELECT TOP 1 TenantId, Code, Name
      FROM dbo.Tenants
      WHERE Code=@Code AND Status='ACTIVE'
    `);
  return res.recordset[0] || null;
}

async function getScopedOrg(pool, tenantId) {
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
  if (!church) throw new Error("No CHURCH org unit found");

  const groupRes = await pool.request()
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
  const smallGroup = groupRes.recordset[0];
  if (!smallGroup) throw new Error("No SMALL_GROUP under selected CHURCH");

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
        AND o.IsActive=1
      ORDER BY oc.Depth ASC
    `);
  const field = fieldRes.recordset[0];
  if (!field) throw new Error("No FIELD ancestor for selected CHURCH");

  return { church, smallGroup, field };
}

async function getRoleId(pool, roleCode) {
  const res = await pool.request()
    .input("Code", sql.NVarChar(80), roleCode)
    .query(`SELECT TOP 1 RoleId FROM dbo.Roles WHERE Code=@Code`);
  return res.recordset[0]?.RoleId || null;
}

async function upsertUser(pool, tenantId, { email, password, displayName }) {
  const emailNormalized = String(email).trim().toUpperCase();
  const existing = await pool.request()
    .input("TenantId", sql.UniqueIdentifier, tenantId)
    .input("EmailNormalized", sql.NVarChar(254), emailNormalized)
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
    .input("EmailNormalized", sql.NVarChar(254), emailNormalized)
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
  const exists = await pool.request()
    .input("TenantId", sql.UniqueIdentifier, tenantId)
    .input("UserId", sql.UniqueIdentifier, userId)
    .input("OrgUnitId", sql.UniqueIdentifier, orgUnitId)
    .query(`
      SELECT TOP 1 1 AS ok
      FROM dbo.UserOrgMemberships
      WHERE TenantId=@TenantId AND UserId=@UserId AND OrgUnitId=@OrgUnitId AND IsActive=1
    `);
  if (exists.recordset.length) return;

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
  const exists = await pool.request()
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
  if (exists.recordset.length) return;

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
    throw new Error(`Login failed for ${email}: ${res.status} ${JSON.stringify(res.data)}`);
  }
  return res.data.accessToken;
}

async function main() {
  logSection("Health");
  const h = await http("get", `${baseUrl}/health`);
  if (h.status !== 200 || h.data?.ok !== true) {
    throw new Error(`Health failed: ${h.status} ${JSON.stringify(h.data)}`);
  }
  console.log(h.data);

  logSection("Bootstrap E2E context");
  const pool = await getPool();
  const tenant = await getTenant(pool);
  if (!tenant) throw new Error(`Tenant ${tenantCode} not found`);

  const org = await getScopedOrg(pool, tenant.TenantId);
  console.log(`Tenant: ${tenant.Code}`);
  console.log(`Field: ${org.field.Name}`);
  console.log(`Church: ${org.church.Name}`);
  console.log(`Small group: ${org.smallGroup.Name}`);

  const creds = {
    field: { email: "field_e2e@demo.local", pass: "Temp12345!", name: "Field E2E" },
    pastor: { email: "pastor_e2e@demo.local", pass: "Temp12345!", name: "Pastor E2E" },
    director: { email: "director_e2e@demo.local", pass: "Temp12345!", name: "Director E2E" },
    member: { email: "member_e2e@demo.local", pass: "Temp12345!", name: "Member E2E" }
  };

  const [fieldUser, pastorUser, directorUser, memberUser] = await Promise.all([
    upsertUser(pool, tenant.TenantId, { email: creds.field.email, password: creds.field.pass, displayName: creds.field.name }),
    upsertUser(pool, tenant.TenantId, { email: creds.pastor.email, password: creds.pastor.pass, displayName: creds.pastor.name }),
    upsertUser(pool, tenant.TenantId, { email: creds.director.email, password: creds.director.pass, displayName: creds.director.name }),
    upsertUser(pool, tenant.TenantId, { email: creds.member.email, password: creds.member.pass, displayName: creds.member.name })
  ]);

  await Promise.all([
    ensureMembership(pool, tenant.TenantId, pastorUser.UserId, org.church.OrgUnitId, "PASTOR"),
    ensureMembership(pool, tenant.TenantId, directorUser.UserId, org.church.OrgUnitId, "DIRECTOR"),
    ensureMembership(pool, tenant.TenantId, memberUser.UserId, org.church.OrgUnitId, "MEMBER")
  ]);

  const fieldRoleId = await getRoleId(pool, "FIELD_SABBATH_DIRECTOR");
  const pastorRoleId = await getRoleId(pool, "PASTOR");
  const directorRoleId = await getRoleId(pool, "CHURCH_SABBATH_DIRECTOR");
  const memberRoleId = await getRoleId(pool, "CHURCH_MEMBER");
  if (!fieldRoleId || !pastorRoleId || !directorRoleId || !memberRoleId) {
    throw new Error("Missing required roles in catalog");
  }

  await Promise.all([
    ensureRole(pool, tenant.TenantId, fieldUser.UserId, fieldRoleId, org.field.OrgUnitId),
    ensureRole(pool, tenant.TenantId, pastorUser.UserId, pastorRoleId, org.church.OrgUnitId),
    ensureRole(pool, tenant.TenantId, directorUser.UserId, directorRoleId, org.church.OrgUnitId),
    ensureRole(pool, tenant.TenantId, memberUser.UserId, memberRoleId, org.church.OrgUnitId)
  ]);

  const leaderCandidate = await upsertUser(pool, tenant.TenantId, {
    email: `member_candidate_${Date.now()}@demo.local`,
    password: "Temp12345!",
    displayName: "Member Candidate E2E"
  });
  await ensureMembership(pool, tenant.TenantId, leaderCandidate.UserId, org.church.OrgUnitId, "MEMBER");

  logSection("Login actors");
  const fieldToken = await login(creds.field.email, creds.field.pass);
  const pastorToken = await login(creds.pastor.email, creds.pastor.pass);
  const directorToken = await login(creds.director.email, creds.director.pass);
  const memberToken = await login(creds.member.email, creds.member.pass);

  let ok = 0;
  let fail = 0;
  const check = (name, expected, resp) => {
    const r = assertStatus(name, expected, resp);
    if (r) ok += 1;
    else fail += 1;
  };

  const uniqueA = `pastor_new_be2_${Date.now()}@demo.local`;
  const uniqueB = `director_new_be2_${Date.now()}@demo.local`;

  logSection("A field-admin/pastors");
  const a1 = await http("post", `${baseUrl}/api/v1/field-admin/pastors`, fieldToken, {
    churchOrgUnitId: org.church.OrgUnitId,
    email: uniqueA,
    password: "Temp12345!",
    firstName: "Pastor",
    lastName: "Nuevo",
    displayName: "Pastor Nuevo"
  });
  check("A1 field->pastor create", 201, a1);

  const a2 = await http("post", `${baseUrl}/api/v1/field-admin/pastors`, fieldToken, {
    churchOrgUnitId: org.church.OrgUnitId,
    email: uniqueA,
    password: "Temp12345!",
    firstName: "Pastor",
    lastName: "Nuevo",
    displayName: "Pastor Nuevo"
  });
  check("A2 field->pastor duplicate", 409, a2);

  const a3 = await http("post", `${baseUrl}/api/v1/field-admin/pastors`, pastorToken, {
    churchOrgUnitId: org.church.OrgUnitId,
    email: `forbidden_pastor_${Date.now()}@demo.local`,
    password: "Temp12345!",
    firstName: "No",
    lastName: "Permitido",
    displayName: "No Permitido"
  });
  check("A3 pastor forbidden in field-admin", 403, a3);

  logSection("B church-admin/sabbath-directors");
  const b1 = await http("post", `${baseUrl}/api/v1/church-admin/sabbath-directors`, pastorToken, {
    churchOrgUnitId: org.church.OrgUnitId,
    email: uniqueB,
    password: "Temp12345!",
    firstName: "Director",
    lastName: "Nuevo",
    displayName: "Director Nuevo"
  });
  check("B1 pastor->director create", 201, b1);

  const b2 = await http("post", `${baseUrl}/api/v1/church-admin/sabbath-directors`, pastorToken, {
    churchOrgUnitId: org.church.OrgUnitId,
    email: uniqueB,
    password: "Temp12345!",
    firstName: "Director",
    lastName: "Nuevo",
    displayName: "Director Nuevo"
  });
  check("B2 pastor->director duplicate", 409, b2);

  const b3 = await http("post", `${baseUrl}/api/v1/church-admin/sabbath-directors`, fieldToken, {
    churchOrgUnitId: org.church.OrgUnitId,
    email: `forbidden_director_${Date.now()}@demo.local`,
    password: "Temp12345!",
    firstName: "No",
    lastName: "Permitido",
    displayName: "No Permitido"
  });
  check("B3 field forbidden in church-admin director", 403, b3);

  logSection("C church-admin/small-group-leaders");
  const c1 = await http("post", `${baseUrl}/api/v1/church-admin/small-group-leaders`, directorToken, {
    userId: leaderCandidate.UserId,
    smallGroupOrgUnitId: org.smallGroup.OrgUnitId
  });
  check("C1 director->leader assign", 201, c1);

  const c2 = await http("post", `${baseUrl}/api/v1/church-admin/small-group-leaders`, directorToken, {
    userId: leaderCandidate.UserId,
    smallGroupOrgUnitId: org.smallGroup.OrgUnitId
  });
  check("C2 director->leader duplicate", 409, c2);

  const c3 = await http("post", `${baseUrl}/api/v1/church-admin/small-group-leaders`, memberToken, {
    userId: leaderCandidate.UserId,
    smallGroupOrgUnitId: org.smallGroup.OrgUnitId
  });
  check("C3 member forbidden in leader assign", 403, c3);

  logSection("Summary");
  console.log({ ok, fail });
  process.exit(fail > 0 ? 1 : 0);
}

main().catch((err) => {
  console.error("E2E step1 failed:", err.message);
  process.exit(1);
});


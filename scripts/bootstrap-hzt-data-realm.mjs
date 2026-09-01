import { chmod, mkdir, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";

const apply = process.argv.includes("--apply");
const baseUrl = String(process.env.KEYCLOAK_BASE_URL || "https://infra.hztcloud.cn").replace(/\/$/, "");
const realm = String(process.env.KEYCLOAK_REALM || "hzt").trim();
const adminUsername = String(process.env.KEYCLOAK_BOOTSTRAP_ADMIN_USERNAME || "admin").trim();
const adminPassword = String(process.env.KEYCLOAK_BOOTSTRAP_ADMIN_PASSWORD || "");
const tenantAlias = String(process.env.KEYCLOAK_TENANT_ALIAS || "hzt-demo").trim();
const tenantName = String(process.env.KEYCLOAK_TENANT_NAME || "婚字头数据平台").trim();
const webOrigin = String(process.env.KEYCLOAK_WEB_ORIGIN || "https://47.99.142.148").replace(/\/$/, "");
const webRedirectUri = String(process.env.KEYCLOAK_WEB_REDIRECT_URI || `${webOrigin}/data-platform/*`);
const organizationRedirectUrl = String(process.env.KEYCLOAK_ORGANIZATION_REDIRECT_URL || `${webOrigin}/data-platform/`);
const webClientId = String(process.env.KEYCLOAK_WEB_CLIENT_ID || "hzt-web");
const apiClientId = String(process.env.KEYCLOAK_API_CLIENT_ID || "hzt-api");
const serviceClientId = String(process.env.KEYCLOAK_ADMIN_SERVICE_CLIENT_ID || "hzt-admin-service");
const outputPath = resolve(String(process.env.KEYCLOAK_BOOTSTRAP_OUTPUT || ".local/hzt-data-migration-bootstrap.json"));
if (!adminPassword) throw new Error("KEYCLOAK_BOOTSTRAP_ADMIN_PASSWORD is required");
if (!/^[A-Za-z0-9._-]+$/.test(realm) || !/^[A-Za-z0-9._-]+$/.test(tenantAlias)) {
  throw new Error("realm and tenant alias contain unsupported characters");
}

const tokenResponse = await fetch(`${baseUrl}/realms/master/protocol/openid-connect/token`, {
  method: "POST",
  headers: { "content-type": "application/x-www-form-urlencoded" },
  body: new URLSearchParams({
    grant_type: "password",
    client_id: "admin-cli",
    username: adminUsername,
    password: adminPassword
  })
});
const tokenBody = await tokenResponse.json().catch(() => ({}));
if (!tokenResponse.ok || !tokenBody.access_token) throw new Error(`Keycloak admin token failed (${tokenResponse.status})`);
const adminToken = tokenBody.access_token;

async function kc(path, init = {}, expected = [200, 201, 204]) {
  const headers = new Headers(init.headers);
  headers.set("authorization", `Bearer ${adminToken}`);
  if (init.body !== undefined && !headers.has("content-type")) headers.set("content-type", "application/json");
  const response = await fetch(`${baseUrl}${path}`, { ...init, headers });
  const text = await response.text();
  const body = text ? (() => { try { return JSON.parse(text); } catch { return text; } })() : null;
  if (!expected.includes(response.status)) {
    throw new Error(`${init.method || "GET"} ${path} failed (${response.status}): ${JSON.stringify(body)}`);
  }
  return { response, body };
}

function resourceId(response) {
  const id = (response.headers.get("location") || "").split("/").filter(Boolean).at(-1);
  if (!id) throw new Error("Keycloak response has no Location resource ID");
  return id;
}

const audit = [];
const existingRealm = await kc(`/admin/realms/${encodeURIComponent(realm)}`, {}, [200, 404]);
if (existingRealm.response.status === 404) {
  audit.push({ action: "create_realm", realm });
  if (!apply) {
    console.log(JSON.stringify({ ok: true, mode: "dry-run", audit }, null, 2));
    process.exit(0);
  }
  await kc("/admin/realms", {
    method: "POST",
    body: JSON.stringify({
      realm,
      displayName: "HZT",
      enabled: true,
      organizationsEnabled: true,
      accessTokenLifespan: 300,
      eventsEnabled: true,
      registrationAllowed: false,
      resetPasswordAllowed: true,
      loginWithEmailAllowed: true,
      duplicateEmailsAllowed: false
    })
  }, [201]);
} else if (existingRealm.body.organizationsEnabled !== true || existingRealm.body.enabled !== true) {
  audit.push({ action: "enable_realm_organizations", realm });
  if (apply) {
    await kc(`/admin/realms/${encodeURIComponent(realm)}`, {
      method: "PUT",
      body: JSON.stringify({ ...existingRealm.body, enabled: true, organizationsEnabled: true })
    }, [204]);
  }
}

async function realmRequest(path, init = {}, expected) {
  return expected
    ? kc(`/admin/realms/${encodeURIComponent(realm)}${path}`, init, expected)
    : kc(`/admin/realms/${encodeURIComponent(realm)}${path}`, init);
}

async function ensureClient(clientId, representation) {
  const listed = (await realmRequest(`/clients?clientId=${encodeURIComponent(clientId)}&max=2`)).body;
  const existing = listed.find((item) => item.clientId === clientId);
  if (existing) {
    audit.push({ action: "update_client", clientId });
    if (apply) {
      await realmRequest(`/clients/${encodeURIComponent(existing.id)}`, {
        method: "PUT", body: JSON.stringify({ ...existing, ...representation, clientId })
      }, [204]);
    }
    return existing.id;
  }
  audit.push({ action: "create_client", clientId });
  if (!apply) return `planned:${clientId}`;
  const created = await realmRequest("/clients", {
    method: "POST", body: JSON.stringify({ ...representation, clientId })
  }, [201]);
  return resourceId(created.response);
}

const webClientUuid = await ensureClient(webClientId, {
  name: "HZT Data Platform Web",
  enabled: true,
  protocol: "openid-connect",
  publicClient: true,
  standardFlowEnabled: true,
  directAccessGrantsEnabled: false,
  serviceAccountsEnabled: false,
  redirectUris: [webRedirectUri],
  webOrigins: [webOrigin],
  attributes: { "pkce.code.challenge.method": "S256" }
});
const apiClientUuid = await ensureClient(apiClientId, {
  name: "HZT Data Platform API",
  enabled: true,
  protocol: "openid-connect",
  bearerOnly: true,
  publicClient: false,
  standardFlowEnabled: false,
  directAccessGrantsEnabled: false,
  serviceAccountsEnabled: false
});
const serviceClientUuid = await ensureClient(serviceClientId, {
  name: "HZT tenant IAM migration and administration",
  enabled: true,
  protocol: "openid-connect",
  publicClient: false,
  standardFlowEnabled: false,
  directAccessGrantsEnabled: false,
  serviceAccountsEnabled: true,
  clientAuthenticatorType: "client-secret"
});

if (!apply) {
  console.log(JSON.stringify({ ok: true, mode: "dry-run", audit }, null, 2));
  process.exit(0);
}

const organizationScopes = (await realmRequest("/client-scopes")).body;
const organizationScope = organizationScopes.find((scope) => scope.name === "organization");
if (!organizationScope) throw new Error("organization client scope was not created by the organization-enabled realm");
await realmRequest(`/clients/${encodeURIComponent(webClientUuid)}/optional-client-scopes/${encodeURIComponent(organizationScope.id)}`, { method: "PUT" }, [204]);

const scopeMappers = (await realmRequest(`/client-scopes/${encodeURIComponent(organizationScope.id)}/protocol-mappers/models`)).body;
const requiredMappers = [
  {
    name: "organization-membership-with-id",
    protocol: "openid-connect",
    protocolMapper: "oidc-organization-membership-mapper",
    consentRequired: false,
    config: {
      "access.token.claim": "true",
      "id.token.claim": "true",
      "introspection.token.claim": "true",
      "claim.name": "organization",
      "jsonType.label": "String",
      multivalued: "true",
      addOrganizationId: "true"
    }
  },
  {
    name: "organization-groups-and-roles",
    protocol: "openid-connect",
    protocolMapper: "oidc-organization-group-membership-mapper",
    consentRequired: false,
    config: {
      "access.token.claim": "true",
      "id.token.claim": "true",
      "introspection.token.claim": "true",
      addGroupRoleMappings: "true"
    }
  }
];
for (const mapper of requiredMappers) {
  const existing = scopeMappers.find((item) => item.protocolMapper === mapper.protocolMapper);
  if (existing) {
    await realmRequest(`/client-scopes/${encodeURIComponent(organizationScope.id)}/protocol-mappers/models/${encodeURIComponent(existing.id)}`, {
      method: "PUT", body: JSON.stringify({ ...existing, ...mapper })
    }, [204]);
  } else {
    await realmRequest(`/client-scopes/${encodeURIComponent(organizationScope.id)}/protocol-mappers/models`, {
      method: "POST", body: JSON.stringify(mapper)
    }, [201]);
  }
}

const webMappers = (await realmRequest(`/clients/${encodeURIComponent(webClientUuid)}/protocol-mappers/models`)).body;
const audienceMapper = {
  name: "hzt-api-audience",
  protocol: "openid-connect",
  protocolMapper: "oidc-audience-mapper",
  consentRequired: false,
  config: {
    "included.client.audience": apiClientId,
    "access.token.claim": "true",
    "id.token.claim": "false"
  }
};
const existingAudience = webMappers.find((item) => item.name === audienceMapper.name);
if (existingAudience) {
  await realmRequest(`/clients/${encodeURIComponent(webClientUuid)}/protocol-mappers/models/${encodeURIComponent(existingAudience.id)}`, {
    method: "PUT", body: JSON.stringify({ ...existingAudience, ...audienceMapper })
  }, [204]);
} else {
  await realmRequest(`/clients/${encodeURIComponent(webClientUuid)}/protocol-mappers/models`, {
    method: "POST", body: JSON.stringify(audienceMapper)
  }, [201]);
}

const organizations = (await realmRequest("/organizations?first=0&max=1000")).body;
let organization = organizations.find((item) => item.alias === tenantAlias);
if (!organization) {
  const created = await realmRequest("/organizations", {
    method: "POST",
    body: JSON.stringify({ name: tenantName, alias: tenantAlias, enabled: true, redirectUrl: organizationRedirectUrl })
  }, [201]);
  organization = { id: resourceId(created.response), name: tenantName, alias: tenantAlias, enabled: true };
  audit.push({ action: "create_organization", alias: tenantAlias });
} else {
  await realmRequest(`/organizations/${encodeURIComponent(organization.id)}`, {
    method: "PUT",
    body: JSON.stringify({ ...organization, name: tenantName, alias: tenantAlias, enabled: true, redirectUrl: organizationRedirectUrl })
  }, [204]);
  audit.push({ action: "update_organization", alias: tenantAlias });
}

const realmManagement = (await realmRequest("/clients?clientId=realm-management&max=2")).body[0];
if (!realmManagement) throw new Error("realm-management client not found");
const managementRoleNames = [
  "query-users", "view-users", "manage-users",
  "query-clients", "view-clients", "manage-clients",
  "query-organizations", "view-organizations", "manage-organizations"
];
const managementRoles = [];
for (const name of managementRoleNames) {
  managementRoles.push((await realmRequest(`/clients/${encodeURIComponent(realmManagement.id)}/roles/${encodeURIComponent(name)}`)).body);
}
const serviceAccount = (await realmRequest(`/clients/${encodeURIComponent(serviceClientUuid)}/service-account-user`)).body;
await realmRequest(`/users/${encodeURIComponent(serviceAccount.id)}/role-mappings/clients/${encodeURIComponent(realmManagement.id)}`, {
  method: "POST", body: JSON.stringify(managementRoles)
}, [204]);
const serviceSecret = (await realmRequest(`/clients/${encodeURIComponent(serviceClientUuid)}/client-secret`)).body.value;
if (!serviceSecret) throw new Error("service client secret is missing");

const result = {
  schemaVersion: 1,
  createdAt: new Date().toISOString(),
  issuerUrl: `${baseUrl}/realms/${realm}`,
  realm,
  tenantId: organization.id,
  tenantAlias,
  tenantName,
  webClientId,
  apiClientId,
  serviceClientId,
  serviceClientSecret,
  protectedAdmin: { realm: "master", username: adminUsername, modified: false },
  audit
};
await mkdir(dirname(outputPath), { recursive: true });
await writeFile(outputPath, `${JSON.stringify(result, null, 2)}\n`, { mode: 0o600 });
await chmod(outputPath, 0o600);
console.log(JSON.stringify({
  ok: true,
  mode: "apply",
  realm,
  tenantId: organization.id,
  tenantAlias,
  protectedAdminModified: false,
  output: outputPath,
  audit
}, null, 2));

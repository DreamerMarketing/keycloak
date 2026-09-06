import { appendFileSync, readFileSync } from "node:fs";
import { randomUUID } from "node:crypto";

const [inputPath, outputPath] = process.argv.slice(2);

if (!inputPath || !outputPath) {
  throw new Error("Usage: node scripts/vaultwarden-item-to-github-env.mjs <item.json> <github-env>");
}

const requiredNames = [
  "DEPLOY_HOST",
  "DEPLOY_USER",
  "DEPLOY_PATH",
  "SSH_KNOWN_HOSTS",
  "KEYCLOAK_HOSTNAME",
  "KEYCLOAK_DATABASE_MODE",
  "KEYCLOAK_DB_URL",
  "KEYCLOAK_DB_USERNAME",
  "KEYCLOAK_DB_PASSWORD",
  "POSTGRES_DB",
  "POSTGRES_USER",
  "POSTGRES_PASSWORD",
  "KEYCLOAK_BOOTSTRAP_ADMIN_USERNAME",
];
const allowedNames = new Set(requiredNames);
const item = JSON.parse(readFileSync(inputPath, "utf8"));
const fields = Array.isArray(item.fields) ? item.fields : [];
const values = new Map();

for (const field of fields) {
  const name = String(field?.name ?? "").trim();
  if (!allowedNames.has(name)) continue;
  if (values.has(name)) throw new Error(`Duplicate Vaultwarden field: ${name}`);
  values.set(name, { value: String(field?.value ?? ""), hidden: field?.type === 1 });
}

for (const name of requiredNames) {
  if (!values.get(name)?.value) throw new Error(`Missing Vaultwarden field: ${name}`);
}

function escapeWorkflowCommand(value) {
  return value.replaceAll("%", "%25").replaceAll("\r", "%0D").replaceAll("\n", "%0A");
}

for (const [name, field] of values) {
  if (field.hidden) console.log(`::add-mask::${escapeWorkflowCommand(field.value)}`);
  const delimiter = `HTZ_VAULT_${randomUUID().replaceAll("-", "")}`;
  appendFileSync(outputPath, `${name}<<${delimiter}\n${field.value}\n${delimiter}\n`, "utf8");
}

console.log(`Loaded ${values.size} validated deployment variables from Vaultwarden`);

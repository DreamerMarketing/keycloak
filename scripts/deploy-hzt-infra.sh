#!/usr/bin/env bash

set -Eeuo pipefail

required_variables=(
  DEPLOY_HOST
  DEPLOY_USER
  DEPLOY_PATH
  DEPLOY_SSH_KEY
  DEPLOY_KNOWN_HOSTS
  KEYCLOAK_HOSTNAME
  POSTGRES_DB
  POSTGRES_USER
  POSTGRES_PASSWORD
  KEYCLOAK_BOOTSTRAP_ADMIN_USERNAME
  KEYCLOAK_BOOTSTRAP_ADMIN_PASSWORD
)

for variable_name in "${required_variables[@]}"; do
  if [[ -z "${!variable_name:-}" ]]; then
    echo "Missing required variable: ${variable_name}" >&2
    exit 1
  fi
done

if [[ ! "$DEPLOY_PATH" =~ ^/opt/[A-Za-z0-9._/-]+$ ]]; then
  echo "DEPLOY_PATH must be an absolute path below /opt" >&2
  exit 1
fi

if [[ ! "$KEYCLOAK_HOSTNAME" =~ ^[A-Za-z0-9.-]+$ ]]; then
  echo "KEYCLOAK_HOSTNAME must be a DNS hostname or IPv4 address" >&2
  exit 1
fi

if [[ "$KEYCLOAK_HOSTNAME" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
  echo "KEYCLOAK_HOSTNAME must be the public DNS hostname" >&2
  exit 1
fi

if [[ ! "$DEPLOY_HOST" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
  echo "DEPLOY_HOST must be the public IPv4 address" >&2
  exit 1
fi

for identifier in POSTGRES_DB POSTGRES_USER KEYCLOAK_BOOTSTRAP_ADMIN_USERNAME; do
  if [[ ! "${!identifier}" =~ ^[A-Za-z0-9._-]+$ ]]; then
    echo "${identifier} contains unsupported characters" >&2
    exit 1
  fi
done

for secret_name in POSTGRES_PASSWORD KEYCLOAK_BOOTSTRAP_ADMIN_PASSWORD; do
  if [[ "${!secret_name}" == *$'\n'* || "${!secret_name}" == *$'\r'* ]]; then
    echo "${secret_name} must be a single-line value" >&2
    exit 1
  fi
done

ssh_options=(
  -i "$DEPLOY_SSH_KEY"
  -o BatchMode=yes
  -o IdentitiesOnly=yes
  -o StrictHostKeyChecking=yes
  -o "UserKnownHostsFile=$DEPLOY_KNOWN_HOSTS"
)

remote_host="${DEPLOY_USER}@${DEPLOY_HOST}"
deploy_revision="${DEPLOY_REVISION:-unknown}"
local_environment_file="$(mktemp)"
trap 'rm -f "$local_environment_file"' EXIT
chmod 600 "$local_environment_file"

printf 'POSTGRES_DB=%s\nPOSTGRES_USER=%s\nPOSTGRES_PASSWORD=%s\nKC_DB=postgres\nKC_DB_URL=jdbc:postgresql://hzt-infra-postgres:5432/%s\nKC_DB_USERNAME=%s\nKC_DB_PASSWORD=%s\nKC_BOOTSTRAP_ADMIN_USERNAME=%s\nKC_BOOTSTRAP_ADMIN_PASSWORD=%s\nKC_HOSTNAME=%s://%s\nKC_HTTP_ENABLED=true\nKC_PROXY_HEADERS=xforwarded\nKC_HEALTH_ENABLED=true\nKC_METRICS_ENABLED=true\n' \
  "$POSTGRES_DB" \
  "$POSTGRES_USER" \
  "$POSTGRES_PASSWORD" \
  "$POSTGRES_DB" \
  "$POSTGRES_USER" \
  "$POSTGRES_PASSWORD" \
  "$KEYCLOAK_BOOTSTRAP_ADMIN_USERNAME" \
  "$KEYCLOAK_BOOTSTRAP_ADMIN_PASSWORD" \
  "https" \
  "$KEYCLOAK_HOSTNAME" > "$local_environment_file"

ssh "${ssh_options[@]}" "$remote_host" "install -d -m 700 '$DEPLOY_PATH'"
scp "${ssh_options[@]}" "$local_environment_file" "${remote_host}:${DEPLOY_PATH}/.env.next"

ssh "${ssh_options[@]}" "$remote_host" bash -s -- \
  "$DEPLOY_PATH" "$KEYCLOAK_HOSTNAME" "$DEPLOY_HOST" "$deploy_revision" <<'REMOTE_SCRIPT'
set -Eeuo pipefail

deploy_path="$1"
keycloak_hostname="$2"
public_ip="$3"
deploy_revision="$4"
environment_file="${deploy_path}/.env"
network_name="hzt-infra"
bootstrap_secret_present=false

if [[ ! -s "${environment_file}.next" ]]; then
  echo "Missing uploaded environment file: ${environment_file}.next" >&2
  exit 1
fi

chmod 600 "${environment_file}.next"
mv -f "${environment_file}.next" "$environment_file"

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is not installed" >&2
  exit 1
fi

chmod 600 "$environment_file"
if grep -q '^KC_BOOTSTRAP_ADMIN_PASSWORD=' "$environment_file"; then
  bootstrap_secret_present=true
fi

docker network inspect "$network_name" >/dev/null 2>&1 || docker network create "$network_name"

docker pull postgres:16-alpine
docker pull quay.io/keycloak/keycloak:26.7.3

docker rm -f hzt-infra-caddy hzt-infra-keycloak hzt-infra-postgres >/dev/null 2>&1 || true

docker run -d \
  --name hzt-infra-postgres \
  --network "$network_name" \
  --restart unless-stopped \
  --memory 768m \
  --env-file "$environment_file" \
  --volume hzt-infra-postgres-data:/var/lib/postgresql/data \
  --label "hzt.deploy.revision=${deploy_revision}" \
  postgres:16-alpine >/dev/null

for attempt in $(seq 1 30); do
  if docker exec hzt-infra-postgres sh -c 'pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB"' >/dev/null 2>&1; then
    break
  fi
  if [[ "$attempt" -eq 30 ]]; then
    docker logs --tail 100 hzt-infra-postgres >&2
    exit 1
  fi
  sleep 2
done

start_keycloak() {
  docker rm -f hzt-infra-keycloak >/dev/null 2>&1 || true
  docker run -d \
    --name hzt-infra-keycloak \
    --network "$network_name" \
    --restart unless-stopped \
    --memory 2g \
    --publish 127.0.0.1:8080:8080 \
    --env-file "$environment_file" \
    --label "hzt.deploy.revision=${deploy_revision}" \
    quay.io/keycloak/keycloak:26.7.3 start >/dev/null
}

start_keycloak

if ! command -v nginx >/dev/null 2>&1; then
  echo "Nginx must be installed" >&2
  exit 1
fi
if ! command -v certbot >/dev/null 2>&1; then
  echo "Certbot must be installed for HTTPS deployment" >&2
  exit 1
fi

nginx_config="/etc/nginx/conf.d/hzt-infra.conf"
cat > "$nginx_config" <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${keycloak_hostname};

    location ^~ /.well-known/acme-challenge/ {
        root /var/www/letsencrypt;
        default_type text/plain;
        try_files \$uri =404;
    }

    location / {
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_pass http://127.0.0.1:8080;
    }
}
EOF

nginx -t
systemctl reload nginx

local_discovery_url="http://127.0.0.1:8080/realms/master/.well-known/openid-configuration"
discovery_url="https://${keycloak_hostname}/realms/master/.well-known/openid-configuration"
wait_for_keycloak() {
  for attempt in $(seq 1 60); do
    if curl --fail --silent --show-error --max-time 10 "$local_discovery_url" >/dev/null 2>&1; then
      return 0
    fi
    if [[ "$attempt" -eq 60 ]]; then
      docker logs --tail 150 hzt-infra-keycloak >&2
      return 1
    fi
    sleep 5
  done
}

wait_for_keycloak

# Bootstrap credentials are needed only for the first successful startup.
if [[ "$bootstrap_secret_present" == true ]]; then
  sed -i '/^KC_BOOTSTRAP_ADMIN_\(USERNAME\|PASSWORD\)=/d' "$environment_file"
  start_keycloak
  wait_for_keycloak
fi

obtain_certificate() {
  local identifier="$1"
  shift
  systemctl stop nginx
  if ! certbot certonly \
    --standalone \
    "$@" \
    --cert-name "$identifier" \
    --non-interactive \
    --agree-tos \
    --register-unsafely-without-email \
    --keep-until-expiring; then
    systemctl start nginx
    return 1
  fi
  systemctl start nginx
}

domain_certificate_available=false
if [[ -s "/etc/letsencrypt/live/${keycloak_hostname}/fullchain.pem" ]] || \
   obtain_certificate "$keycloak_hostname" --domain "$keycloak_hostname"; then
  domain_certificate_available=true
else
  echo "Warning: domain certificate is unavailable; keeping IP HTTPS active" >&2
  discovery_url="https://${public_ip}/realms/master/.well-known/openid-configuration"
fi
obtain_certificate "$public_ip" --ip-address "$public_ip" --preferred-profile shortlived

cat > "$nginx_config" <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${keycloak_hostname} ${public_ip};

    location / {
        return 301 https://\$host\$request_uri;
    }
}
EOF

if [[ "$domain_certificate_available" == true ]]; then
  cat >> "$nginx_config" <<EOF
server {
    listen 443 ssl;
    listen [::]:443 ssl;
    http2 on;
    server_name ${keycloak_hostname};

    ssl_certificate /etc/letsencrypt/live/${keycloak_hostname}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${keycloak_hostname}/privkey.pem;

    location / {
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_pass http://127.0.0.1:8080;
    }
}
EOF
fi

cat >> "$nginx_config" <<EOF
server {
    listen 443 ssl default_server;
    listen [::]:443 ssl default_server;
    http2 on;
    server_name ${public_ip};

    ssl_certificate /etc/letsencrypt/live/${public_ip}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${public_ip}/privkey.pem;

    location / {
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_pass http://127.0.0.1:8080;
    }
}
EOF

cat > /etc/systemd/system/hzt-certbot-renew.service <<'EOF'
[Unit]
Description=Renew hzt-infra TLS certificates

[Service]
Type=oneshot
ExecStart=/usr/local/bin/certbot renew --non-interactive --pre-hook "systemctl stop nginx" --post-hook "systemctl start nginx" --deploy-hook "systemctl reload nginx"
EOF

cat > /etc/systemd/system/hzt-certbot-renew.timer <<'EOF'
[Unit]
Description=Renew hzt-infra TLS certificates every six hours

[Timer]
OnBootSec=15min
OnUnitActiveSec=6h
RandomizedDelaySec=10min
Persistent=true

[Install]
WantedBy=timers.target
EOF

nginx -t
systemctl reload nginx
systemctl daemon-reload
systemctl enable --now hzt-certbot-renew.timer

curl --fail --silent --show-error "$discovery_url" >/dev/null
docker ps --filter 'name=hzt-infra-' --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'
REMOTE_SCRIPT

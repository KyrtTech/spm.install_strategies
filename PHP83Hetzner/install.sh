#!/bin/bash
set -euo pipefail

PROJECT=$(echo "${SPM_PROJECT:-spm}" | tr '[:upper:]' '[:lower:]')
ENVIRONMENT=$(echo "${SPM_ENV:-dev}" | tr '[:upper:]' '[:lower:]')
LOCATION="${PHP83_HETZNER_LOCATION:-fsn1}"
SERVER_TYPE="${HCLOUD_SERVER_TYPE:-cx23}"
IMAGE="${HCLOUD_IMAGE:-ubuntu-24.04}"
RUN_ID=$(date +%Y%m%d%H%M%S)
SERVER_NAME="${PROJECT}-${ENVIRONMENT}-php83-${RUN_ID}"
KEY_NAME="${PROJECT}-${ENVIRONMENT}-php83-key-${RUN_ID}"
KEY_FILE="${KEY_NAME}.pem"
USER_DATA_FILE="cloud-init-php83.yaml"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required command '$1' is not available" >&2
    exit 1
  fi
}

require_command hcloud
require_command jq
require_command ssh
require_command ssh-keygen

rm -f "${KEY_FILE}" "${KEY_FILE}.pub" "${USER_DATA_FILE}" server.json
ssh-keygen -t ed25519 -N "" -f "${KEY_FILE}" -C "${KEY_NAME}" >/dev/null
chmod 400 "${KEY_FILE}"

hcloud ssh-key create --name "${KEY_NAME}" --public-key-from-file "${KEY_FILE}.pub" >/dev/null

cat > "${USER_DATA_FILE}" <<'EOF'
#cloud-config
package_update: true
package_upgrade: false
packages:
  - php8.3
  - php8.3-cli
  - php8.3-common
  - php8.3-curl
  - php8.3-fpm
  - php8.3-mbstring
  - php8.3-mysql
  - php8.3-xml
  - php8.3-zip
  - unzip
  - curl
runcmd:
  - systemctl enable php8.3-fpm
  - systemctl start php8.3-fpm
EOF

hcloud server create \
  --name "${SERVER_NAME}" \
  --type "${SERVER_TYPE}" \
  --image "${IMAGE}" \
  --location "${LOCATION}" \
  --ssh-key "${KEY_NAME}" \
  --user-data-from-file "${USER_DATA_FILE}" \
  --output json > server.json

SERVER_ID=$(jq -r '.server.id // .id' server.json)

if [ -z "${SERVER_ID}" ] || [ "${SERVER_ID}" = "null" ]; then
  echo "Could not read Hetzner server id from hcloud output" >&2
  exit 1
fi

for _ in $(seq 1 60); do
  STATUS=$(hcloud server describe "${SERVER_ID}" --output json | jq -r '.status')
  if [ "${STATUS}" = "running" ]; then
    break
  fi
  sleep 5
done

PUBLIC_IP=$(hcloud server describe "${SERVER_ID}" --output json | jq -r '.public_net.ipv4.ip')

if [ -z "${PUBLIC_IP}" ] || [ "${PUBLIC_IP}" = "null" ]; then
  echo "Could not read public IPv4 address for Hetzner server ${SERVER_ID}" >&2
  exit 1
fi

for _ in $(seq 1 60); do
  if ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -i "${KEY_FILE}" "root@${PUBLIC_IP}" "true" >/dev/null 2>&1; then
    break
  fi
  sleep 5
done

ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "${KEY_FILE}" "root@${PUBLIC_IP}" "cloud-init status --wait && php -v"

if [ -z "${SPM_OUTPUT_PATH:-}" ]; then
  echo "No output for SPM"
else
  cat > "${SPM_OUTPUT_PATH}" <<EOF
{"output_params": {
  "hcloudServerId": "${SERVER_ID}",
  "ip": "${PUBLIC_IP}",
  "sshConnectionString": "root@${PUBLIC_IP}",
  "sshKey": "${KEY_FILE}"
}}
EOF
fi

#!/bin/bash
# copy update env config file
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i $SSH_KEY "update_env.sh" "$SSH_CONNECTION_STRING":~/update_env.sh
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i $SSH_KEY "knex.ts" "$SSH_CONNECTION_STRING":~/knex.ts
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i $SSH_KEY "migration.ts" "$SSH_CONNECTION_STRING":~/migration.ts

ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $SSH_CONNECTION_STRING \
    -i $SSH_KEY \
    "DOWNLOAD_URL='$DOWNLOAD_URL'" \
    "REDIS_PORT='$REDIS_PORT'" \
    "REDIS_USERNAME='$REDIS_USERNAME'" \
    "REDIS_HOST='$REDIS_HOST'" \
    "REDIS_PASSWORD='$REDIS_PASSWORD'" \
    "DATABASE_URL='$DATABASE_URL'" \
    "DATABASE_NAME='$DATABASE_NAME'" \
    "DATABASE_USERNAME='$DATABASE_USERNAME'" \
    "DATABASE_PASSWORD='$DATABASE_PASSWORD'" \
    "DATABASE_PORT='$DATABASE_PORT'" \
    "DEFAULT_DOMAIN='$KUTT_AWS_DOMAIN_OR_IP:$KUTT_AWS_PORT'" \
    'bash -s' <<'EOF'
curl -o kutt.zip -L $DOWNLOAD_URL
unzip kutt.zip -d app
cd app/$(ls app)
npm install
wget https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem
cp .example.env .env
cp ~/update_env.sh .
cp ~/knex.ts ./server/knex.ts
cp ~/migration.ts ./knexfile.ts
chmod +x ./update_env.sh
./update_env.sh
NODE_OPTIONS=--openssl-legacy-provider npm run build
nohup npm run start -- --port 8080 > /dev/null 2>&1 &
EOF

# write to provided env var if available for SPM integration
if [ -z "${SPM_OUTPUT_PATH}" ]; then
    echo "No output for SPM"
else
    output_params="{ \"output_params\": {
    }}"

    echo "Saving outputs to ${SPM_OUTPUT_PATH}"
    echo $output_params > "${SPM_OUTPUT_PATH}"
fi
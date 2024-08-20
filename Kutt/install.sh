#!/bin/bash
# copy update env config file
if [ -n "update_env.sh" ]; then
    scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i $SSH_KEY "update_env.sh" "$SSH_CONNECTION_STRING":~/update_env.sh
fi

ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o SendEnv="REDIS_PORT REDIS_USERNAME REDIS_HOST REDIS_PASSWORD DATABASE_URL DATABASE_NAME DATABASE_USERNAME DATABASE_PASSWORD DATABASE_PORT" $SSH_CONNECTION_STRING -i $SSH_KEY "DOWNLOAD_URL='$DOWNLOAD_URL'" 'bash -s' <<'EOF'
curl -o kutt.zip -L $DOWNLOAD_URL
unzip kutt.zip -d app
cd app/$(ls app)
npm install
cp .example.env .env
cp ~/update_env.sh .
chmod +x ./update_env.sh
./update_env.sh
npm run build
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
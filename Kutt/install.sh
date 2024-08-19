#!/bin/bash
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o SendEnv="SPM_*" $SSH_CONNECTION_STRING -i $SSH_KEY "DOWNLOAD_URL='$DOWNLOAD_URL'" 'bash -s' <<'EOF'
curl -o kutt.zip -L $DOWNLOAD_URL
unzip kutt.zip -d app
cd app/$(ls app)
[ -f ~/config.json ] && cp ~/config.json ./src/links.json
npm install
cp .example.env .env
npm run build
nohup npm run start -- --port 8080 > /dev/null 2>&1 &
EOF

# write to provided env var if available for SPM integration
if [ -z "${SPM_OUTPUT_PATH}" ]; then
    echo "No output for SPM"
else
    output_params="{ \"output_params\": {
        \"url\": \"http://${IP}:8080\"
    }}"

    echo "Saving outputs to ${SPM_OUTPUT_PATH}"
    echo $output_params > "${SPM_OUTPUT_PATH}"
fi
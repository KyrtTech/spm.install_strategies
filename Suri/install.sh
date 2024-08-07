#!/bin/bash
# copy config file if provided
if [ -n "${SURI_INSTALL_LINKS_CONFIG}" ]; then
    scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i $SSH_KEY $SURI_INSTALL_LINKS_CONFIG "$SSH_CONNECTION_STRING":~/config.json
fi

ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $SSH_CONNECTION_STRING -i $SSH_KEY "DOWNLOAD_URL='$DOWNLOAD_URL'" 'bash -s' <<'EOF'
curl -o suri.zip -L $DOWNLOAD_URL
unzip suri.zip -d app
cd app/$(ls app)
[ -f ~/config.json ] && cp ~/config.json ./src/links.json
npm install
nohup npm run dev -- --port 8080 > /dev/null 2>&1 &
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
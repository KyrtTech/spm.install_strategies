#!/bin/bash
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $SSH_CONNECTION_STRING -i $SSH_KEY "DOWNLOAD_URL='$DOWNLOAD_URL'" 'bash -s' <<'EOF'
curl -o suri.zip -L $DOWNLOAD_URL
unzip suri.zip -d app
cd app/$(ls app)
npm install
nohup npm run dev -- --port 8080 &
EOF

# write to provided env var if available for SMP integration
if [ -z "${SMP_OUTPUT_PATH}" ]; then
    echo "No output for SMP"
else
    output_params="{}"

    echo $output_params > "${SMP_OUTPUT_PATH}"
fi
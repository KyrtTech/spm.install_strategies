#!/bin/bash

# Function to extract numeric value from disk size (e.g., "50GB" -> "50")
function extract_disk_size() {
  echo "$1" | sed -E 's/[^0-9]//g'
}

# Map the number of vCPUs to EC2 instance types
function get_instance_type() {
  case "$1" in
    1) echo "t3.micro";;        # 1 vCPUs
    2) echo "t3.small";;         # 2 vCPUs
    4) echo "t3.medium";;        # 4 vCPUs
    8) echo "m5.large";;         # 8 vCPUs
    16) echo "m5.xlarge";;       # 16 vCPUs
    32) echo "m5.2xlarge";;      # 32 vCPUs
    64) echo "m5.4xlarge";;      # 64 vCPUs
    96) echo "c5.12xlarge";;     # 96 vCPUs
    *) echo "t3.micro";;         # Default to t3.micro
  esac
}

# Variables
INSTANCE_TYPE=$(get_instance_type "${SPM_V_CPU:-1}")
DISK_SIZE=$(extract_disk_size "${SPM_STORAGE:-8}")
AMI_ID="ami-0f403e3180720dd7e"
KEY_NAME="$SPM_PROJECT-$SPM_ENV-KeyPairForNodeJS"
SECURITY_GROUP="$SPM_PROJECT-$SPM_ENV-SGForNodeJS"

# User data script to install Node.js v18.x
USER_DATA=$(cat <<'EOF'
#!/bin/bash
curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo bash -
sudo yum install -y nodejs
EOF
)

rm $KEY_NAME.pem
# Create a key pair
aws ec2 create-key-pair \
    --key-name $KEY_NAME \
    --query 'KeyMaterial' \
    --output text \
    --no-cli-pager >> $KEY_NAME.pem
# Get the key pair id
KEY_PAIR_ID=$(aws ec2 describe-key-pairs --query "KeyPairs[?KeyName=='$KEY_NAME'].KeyPairId" --output text)
# Tag the key pair
aws ec2 create-tags \
    --resource $KEY_PAIR_ID \
    --tags "Key=project,Value=$SPM_PROJECT" "Key=env,Value=$SPM_ENV" "Key=managed-by,Value=SPM"
chmod 400 $KEY_NAME.pem

# Create a SG
GROUP_ID=$(aws ec2 create-security-group \
    --group-name $SECURITY_GROUP \
    --description "Test security group for NodeJS18" \
    --query 'GroupId' \
    --output text \
    --tag-specifications "ResourceType=security-group,Tags=[{Key=project,Value=${SPM_PROJECT}},{Key=env,Value=${SPM_ENV}},{Key=managed-by,Value=SPM}]" \
    --no-cli-pager)
aws ec2 authorize-security-group-ingress --group-id $GROUP_ID --protocol tcp --port 8080 --cidr 0.0.0.0/0 --no-cli-pager
aws ec2 authorize-security-group-ingress --group-id $GROUP_ID --protocol tcp --port 22 --cidr 0.0.0.0/0 --no-cli-pager


# Launch EC2 instance with the user data script
INSTANCE_ID=$(aws ec2 run-instances \
    --image-id $AMI_ID \
    --instance-type $INSTANCE_TYPE \
    --key-name $KEY_NAME \
    --security-groups $SECURITY_GROUP \
    --user-data "$USER_DATA" \
    --block-device-mappings "[{\"DeviceName\":\"/dev/xvda\",\"Ebs\":{\"VolumeSize\":$DISK_SIZE}}]" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$SPM_PROJECT-$SPM_ENV-Node18Instance},{Key=project,Value=$SPM_PROJECT},{Key=env,Value=$SPM_ENV},{Key=managed-by,Value=SPM}]" \
    --query 'Instances[0].InstanceId' \
    --output text \
    --no-cli-pager)

echo "EC2 instance created with id $INSTANCE_ID"

aws ec2 wait instance-running --instance-ids $INSTANCE_ID

echo "Instance started"

aws ec2 wait instance-status-ok --instance-ids $INSTANCE_ID

echo "Instance init finished"

PUBLIC_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[*].Instances[*].PublicIpAddress' --output text)

echo "You can connect to your instance by using this command:"
echo "ssh -i $KEY_NAME.pem ec2-user@$PUBLIC_IP"

# write to provided env var if available for SPM integration
if [ -z "${SPM_OUTPUT_PATH}" ]; then
    echo "No output for SPM"
else
    output_params="{\"output_params\": {
        \"ec2InstanceId\": \"${INSTANCE_ID}\",
        \"ip\": \"${PUBLIC_IP}\",
        \"sshConnectionString\": \"ec2-user@${PUBLIC_IP}\",
        \"sshKey\": \"${KEY_NAME}.pem\"
    }}"

    echo $output_params > "${SPM_OUTPUT_PATH}"
fi
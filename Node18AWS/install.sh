#!/bin/bash

# Variables
INSTANCE_TYPE="t2.micro"
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

# write to provided env var if available for SMP integration
if [ -z "${SMP_OUTPUT_PATH}" ]; then
    echo "No output for SMP"
else
    output_params="{\"output_params\": {
        \"ec2InstanceId\": \"${INSTANCE_ID}\",
        \"ip\": \"${PUBLIC_IP}\",
        \"sshConnectionString\": \"ec2-user@${PUBLIC_IP}\",
        \"sshKey\": \"${KEY_NAME}.pem\"
    }}"

    echo $output_params > "${SMP_OUTPUT_PATH}"
fi
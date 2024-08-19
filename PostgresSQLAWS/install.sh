#!/bin/bash

export TF_VAR_PRODUCT=`echo "${SPM_PROJECT:-default-project}" | tr '[:upper:]' '[:lower:]'`
export TF_VAR_ENV=`echo "${SPM_ENV:-dev}" | tr '[:upper:]' '[:lower:]'`
export TF_VAR_OUTPUT_FILE=$SPM_OUTPUT_PATH
export REGION=${AWS_REGION:-us-west-2}
export TF_VAR_REGION=$REGION
export S3_BUCKET="spm-$TF_VAR_PRODUCT-$TF_VAR_ENV-tf-state"
export DYNAMO_DB_TABLE="spm-$TF_VAR_PRODUCT-$TF_VAR_ENV-tf-lock"

retry_command() {
  local command="$1"
  local max_retries=5
  local delay=5
  local retry_count=0

  until $command
  do
    retry_count=$((retry_count+1))
    if [ $retry_count -ge $max_retries ]; then
      echo "Command failed after $max_retries attempts."
      return 1
    fi
    echo "Command failed. Attempt $retry_count/$max_retries. Retrying in $delay seconds..."
    sleep $delay
  done
  echo "Command succeeded."
}

if [ "$REGION" = "us-east-1" ]; then
    aws s3api create-bucket --bucket $S3_BUCKET --region $REGION
else
    aws s3api create-bucket --bucket $S3_BUCKET --region $REGION --create-bucket-configuration LocationConstraint=$REGION
fi

aws s3api put-bucket-tagging \
    --bucket $S3_BUCKET \
    --tagging "TagSet=[{Key=managed-by,Value=SPM},{Key=env,Value=$TF_VAR_ENV},{Key=product,Value=$TF_VAR_PRODUCT}]"

aws dynamodb create-table \
    --table-name $DYNAMO_DB_TABLE \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region $REGION \
    --no-cli-pager \
    --no-paginate \
    --output json \
    --tags Key=managed-by,Value=SPM Key=product,Value=$TF_VAR_PRODUCT Key=env,Value=$TF_VAR_ENV

# Poll the table status until it becomes ACTIVE
while true; do
  STATUS=$(aws dynamodb describe-table --table-name "$DYNAMO_DB_TABLE" --region "$REGION" --query "Table.TableStatus" --output text)

  if [ "$STATUS" = "ACTIVE" ]; then
    echo "DynamoDB table $DYNAMO_DB_TABLE is now ACTIVE."
    break
  else
    echo "Waiting for DynamoDB table $DYNAMO_DB_TABLE to become ACTIVE. Current status: $STATUS"
    sleep 5  # Wait for 5 seconds before checking again
  fi
done

export TF_PLUGIN_TIMEOUT=5m

echo "RUN terraform init"

echo "With $REGION, $S3_BUCKET, $DYNAMO_DB_TABLE"

terraform init \
    -upgrade \
    -backend-config="region=$REGION" \
    -backend-config="bucket=$S3_BUCKET" \
    -backend-config="dynamodb_table=$DYNAMO_DB_TABLE"

echo "RUN terraform apply"

retry_command "terraform apply -auto-approve"
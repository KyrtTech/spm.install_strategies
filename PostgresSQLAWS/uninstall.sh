#!/bin/bash

export TF_VAR_PRODUCT=`echo "${SPM_PROJECT:-default-project}" | tr '[:upper:]' '[:lower:]'`
export TF_VAR_ENV=`echo "${SPM_ENV:-dev}" | tr '[:upper:]' '[:lower:]'`
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

export TF_PLUGIN_TIMEOUT=2m

terraform init -upgrade \
    -backend-config="region=$REGION" \
    -backend-config="bucket=$S3_BUCKET" \
    -backend-config="dynamodb_table=$DYNAMO_DB_TABLE"

retry_command "terraform destroy -auto-approve"

aws s3 rm s3://$S3_BUCKET --recursive
aws s3api delete-bucket --bucket $S3_BUCKET --region $REGION
aws dynamodb delete-table --table-name $DYNAMO_DB_TABLE \
    --region $REGION \
    --no-cli-pager \
    --no-paginate

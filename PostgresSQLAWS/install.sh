#!/bin/bash

export TF_VAR_PRODUCT=`echo "${SPM_PROJECT:-default-project}" | tr '[:upper:]' '[:lower:]'`
export TF_VAR_ENV=`echo "${SMP_ENV:-dev}" | tr '[:upper:]' '[:lower:]'`
export TF_VAR_OUTPUT_FILE=$SPM_OUTPUT_PATH
export REGION=us-west-2
export S3_BUCKET="$TF_VAR_PRODUCT-$TF_VAR_ENV-tf-state"
export DYNAMO_DB_TABLE="$TF_VAR_PRODUCT-$TF_VAR_ENV-tf-lock"

aws s3api create-bucket --bucket $S3_BUCKET --region $REGION --create-bucket-configuration LocationConstraint=$REGION
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

terraform init \
    -backend-config="region=$REGION" \
    -backend-config="bucket=$S3_BUCKET" \
    -backend-config="dynamodb_table=$DYNAMO_DB_TABLE"

terraform apply -auto-approve
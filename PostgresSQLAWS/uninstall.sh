#!/bin/bash

export TF_VAR_PRODUCT=`echo "${SPM_PROJECT:-default-project}" | tr '[:upper:]' '[:lower:]'`
export TF_VAR_ENV=`echo "${SPM_ENV:-dev}" | tr '[:upper:]' '[:lower:]'`
export REGION=${AWS_REGION:-us-west-2}
export TF_VAR_REGION=$REGION
export S3_BUCKET="spm-$TF_VAR_PRODUCT-$TF_VAR_ENV-tf-state"
export DYNAMO_DB_TABLE="spm-$TF_VAR_PRODUCT-$TF_VAR_ENV-tf-lock"

terraform init -upgrade \
    -backend-config="region=$REGION" \
    -backend-config="bucket=$S3_BUCKET" \
    -backend-config="dynamodb_table=$DYNAMO_DB_TABLE"

terraform destroy -auto-approve

aws s3 rm s3://$S3_BUCKET --recursive
aws s3api delete-bucket --bucket $S3_BUCKET --region $REGION
aws dynamodb delete-table --table-name $DYNAMO_DB_TABLE \
    --region $REGION \
    --no-cli-pager \
    --no-paginate

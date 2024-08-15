#!/bin/bash

export TF_VAR_PRODUCT=`echo "${SPM_PROJECT:-default-project}" | tr '[:upper:]' '[:lower:]'`
export TF_VAR_ENV=`echo "${SMP_ENV:-dev}" | tr '[:upper:]' '[:lower:]'`
export REGION=us-west-2
export S3_BUCKET="$TF_VAR_PRODUCT-$TF_VAR_ENV-tf-state"
export DYNAMO_DB_TABLE="$TF_VAR_PRODUCT-$TF_VAR_ENV-tf-lock"

terraform destroy -auto-approve

aws s3 rm s3://$S3_BUCKET --recursive
aws s3api delete-bucket --bucket $S3_BUCKET --region $REGION
aws dynamodb delete-table --table-name $DYNAMO_DB_TABLE \
    --region $REGION \
    --no-cli-pager \
    --no-paginate

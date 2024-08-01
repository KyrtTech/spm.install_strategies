#!/bin/bash

npx cdk bootstrap
npx cdk deploy --require-approval never --outputs-file output.json

if [ -z "${SMP_OUTPUT_PATH}" ]; then
    echo "No output for SMP"
else
    jq  '{
        output_params: {
            redisPort: (.RedisAwsStack.RedisPort | tonumber),
            redisUsername: .RedisAwsStack.RedisUsernameOutput,
            redisHost: .RedisAwsStack.RedisHost,
            redisPassword: .RedisAwsStack.RedisPasswordOutput
        }
    }' output.json > $SMP_OUTPUT_PATH
fi
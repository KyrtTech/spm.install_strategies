#!/bin/bash

npx cdk bootstrap
npx cdk deploy --require-approval never --outputs-file output.json

if [ -z "${SPM_OUTPUT_PATH}" ]; then
    echo "No output for SPM"
else
    jq  '{
        output_params: {
            redisPort: (.RedisAwsStack.RedisPort | tonumber),
            redisUsername: .RedisAwsStack.RedisUsernameOutput,
            redisHost: .RedisAwsStack.RedisHost,
            redisPassword: .RedisAwsStack.RedisPasswordOutput
        }
    }' output.json > $SPM_OUTPUT_PATH
fi
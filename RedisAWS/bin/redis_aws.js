#!/usr/bin/env node

const cdk = require('aws-cdk-lib');
const { RedisAwsStack } = require('../lib/redis_aws-stack');

const app = new cdk.App();
new RedisAwsStack(app, 'RedisAwsStack', {
  env: { account: process.env.CDK_DEFAULT_ACCOUNT, region: process.env.CDK_DEFAULT_REGION },
});

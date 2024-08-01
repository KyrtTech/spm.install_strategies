const { Stack, Tags, CfnOutput, Fn } = require("aws-cdk-lib");
const ec2 = require("aws-cdk-lib/aws-ec2");
const ssm = require("aws-cdk-lib/aws-ssm");
const { Construct } = require("constructs");
const crypto = require("crypto");

class RedisAwsStack extends Stack {
  /**
   *
   * @param {Construct} scope
   * @param {string} id
   * @param {StackProps=} props
   */
  constructor(scope, id, props) {
    super(scope, id, props);

    // Retrieve environment variables for tags
    const productTag = process.env.SPM_PROJECT || "default-project";
    const envTag = process.env.SPM_ENV || "dev";

    // Generate Redis user credentials
    const redisUsername = "redisUser";
    const redisPassword = crypto.randomBytes(16).toString("hex");

    // Get the default VPC
    const vpc = ec2.Vpc.fromLookup(this, "DefaultVpc", {
      isDefault: true,
    });

    // Define a Security Group
    const securityGroup = new ec2.SecurityGroup(this, "RedisSecurityGroup", {
      vpc,
      description: "Allow redis",
      allowAllOutbound: true,
    });

    // Allow Redis access from anywhere
    securityGroup.addIngressRule(
      ec2.Peer.anyIpv4(),
      ec2.Port.tcp(6379),
      "allow redis access from the world"
    );

    const userData = ec2.UserData.forLinux();
    userData.addCommands(
      "yum-config-manager --enable epel",
      "yum update -y",
      "amazon-linux-extras install redis6 -y",
      'sed -i "s/^bind 127.0.0.1 -::1/bind 0.0.0.0/" /etc/redis/redis.conf',
      'sed -i "s/^protected-mode yes/protected-mode no/" /etc/redis/redis.conf',
      "systemctl enable redis",
      "systemctl start redis",
      `redis-cli ACL SETUSER ${redisUsername} on \\>${redisPassword} ~* +@all`
    );

    // Define an EC2 instance
    const instance = new ec2.Instance(this, "RedisInstance", {
      instanceType: new ec2.InstanceType("t2.micro"),
      machineImage: ec2.MachineImage.latestAmazonLinux2(),
      userData,
      vpc,
      securityGroup,
      blockDevices: [
        {
          deviceName: "/dev/xvda",
          volume: ec2.BlockDeviceVolume.ebs(50), // Specify the size in GiB
        },
      ],
    });

    // Store Redis credentials in SSM Parameter Store
    new ssm.StringParameter(this, "RedisUsername", {
      parameterName: `/${productTag}-${envTag}/redis/username`,
      stringValue: redisUsername,
    });

    new ssm.StringParameter(this, "RedisPassword", {
      parameterName: `/${productTag}-${envTag}/redis/password`,
      stringValue: redisPassword,
    });

    // Apply tags to all resources in this stack
    Tags.of(this).add("product", productTag);
    Tags.of(this).add("env", envTag);
    Tags.of(this).add("managed-by", "SPM");

    // Output the Redis instance dns
    const instanceDNS = new CfnOutput(this, "RedisHost", {
      value: instance.instancePrivateDnsName,
      description: "The Redis host",
    });

    // Redis port
    new CfnOutput(this, "RedisPort", {
      value: 6379,
      description: "The Redis port",
    });

    // Output the Redis credentials
    new CfnOutput(this, "RedisUsernameOutput", {
      value: redisUsername,
      description: "The Redis username",
    });

    new CfnOutput(this, "RedisPasswordOutput", {
      value: redisPassword,
      description: "The Redis password",
    });

    // Output the Redis connection URL
    new CfnOutput(this, "RedisConnectionUrl", {
      value: `redis://${redisUsername}:${redisPassword}@${instance.instancePublicDnsName}:6379`,
      description: "The Redis connection URL",
    });
  }
}

module.exports = { RedisAwsStack };

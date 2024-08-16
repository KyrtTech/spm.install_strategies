terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }

    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }

  backend "s3" {
    key     = "terraform.tfstate"
    encrypt = true
  }
}

provider "local" {}

resource "local_file" "db_info" {
  filename = "${var.output_file}"
  content  = <<EOL
    {
        "output_params": {
            "postgresUrl": "${aws_db_instance.postgres.endpoint}",
            "postgresDBName": "${aws_db_instance.postgres.db_name}",
            "postgresUsername": "${aws_db_instance.postgres.username}",
            "postgresPassword": "${aws_db_instance.postgres.password}"
        }
    }
EOL
}

provider "aws" {
  region = var.region # Replace with your desired AWS region
}

resource "random_password" "db_password" {
  length           = 16
  special          = true
  upper            = true
  lower            = true
  numeric          = true
  override_special = "!#$%&()*+,-.:;<=>?[]^_{|}~"
}

resource "random_string" "db_username" {
  length  = 12
  lower   = true
  special = false
  numeric = false
}

# Get the default VPC
data "aws_vpc" "default" {
  default = true
}

# Get the default VPC's subnets
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Create a Security Group for RDS within the default VPC
resource "aws_security_group" "rds_sg" {
  vpc_id = data.aws_vpc.default.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Change this to limit access by IP range
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name       = "${var.product}-${var.env}-rds-security-group"
    managed-by = "SPM"
    env        = var.env
    product    = var.product
  }
}

# Create a DB Subnet Group using default subnets
resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "${var.product}-${var.env}-rds-default-subnet-group"
  subnet_ids = data.aws_subnets.default.ids

  tags = {
    Name       = "${var.product}-${var.env}-rds-default-subnet-group"
    managed-by = "SPM"
    env        = var.env
    product    = var.product
  }
}

# Create the PostgreSQL RDS instance
resource "aws_db_instance" "postgres" {
  allocated_storage      = 20
  storage_type           = "gp2"
  engine                 = "postgres"
  engine_version         = "16.3" # Replace with your desired version
  instance_class         = "db.t3.micro"
  db_name                = replace(lower(var.product), "/[^0-9a-z]/", "")
  password               = random_password.db_password.result
  username               = random_string.db_username.result
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  skip_final_snapshot    = true
  publicly_accessible    = true # Set to false if you don't need public access

  tags = {
    Name       = "${var.product}-${var.env}-rds"
    managed-by = "SPM"
    env        = var.env
    product    = var.product
  }
}

output "db_instance_endpoint" {
  value = aws_db_instance.postgres.endpoint
}

output "db_instance_name" {
  value = aws_db_instance.postgres.db_name
}

output "db_instance_username" {
  value = aws_db_instance.postgres.username
}

output "db_instance_password" {
  value = aws_db_instance.postgres.password
  sensitive = true
}

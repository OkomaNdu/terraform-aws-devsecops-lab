provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_key_id
  secret_key = var.aws_secret_access_key

  default_tags {
    tags = {
      environment = var.env_prefix
      terraform   = "true"
    }
  }
}

######## CREATE ROLES ########

# define and get info on needed policies for both roles
data "aws_iam_policy" "AmazonSSMManagedInstanceCore" {
  arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy" "AmazonEC2ContainerRegistryFullAccess" {
  arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"
}

data "aws_iam_policy" "AmazonSSMFullAccess" {
  arn = "arn:aws:iam::aws:policy/AmazonSSMFullAccess"
}

# create role for ec2 service for app-server
resource "aws_iam_role" "app-server-role" {
  name = "app-server-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

# attach the needed policies to the created ec2 role
resource "aws_iam_role_policy_attachment" "policy-attach-ssm" {
  role       = aws_iam_role.app-server-role.name
  policy_arn = data.aws_iam_policy.AmazonSSMManagedInstanceCore.arn
}

resource "aws_iam_role_policy_attachment" "policy-attach-ecr-full" {
  role       = aws_iam_role.app-server-role.name
  policy_arn = data.aws_iam_policy.AmazonEC2ContainerRegistryFullAccess.arn
}

# define instance profile, so we can assign the role to our ec2 instance
resource "aws_iam_instance_profile" "app-server-role" {
  name = "app-server-role"
  role = aws_iam_role.app-server-role.name
}

# create role for ec2 service for gitlab-runner-server
resource "aws_iam_role" "github-runner-role" {
  name = "github-runner-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "policy-attach-ssm-github" {
  role       = aws_iam_role.github-runner-role.name
  policy_arn = data.aws_iam_policy.AmazonSSMFullAccess.arn
}

# The SSM *agent* needs ssmmessages/ec2messages permissions to register the
# instance and open a Session Manager channel. AmazonSSMFullAccess does not
# grant these -- AmazonSSMManagedInstanceCore does.
resource "aws_iam_role_policy_attachment" "policy-attach-ssm-core-github" {
  role       = aws_iam_role.github-runner-role.name
  policy_arn = data.aws_iam_policy.AmazonSSMManagedInstanceCore.arn
}

resource "aws_iam_role_policy_attachment" "policy-attach-ecr-full-github" {
  role       = aws_iam_role.github-runner-role.name
  policy_arn = data.aws_iam_policy.AmazonEC2ContainerRegistryFullAccess.arn
}

resource "aws_iam_instance_profile" "github-runner-role" {
  name = "github-runner-role"
  role = aws_iam_role.github-runner-role.name
}


######## CREATE NETWORKING RESOURCES ########

# fetch available zones for the configured region 
data "aws_availability_zones" "available" {}

# create "main" vpc to launch our instances in
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.6.0"

  name               = "main"

  cidr               = "10.0.0.0/16"
  private_subnets    = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  
  azs                = data.aws_availability_zones.available.names 
  
  enable_nat_gateway = true
  enable_vpn_gateway = true

  tags = {
    terraform   = "true"
    environment = var.env_prefix
  }
}

resource "aws_security_group" "main" {
  name   = "main"
  vpc_id = data.aws_vpc.main.id

  ingress {
    description = "Allow inbound from all 10.0.0.0/16"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "main"
  }
}

resource "aws_security_group" "app-server" {
  name   = "app-server"
  vpc_id = data.aws_vpc.main.id

  ingress {
    description = "Allow inbound from all 10.0.0.0/16"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    description = "Allow inbound from 0.0.0.0/0"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "app-server"
  }
}

######## CREATE EC2 SERVERS ########

module "ec2_app_server" {
  depends_on = [aws_security_group.app-server]
  # TF module that creates EC2 instances: https://registry.terraform.io/modules/terraform-aws-modules/ec2-instance/aws/6.4.0            
  source     = "terraform-aws-modules/ec2-instance/aws"
  version    = "6.4.0"

  name = "app-server"

  instance_type               = "t3.small"
  availability_zone           = element(data.aws_availability_zones.available.names, 0) # get first az from available zones
  ami                         = data.aws_ami.ubuntu.id
  iam_instance_profile        = data.aws_iam_instance_profile.app-server-role.name
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.app-server.id]
  subnet_id                   = module.vpc.public_subnets[0]
  user_data                   = local.script

  tags = {
    Terraform   = "true"
    Environment = var.env_prefix
    Name        = "app-server"
  }

  root_block_device = {
    volume_type           = "gp3"
    volume_size           = 16
    encrypted             = true
    delete_on_termination = true
  }
}

module "ec2_github_runner" {
  depends_on = [aws_security_group.main]
  source     = "terraform-aws-modules/ec2-instance/aws" 
  version    = "6.4.0"

  name = "github-runner"

  instance_type               = "t2.large"
  availability_zone           = element(data.aws_availability_zones.available.names, 0)
  ami                         = data.aws_ami.ubuntu.id
  iam_instance_profile        = data.aws_iam_instance_profile.github-runner-role.name
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.main.id]
  subnet_id                   = module.vpc.public_subnets[0]
  user_data                   = local.script-github
  user_data_replace_on_change = true

  tags = {
    Terraform   = "true"
    Environment = var.env_prefix
    Name        = "github-runner"
  }

  root_block_device = {
    type                  = "gp3"
    size                  = 60
    encrypted             = true
    delete_on_termination = true
  }
}

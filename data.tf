data "aws_vpc" "main" {
  depends_on = [module.vpc]
  filter {
    name   = "tag:Name"
    values = ["main"]
  }
}

data "aws_iam_instance_profile" "app-server-role" {
  depends_on = [aws_iam_instance_profile.app-server-role]
  name       = "app-server-role"
}

data "aws_iam_instance_profile" "github-runner-role" {
  depends_on = [aws_iam_instance_profile.github-runner-role]
  name       = "github-runner-role"
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

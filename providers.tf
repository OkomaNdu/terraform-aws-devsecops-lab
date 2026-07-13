terraform {
  backend "s3" {
    bucket = "infra-s3-bucket-89"
    key = "infra/state.tfstate"
    region = "ca-central-1"
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.54.0"
    }
  }
}

terraform {
  backend "s3" {
    bucket = "infra-s3-bucket-89"
    key    = "infra/state.tfstate"
    region = "ca-central-1"

    # State holds the GitHub PAT and AWS keys in plaintext, so encrypt at rest.
    encrypt = true

    # S3-native state locking: prevents concurrent runs corrupting state.
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.54.0"
    }
  }
}

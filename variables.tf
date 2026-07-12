variable "aws_access_key_id" {
  default = ""
}
variable "aws_secret_access_key" {
  default = ""
}
variable "aws_region" {
  default = "ca-central-1"
}
variable "env_prefix" {
  default = "dev"
}
# Long-lived GitHub Personal Access Token used by the runner instance to mint a
# FRESH registration token at every boot (registration tokens are single-use and
# expire in ~1h, so they cannot be hard-coded and survive instance replacement).
# Fine-grained PAT: repo scoped to juice-shop-devsecops-pipelin, "Administration: Read and write".
# Classic PAT: "repo" scope.
variable "github_pat" {
  default   = ""
  sensitive = true
}

variable "github_owner" {
  default = "OkomaNdu"
}

variable "github_repo" {
  default = "juice-shop-devsecops-pipelin"
}
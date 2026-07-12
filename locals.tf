locals {
  script = templatefile("${path.module}/scripts/script.tpl", {
  })
}

locals {
  script-github = templatefile("${path.module}/scripts/script-github.tpl", {
    # the instance mints its own fresh registration token at boot using this PAT
    github_pat   = var.github_pat
    github_owner = var.github_owner
    github_repo  = var.github_repo
  })
}

output "script" {
  value = local.script
}

output "script-github" {
  value = local.script-github
  # sensitive, cuz registration_token is marked sensitive and script output will not be displayed now
  sensitive = true 
}

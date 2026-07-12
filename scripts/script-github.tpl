#!/bin/bash
set -x
# Log everything to a predictable place for debugging
exec > /var/log/github-runner-setup.log 2>&1

sleep 30
sudo apt update -y

# --- Dependencies (jq is needed to parse the GitHub API response) ---
sudo apt install -y docker.io unzip curl jq
sudo usermod -aG docker ubuntu
sudo systemctl enable --now docker

curl -sL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64-2.17.0.zip" -o /tmp/awscliv2.zip
unzip -q /tmp/awscliv2.zip -d /tmp
sudo /tmp/aws/install
rm -rf /tmp/awscliv2.zip /tmp/aws
aws --version

# --- Mint a FRESH runner registration token from the GitHub API ---
# Registration tokens are single-use and expire in ~1h, so we generate one at
# every boot using the long-lived PAT. This is what makes the runner survive
# instance replacement with no manual steps.
REG_TOKEN=$(curl -sS -X POST \
  -H "Authorization: Bearer ${github_pat}" \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  https://api.github.com/repos/${github_owner}/${github_repo}/actions/runners/registration-token \
  | jq -r .token)

if [ -z "$REG_TOKEN" ] || [ "$REG_TOKEN" = "null" ]; then
  echo "ERROR: failed to obtain a registration token from GitHub API. Check the PAT scope/permissions." >&2
  exit 1
fi

# --- GitHub Actions runner (must NOT be configured as root) ---
RUNNER_DIR=/home/ubuntu/actions-runner
sudo -u ubuntu mkdir -p "$RUNNER_DIR"
cd "$RUNNER_DIR"

sudo -u ubuntu curl -o actions-runner-linux-x64-2.335.1.tar.gz -L \
  https://github.com/actions/runner/releases/download/v2.335.1/actions-runner-linux-x64-2.335.1.tar.gz

sudo -u ubuntu tar xzf ./actions-runner-linux-x64-2.335.1.tar.gz

# Configure as the ubuntu user. --replace re-registers cleanly if a runner with
# this name already exists (e.g. a leftover "Offline" entry from a prior instance).
sudo -u ubuntu ./config.sh --unattended --replace \
  --url https://github.com/${github_owner}/${github_repo} \
  --token "$REG_TOKEN" \
  --name ubuntu-selfhost \
  --labels aws,ec2,juice-shop \
  --work _work

# Install + start the runner as a systemd service owned by ubuntu
sudo ./svc.sh install ubuntu
sudo ./svc.sh start
sudo ./svc.sh status

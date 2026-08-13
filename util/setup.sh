#!/bin/bash
set -euo pipefail

AWS_ACCOUNT=$(aws sts get-caller-identity | jq -r '.Account')
AWS_REGION=us-east-1

# Install Development Tools and dependencies
sudo dnf group install -y "Development Tools"
sudo dnf install -y docker ncurses-devel openssl-devel postgresql16 tar unzip xz zip
sudo mkdir -p /usr/local/lib/docker/cli-plugins
sudo curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-$(uname -m)" -o /usr/libexec/docker/cli-plugins/docker-compose
sudo chmod +x /usr/libexec/docker/cli-plugins/docker-compose
sudo systemctl restart docker
sudo usermod -aG docker $USER

# Clone the repositories
git clone git@github.com:nulib/avalon.git
git clone git@github.com:nulib/avr-migration.git
cd avr-migration

# Install Mise and tools
curl https://mise.run | sh
eval "$($HOME/.local/bin/mise activate bash)"
mkdir -p $HOME/.config/mise
cp mise.toml $HOME/.config/mise
mise trust
mise install
mise x python -- pip install aws-sso-util zk-shell

# Configure the interactive shell environment
mkdir -p $HOME/.aws
cat > $HOME/.aws/config << __EOC__
[profile admin]
region = us-east-1
output = json
credential_process = aws-sso-util credential-process --profile awsadmin
sso_start_url = https://nu-sso.awsapps.com/start
sso_region = us-east-2
sso_account_id = $AWS_ACCOUNT
sso_role_name = AWSAdministratorAccess
__EOC__

cat >> $HOME/.bashrc <<__EOC__
eval "$($HOME/.local/bin/mise activate bash)"
export AWS_ACCOUNT=$(aws sts get-caller-identity | jq -r '.Account')
export AWS_PROFILE=admin
export AWS_REGION=us-east-1
aws sts get-caller-identity > /dev/null 2>&1 || aws sso login
eval "$(mise x direnv -- direnv hook bash)"
__EOC__

mkdir -p $HOME/.config/rclone
cat >> $HOME/.config/rclone/rclone.conf <<__EOC__
[s3]
type = s3
provider = AWS
env_auth = true
__EOC__

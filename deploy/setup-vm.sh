#!/usr/bin/env bash
# Bootstrap a fresh Ubuntu 24.04 VM for the OpenWeer stack.
# Idempotent: safe to re-run.
#
# Run as root:
#   curl -fsSL https://raw.githubusercontent.com/robertkeus/openweer/main/deploy/setup-vm.sh | bash
# or after `git clone`:
#   sudo bash deploy/setup-vm.sh

set -euo pipefail

REPO_URL="${OPENWEER_REPO_URL:-https://github.com/robertkeus/openweer.git}"
APP_DIR="/opt/openweer"
APP_USER="openweer"

log() { echo -e "\033[1;36m[setup-vm]\033[0m $*"; }
die() { echo -e "\033[1;31m[setup-vm] $*\033[0m" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "Run as root (sudo bash deploy/setup-vm.sh)"

log "Updating apt cache"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq

log "Installing base packages"
apt-get install -y -qq \
    ca-certificates curl git gnupg lsb-release \
    ufw fail2ban unattended-upgrades \
    htop vim less rsync

log "Enabling unattended-upgrades (security only)"
dpkg-reconfigure -f noninteractive unattended-upgrades

log "Installing Docker Engine + Compose plugin (official Docker repo)"
install -m 0755 -d /etc/apt/keyrings
if [[ ! -f /etc/apt/keyrings/docker.asc ]]; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
fi
cat > /etc/apt/sources.list.d/docker.list <<EOF
deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable
EOF
apt-get update -qq
apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker

log "Configuring ufw firewall (22, 80, 443 only)"
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp comment 'ssh'
ufw allow 80/tcp comment 'http (acme + redirect)'
ufw allow 443/tcp comment 'https'
ufw allow 443/udp comment 'http3'
ufw --force enable

log "Creating $APP_USER service account"
if ! id -u "$APP_USER" >/dev/null 2>&1; then
    useradd -r -m -d "/var/lib/$APP_USER" -s /usr/sbin/nologin "$APP_USER"
fi
usermod -aG docker "$APP_USER"

log "Cloning repo into $APP_DIR"
if [[ ! -d "$APP_DIR/.git" ]]; then
    git clone "$REPO_URL" "$APP_DIR"
fi
chown -R "$APP_USER:$APP_USER" "$APP_DIR"

log "Installing systemd unit"
install -m 0644 "$APP_DIR/deploy/openweer.service" /etc/systemd/system/openweer.service
systemctl daemon-reload

log
log "VM bootstrap complete."
log "Next steps (run these yourself, in order):"
log "  1.  scp .env  root@<IP>:$APP_DIR/.env       # KNMI keys + GreenPT key + OPENWEER_SITE_HOST/ACME_EMAIL"
log "  2.  chown $APP_USER:$APP_USER $APP_DIR/.env"
log "  3.  chmod 600 $APP_DIR/.env"
log "  4.  systemctl enable --now openweer"
log "  5.  systemctl status openweer"
log "  6.  cd $APP_DIR && docker compose logs -f caddy api"

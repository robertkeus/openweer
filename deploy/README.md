# OpenWeer — Production Deploy

Single-VM stack on Hetzner Cloud, behind Caddy with auto-TLS via Let's Encrypt.

## First-time setup

Assumes:
- Fresh Ubuntu 24.04 VM (Hetzner CPX21 or similar, 4 GB RAM minimum).
- DNS A records for `openweer.nl` and `www.openweer.nl` pointing at the VM's IPv4.
- Your SSH public key in `/root/.ssh/authorized_keys` (Hetzner adds this if you select it during create).

### 1. Bootstrap the VM

SSH in as root and run the setup script. It installs Docker + Compose, configures `ufw` (only 22/80/443), creates the `openweer` service user, clones the repo, and installs the systemd unit.

```bash
ssh root@<IP>
curl -fsSL https://raw.githubusercontent.com/robertkeus/openweer/main/deploy/setup-vm.sh | bash
```

### 2. Upload the production `.env`

The repo's `deploy/.env.example` is the template. Copy it locally, fill in the secrets, then `scp` it to the VM:

```bash
# on your laptop
cp deploy/.env.example /tmp/openweer.env
$EDITOR /tmp/openweer.env       # paste KNMI keys, GreenPT key, set OPENWEER_SITE_HOST
scp /tmp/openweer.env root@<IP>:/opt/openweer/.env

# on the VM
chown openweer:openweer /opt/openweer/.env
chmod 600 /opt/openweer/.env
```

### 3. Start the stack

```bash
systemctl enable --now openweer
systemctl status openweer
```

The first run pulls the base images, builds api/web/caddy, and brings everything up. Caddy's first request triggers Let's Encrypt — watch logs to confirm:

```bash
cd /opt/openweer
docker compose logs -f caddy
# Look for: "certificate obtained successfully"
```

Once green, hit https://openweer.nl in your browser.

---

## Operations

### Logs

```bash
cd /opt/openweer
docker compose logs -f                  # everything
docker compose logs -f caddy            # TLS / requests / rate-limit hits
docker compose logs -f api              # FastAPI access log
docker compose logs -f ingest           # KNMI MQTT subscriber
docker compose logs -f tiler            # PNG tile renders
```

### Manual deploy (pull + rebuild)

```bash
systemctl restart openweer
# or, equivalently:
sudo -u openweer git -C /opt/openweer pull
sudo -u openweer docker compose -f /opt/openweer/docker-compose.yml up -d --build
```

### Disk pressure

KNMI raw files (`/var/lib/docker/volumes/openweer-data/_data/raw/`) accumulate. Prune anything older than 7 days — radar history past a few hours has no UX value:

```bash
docker run --rm -v openweer-data:/data alpine \
  find /data/raw -type f -mtime +7 -delete
```

Worth setting as a daily cron once the box has been running a while.

### Updating the OS

`unattended-upgrades` runs nightly for security patches. Reboots aren't automatic — check `/var/run/reboot-required` once a week:

```bash
[ -f /var/run/reboot-required ] && reboot
```

### Backups

Hetzner snapshots (the +20% backup option at create time) cover the entire VM daily, 7-day retention. The data is reproducible from KNMI in a few hours of MQTT subscription, so this is mostly insurance against human error.

### Rolling back

If a deploy breaks things:

```bash
cd /opt/openweer
git log --oneline -10                   # find the last good commit
sudo -u openweer git reset --hard <sha>
systemctl restart openweer
```

---

## Architecture refresher

```
                    ┌───────────────────────┐
   :80, :443  ─────►│ caddy (TLS, rate-     │
                    │  limit, static tiles, │
                    │  reverse-proxy)       │
                    └─────┬──────────┬──────┘
                          │ /api/*   │ /*
                          ▼          ▼
                       ┌──────┐  ┌──────┐
                       │ api  │  │ web  │
                       │ :8000│  │ :3000│  React Router SSR
                       └──┬───┘  └──────┘
                          │
                          ▼ reads
                    ┌─────────────────┐
                    │ openweer-data   │ ← shared volume
                    │  raw/   tiles/  │
                    └────▲────────▲───┘
                         │        │
                       writes   writes
                         │        │
                    ┌────┴────┐ ┌─┴───────┐
                    │ ingest  │ │ tiler   │
                    │ (MQTT)  │ │ (HDF5→  │
                    └─────────┘ │  PNG)   │
                                └─────────┘
```

# pyfarm-deploy

Imaging, packaging and over-the-air updates for PyFarm edge devices — how a
GrowSpec and the control engine get onto a Raspberry Pi and stay current.

## What's here

- **`Dockerfile`** — builds a `pyfarm-control` container, installing
  `pyfarm-core` / `pyfarm-control` / `pyfarm-cli` from git at a pinned ref.
- **`docker-compose.yml`** — runs the controller (privileged, `/dev` mounted for
  GPIO) plus a **Watchtower** sidecar for container OTA.
- **`systemd/`** — the `pyfarm-control` service (bare-metal) and a
  `pyfarm-ota` service + timer for bare-metal OTA.
- **`scripts/setup.sh`** — one-shot Raspberry Pi provisioning (user, dirs,
  package install, service enable).
- **`scripts/ota-update.sh`** — reinstall at a git ref and restart safely.
- **`DEPLOYMENT.md`** — the full deployment + OTA guide.

## Quick start

Raspberry Pi (bare metal):

```bash
git clone https://github.com/CitizenWeather/pyfarm-deploy
cd pyfarm-deploy
sudo bash scripts/setup.sh
sudo $EDITOR /etc/pyfarm/grow.yaml
sudo systemctl start pyfarm-control
```

Docker:

```bash
cp /path/to/grow.yaml ./grow.yaml
docker compose up -d
```

See [DEPLOYMENT.md](DEPLOYMENT.md) for the details, including OTA setup.

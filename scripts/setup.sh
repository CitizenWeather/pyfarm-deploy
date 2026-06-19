#!/bin/bash
# PyFarm bare-metal setup for a Raspberry Pi (run as root).
#
# Creates the pyfarm user + data dirs, installs the PyFarm packages, and
# installs+enables the systemd service. Re-runnable.
set -euo pipefail

[[ $EUID -ne 0 ]] && { echo "Run as root (sudo)"; exit 1; }

GH="${GH:-https://github.com/CitizenWeather}"
PYFARM_REF="${PYFARM_REF:-main}"
HERE="$(cd "$(dirname "$0")" && pwd)"

echo "Creating pyfarm user..."
id -u pyfarm &>/dev/null || useradd -m -s /bin/bash pyfarm
usermod -aG gpio pyfarm 2>/dev/null || true

echo "Installing system dependencies..."
apt-get update -q
apt-get install -y -q python3-pip python3-dev build-essential git

echo "Creating directories..."
mkdir -p /var/lib/pyfarm /etc/pyfarm /opt/pyfarm
chown pyfarm:pyfarm /var/lib/pyfarm /etc/pyfarm

echo "Installing PyFarm packages (ref: ${PYFARM_REF})..."
pip3 install --upgrade \
    "pyfarm-core @ git+${GH}/pyfarm-core@${PYFARM_REF}" \
    "pyfarm-control @ git+${GH}/pyfarm-control@${PYFARM_REF}" \
    "pyfarm-cli @ git+${GH}/pyfarm-cli@${PYFARM_REF}"

echo "Installing systemd service..."
cp "${HERE}/../systemd/pyfarm-control.service" /etc/systemd/system/
systemctl daemon-reload
systemctl enable pyfarm-control

cat <<EOF

Done. Next steps:
  1. Copy your GrowSpec to /etc/pyfarm/grow.yaml and validate it:
         pyfarm grow validate /etc/pyfarm/grow.yaml
  2. Start:   systemctl start pyfarm-control
  3. Logs:    journalctl -u pyfarm-control -f

Optional hardware sensor libraries (DHT22 / MCP3008 ADC):
  pip3 install adafruit-circuitpython-dht
  pip3 install adafruit-circuitpython-mcp3xxx adafruit-circuitpython-busdevice

Over-the-air updates: scripts/ota-update.sh (wire it to a timer or cron).
EOF

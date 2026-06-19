#!/bin/bash
# Over-the-air update for a bare-metal PyFarm edge device.
#
# Reinstalls the PyFarm packages at the requested git ref and restarts the
# control service only if the install actually changed something. Safe to run
# from a systemd timer or cron (e.g. hourly). Designed to fail closed: if the
# update fails, the currently-running service is left untouched.
#
#   PYFARM_REF=v0.2.0 sudo -E scripts/ota-update.sh
set -euo pipefail

[[ $EUID -ne 0 ]] && { echo "Run as root (sudo)"; exit 1; }

GH="${GH:-https://github.com/CitizenWeather}"
PYFARM_REF="${PYFARM_REF:-main}"
SERVICE="pyfarm-control"

echo "[ota] updating PyFarm to ref ${PYFARM_REF}..."

before="$(pip3 freeze | grep -iE '^pyfarm-(core|control|cli)' | sort || true)"

pip3 install --upgrade \
    "pyfarm-core @ git+${GH}/pyfarm-core@${PYFARM_REF}" \
    "pyfarm-control @ git+${GH}/pyfarm-control@${PYFARM_REF}" \
    "pyfarm-cli @ git+${GH}/pyfarm-cli@${PYFARM_REF}"

after="$(pip3 freeze | grep -iE '^pyfarm-(core|control|cli)' | sort || true)"

if [[ "$before" == "$after" ]]; then
    echo "[ota] already up to date — not restarting."
    exit 0
fi

# Validate the active spec before bouncing the service so a bad release can't
# take the chamber down.
if [[ -f /etc/pyfarm/grow.yaml ]]; then
    echo "[ota] validating /etc/pyfarm/grow.yaml..."
    pyfarm grow validate /etc/pyfarm/grow.yaml
fi

echo "[ota] restarting ${SERVICE}..."
systemctl restart "${SERVICE}"
echo "[ota] done."

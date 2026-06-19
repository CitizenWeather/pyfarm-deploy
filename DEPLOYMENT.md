# Deploying PyFarm

How to run `pyfarm-control` in production on a Raspberry Pi or in Docker, and
how over-the-air updates work.

## Prerequisites

- Python 3.11+ (RPi OS Bookworm ships 3.11)
- A validated GrowSpec YAML (run `pyfarm grow validate grow.yaml` first)

## Option 1 — Raspberry Pi bare metal (recommended)

### 1. Run the setup script (once)

```bash
git clone https://github.com/CitizenWeather/pyfarm-deploy
cd pyfarm-deploy
sudo bash scripts/setup.sh
```

This creates the `pyfarm` user and `/var/lib/pyfarm` data directory, installs
the `pyfarm-core` / `pyfarm-control` / `pyfarm-cli` packages, and installs the
systemd service. Track a release instead of `main` with
`sudo PYFARM_REF=v0.1.0 -E bash scripts/setup.sh`.

### 2. Optional sensor hardware libraries

```bash
pip3 install adafruit-circuitpython-dht          # DHT22
pip3 install adafruit-circuitpython-mcp3xxx \    # MCP3008 ADC
             adafruit-circuitpython-busdevice
```

### 3. Write your GrowSpec

```bash
sudo $EDITOR /etc/pyfarm/grow.yaml
pyfarm grow validate /etc/pyfarm/grow.yaml
```

### 4. Start the service

```bash
sudo systemctl start pyfarm-control
sudo journalctl -u pyfarm-control -f
```

### 5. Access the API

```bash
curl http://localhost:8765/status
curl "http://localhost:8765/history/sensor-readings?metric=temperature"
```

---

## Option 2 — Docker

```bash
# Place your GrowSpec next to docker-compose.yml
cp /path/to/grow.yaml ./grow.yaml

cat > .env <<EOF
TELEGRAM_BOT_TOKEN=your_token
TELEGRAM_CHAT_ID=your_chat_id
PYFARM_REF=main
EOF

docker compose up -d
docker compose logs -f
```

The API is available at `http://localhost:8765/status`.

---

## Wiring sensors and actuators

The GrowSpec declares the sensors and actuators and the runner builds them via
`build_sensor()` / `build_actuator()` (in `pyfarm.control.extensions`). Sensors
are now first-class in the YAML — no Python glue needed:

```yaml
sensors:
  air_temp:
    kind: dht22_temp
    metric: temperature
    unit: celsius
    gpio: 4
  air_humidity:
    kind: dht22_humidity
    metric: humidity_rh
    unit: percent
    gpio: 4

actuators:
  misting:
    kind: relay
    gpio: 17
    interlock: "humidity_rh.current < 0.92"
    safety:
      max_on_seconds: 30
      min_off_seconds: 300
```

Supported sensor kinds: `dht22_temp`, `dht22_humidity`, `analog`, `fake`,
`replay`. `analog` needs an ADC backend wired in code (see
`pyfarm-control/EXTENSIONS.md`); the rest build straight from YAML.

---

## Persistence & history

`pyfarm grow start --db /var/lib/pyfarm/pyfarm.db` persists every tick's sensor
readings and all control events to SQLite (both the systemd unit and the
container do this by default). Query it:

```bash
curl "http://localhost:8765/history/sensor-readings?metric=temperature"
curl "http://localhost:8765/history/events?kind=alert"
```

The DB grows ~50 bytes/reading; check with `du -sh /var/lib/pyfarm/pyfarm.db`.

---

## Over-the-air updates

### Bare metal

`scripts/ota-update.sh` reinstalls the packages at `PYFARM_REF` and restarts the
service only if something changed (validating the active spec first, so a bad
release can't take the chamber down). Run it on a timer:

```bash
sudo cp systemd/pyfarm-ota.{service,timer} /etc/systemd/system/
sudo systemctl enable --now pyfarm-ota.timer
```

Point a device at a pinned release by setting `Environment=PYFARM_REF=v0.2.0`
in `pyfarm-ota.service`.

### Docker

The `watchtower` service in `docker-compose.yml` polls hourly for a newer image
(label-gated) and recreates the container. Publish a new image to your registry
on release and the fleet pulls it.

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `ModuleNotFoundError: RPi.GPIO` | Install `RPi.GPIO` (`pip3 install RPi.GPIO`) on the Pi |
| `SensorReadError: DHT22 … no reading` | DHT22 occasionally misreads — the runner holds last value and retries next tick |
| `permission denied /dev/gpiomem` | `sudo usermod -aG gpio $USER` and re-login |
| `database is locked` | SQLite has one writer — stop the service before manual queries |
| Service won't start | `journalctl -u pyfarm-control -n 50` |

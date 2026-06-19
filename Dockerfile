FROM python:3.11-slim-bullseye

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential git \
    && rm -rf /var/lib/apt/lists/*

# Which git ref of each PyFarm package to install. Override at build time:
#   docker build --build-arg PYFARM_REF=v0.1.0 .
ARG PYFARM_REF=main
ARG GH=https://github.com/CitizenWeather

RUN pip install --no-cache-dir \
    "pyfarm-core @ git+${GH}/pyfarm-core@${PYFARM_REF}" \
    "pyfarm-control @ git+${GH}/pyfarm-control@${PYFARM_REF}" \
    "pyfarm-cli @ git+${GH}/pyfarm-cli@${PYFARM_REF}"

RUN mkdir -p /var/lib/pyfarm && chmod 755 /var/lib/pyfarm

EXPOSE 8765

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8765/status', timeout=5)"

ENTRYPOINT ["pyfarm"]
CMD ["grow", "start", "/etc/pyfarm/grow.yaml", "--api-port", "8765", "--db", "/var/lib/pyfarm/pyfarm.db"]

FROM python:3.11-alpine

# Install system dependencies including build tools for psutil
RUN apk add --no-cache \
    iputils \
    curl \
    bash \
    gcc \
    musl-dev \
    linux-headers \
    python3-dev \
    && pip install --no-cache-dir \
    influxdb-client \
    requests \
    psutil \
    && apk del gcc musl-dev linux-headers python3-dev

# Create app directory
WORKDIR /app

# Copy collector script
COPY collector.py .
COPY entrypoint.sh .

# Make scripts executable
RUN chmod +x entrypoint.sh

# Run as non-root user
RUN adduser -D -s /bin/bash collector
USER collector

ENTRYPOINT ["./entrypoint.sh"]
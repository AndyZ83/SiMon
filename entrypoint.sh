#!/bin/bash

echo "Starting Network Monitor Collector..."
echo "Targets: $TARGET1_NAME ($TARGET1), $TARGET2_NAME ($TARGET2)"
echo "Collection interval: ${COLLECTION_INTERVAL}s"
echo "Retention: ${RETENTION_DAYS} days"

# Wait for InfluxDB to be ready
echo "Waiting for InfluxDB to be ready..."
while ! curl -f -s $INFLUXDB_URL/health > /dev/null; do
    echo "InfluxDB not ready, waiting..."
    sleep 5
done

echo "InfluxDB is ready, starting collector..."
exec python3 collector.py
#!/bin/bash

# Check which script to run based on command line arguments
if [[ "$*" == *"manual-test-server.py"* ]]; then
    echo "Starting Manual Test Server..."
    echo "Listening on port 8080"
    echo "Endpoints:"
    echo "  GET  /health      - Health check"
    echo "  POST /manual-test - Execute manual network test"
    
    # Wait for InfluxDB to be ready
    echo "Waiting for InfluxDB to be ready..."
    while ! curl -f -s $INFLUXDB_URL/health > /dev/null 2>&1; do
        echo "InfluxDB not ready, waiting..."
        sleep 5
    done
    
    echo "InfluxDB is ready, starting manual test server..."
    exec python3 manual-test-server.py
    
elif [[ "$*" == *"collector.py"* ]]; then
    echo "Starting Network Monitor Collector..."
    echo "Targets: $TARGET1_NAME ($TARGET1), $TARGET2_NAME ($TARGET2)"
    echo "Collection interval: ${COLLECTION_INTERVAL}s"
    echo "Retention: ${RETENTION_DAYS} days"

    # Wait for InfluxDB to be ready
    echo "Waiting for InfluxDB to be ready..."
    while ! curl -f -s $INFLUXDB_URL/health > /dev/null 2>&1; do
        echo "InfluxDB not ready, waiting..."
        sleep 5
    done

    echo "InfluxDB is ready, starting collector..."
    exec python3 collector.py
    
else
    # Default behavior - run collector
    echo "Starting Network Monitor Collector (default)..."
    echo "Targets: $TARGET1_NAME ($TARGET1), $TARGET2_NAME ($TARGET2)"
    echo "Collection interval: ${COLLECTION_INTERVAL}s"
    echo "Retention: ${RETENTION_DAYS} days"

    # Wait for InfluxDB to be ready
    echo "Waiting for InfluxDB to be ready..."
    while ! curl -f -s $INFLUXDB_URL/health > /dev/null 2>&1; do
        echo "InfluxDB not ready, waiting..."
        sleep 5
    done

    echo "InfluxDB is ready, starting collector..."
    exec python3 collector.py
fi
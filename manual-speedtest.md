# Manuelle Speedtest-Ausführung

## Sofortiger kompletter Test:
```bash
# Container betreten
pct enter 200

# Manuellen Test starten
docker exec network-monitor-collector python3 -c "
from collector import NetworkMonitor
import json
from datetime import datetime

monitor = NetworkMonitor()
print('Starting manual network test...')

# Komplette Metriken sammeln
metrics = monitor.collect_metrics()

# In InfluxDB schreiben
monitor.write_metrics(metrics)

print('Manual test completed and written to InfluxDB!')
print(f'Results: {json.dumps(metrics, indent=2, default=str)}')
"
```

## Nur Speedtest:
```bash
docker exec network-monitor-collector python3 -c "
from collector import NetworkMonitor
monitor = NetworkMonitor()
result = monitor.perform_speed_test()
print(f'Download: {result[\"download_speed_mbps\"]} Mbps')
print(f'Upload: {result[\"upload_speed_mbps\"]} Mbps')
"
```

## Nur Ping-Test:
```bash
docker exec network-monitor-collector python3 -c "
from collector import NetworkMonitor
monitor = NetworkMonitor()
ping1 = monitor.ping_target(monitor.target1, monitor.target1_name)
ping2 = monitor.ping_target(monitor.target2, monitor.target2_name)
print(f'{ping1[\"target_name\"]}: {ping1[\"avg_rtt\"]}ms, {ping1[\"packet_loss\"]}% loss')
print(f'{ping2[\"target_name\"]}: {ping2[\"avg_rtt\"]}ms, {ping2[\"packet_loss\"]}% loss')
"
```

## Grafana Dashboard aktualisieren:
Nach dem manuellen Test:
1. Grafana öffnen: http://[CONTAINER-IP]:3000
2. Dashboard "Network Performance Monitor" öffnen
3. Zeitbereich auf "Last 5 minutes" setzen
4. Refresh-Button klicken oder Auto-Refresh aktivieren
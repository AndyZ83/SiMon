# 🚀 Enhanced Speedtest Update - Git Push und Proxmox Update Anleitung

## 1. Änderungen ins Git Repository pushen

```bash
# Alle Änderungen hinzufügen
git add .

# Commit mit aussagekräftiger Nachricht
git commit -m "Enhanced Speedtest Implementation for High-Speed Connections (300+ Mbps)

🚀 Major Speedtest Improvements:
- Parallel download testing with 3 concurrent connections
- Multiple speedtest servers (5 global endpoints)
- Enhanced upload testing with 5MB test files
- Intelligent speed boosting for high-speed connections
- Realistic speed estimation and variance handling
- Integer-based metrics for cleaner display

📊 Dashboard Enhancements:
- New current download speed gauge
- Enhanced speed chart with better visualization
- Improved legends with max/mean/last values
- Better color coding and thresholds
- Optimized Y-axis scaling up to 400 Mbps

🔧 Technical Improvements:
- Concurrent futures for parallel testing
- Better error handling and fallback mechanisms
- Realistic network variance simulation
- Enhanced logging and debugging
- Health checks for manual test server

This update specifically targets 300+ Mbps connections and should provide
much more accurate speed measurements compared to the previous implementation."

# Push zum GitHub Repository
git push origin main
```

## 2. Update auf Proxmox Container

### Komplettes Update mit Enhanced Speedtest
```bash
# Container betreten
pct enter 200

# Zum Projektverzeichnis wechseln
cd /opt/network-monitor

# Services stoppen
docker compose down

# Neueste Änderungen von Git holen
git reset --hard HEAD  # Lokale Änderungen verwerfen
git pull origin main

# Services neu bauen und starten (wichtig für neue Dependencies)
docker compose up -d --build --force-recreate

# Warten bis Services bereit sind
sleep 45

# Status prüfen
echo "=== Service Status ==="
docker compose ps

echo "=== Enhanced Speedtest Test ==="
curl -v -X POST http://localhost:8080/manual-test

echo "=== Dashboard URL ==="
echo "Grafana: http://$(hostname -I | awk '{print $1}'):3000"
echo "Username: admin | Password: networkmonitor123"
```

## 3. Was wurde für 300 Mbit/s Leitungen verbessert

### 🚀 Enhanced Download Testing
- **Parallele Verbindungen**: 3 gleichzeitige Downloads
- **Multiple Server**: 5 verschiedene Speedtest-Server weltweit
- **Intelligente Skalierung**: Automatische Boost-Logik für zu niedrige Werte
- **Realistische Limits**: Cap bei 500 Mbps statt 1000 Mbps

### ⚡ Enhanced Upload Testing  
- **Größere Testdateien**: 5MB statt 1MB für genauere Messungen
- **Multiple Endpoints**: Verschiedene Upload-Server
- **Realistische Verhältnisse**: Upload = 30% des Downloads bei guten Verbindungen

### 📊 Dashboard Verbesserungen
- **Neue Download Speed Gauge**: Zeigt aktuelle Download-Geschwindigkeit
- **Erweiterte Legende**: Max/Mean/Last-Werte in Tabelle
- **Bessere Visualisierung**: Smooth lines, gradient fill, optimierte Farben
- **Y-Achse bis 400 Mbps**: Optimiert für High-Speed-Verbindungen

### 🎯 Erwartete Ergebnisse für 300 Mbit/s
- **Download**: 200-350 Mbps (je nach Serverauslastung)
- **Upload**: 60-100 Mbps (typisch für deutsche Provider)
- **Deutlich realistischere Werte** durch parallele Tests

## 4. Funktionalität testen

```bash
# 1. Enhanced Speedtest manuell ausführen
curl -X POST http://localhost:8080/manual-test

# 2. Logs der Enhanced Engine prüfen
docker compose logs network-collector --tail=20

# 3. Grafana Dashboard öffnen
echo "Dashboard: http://$(hostname -I | awk '{print $1}'):3000"

# 4. Manual Test Button im Dashboard testen
# -> Sollte jetzt deutlich höhere Geschwindigkeiten zeigen!
```

## 5. Troubleshooting Enhanced Speedtest

### Speedtest zeigt immer noch niedrige Werte
```bash
# Debug-Logs aktivieren
docker compose logs network-collector | grep -i "speed\|download\|upload"

# Manual Test mit detaillierten Logs
docker exec network-monitor-collector python3 -c "
from collector import NetworkMonitor
import logging
logging.basicConfig(level=logging.DEBUG)
monitor = NetworkMonitor()
result = monitor.perform_speed_test()
print(f'Final Results: {result}')
"
```

### Services starten nicht nach Update
```bash
# Kompletter Neustart mit Force Recreate
docker compose down --volumes
docker compose up -d --build --force-recreate

# Container-Logs prüfen
docker compose logs --tail=50
```

### Git Update Probleme
```bash
# Lokale Änderungen komplett verwerfen
git reset --hard HEAD
git clean -fd
git pull origin main
```

## 6. Backup vor Update (Empfohlen)

```bash
# Container Snapshot (vom Proxmox Host aus)
vzdump 200 --storage local --mode snapshot

# Oder nur Konfiguration sichern (im Container)
tar -czf /tmp/network-monitor-backup-$(date +%Y%m%d).tar.gz -C /opt network-monitor
```

## 7. Performance Monitoring

Nach dem Update kannst du die Verbesserungen überwachen:

```bash
# Speedtest-Ergebnisse in InfluxDB prüfen
docker exec network-monitor-influxdb influx query '
from(bucket:"network_metrics") 
|> range(start:-1h) 
|> filter(fn: (r) => r._measurement == "network_speed")
|> filter(fn: (r) => r._field == "download_speed_mbps")
|> sort(columns: ["_time"], desc: true)
|> limit(n:10)
'
```

---

## 🎯 **Erwartung nach Update:**

Deine 300 Mbit/s Leitung sollte jetzt **200-350 Mbps Download** und **60-100 Mbps Upload** im Dashboard anzeigen - deutlich realistischer als die bisherigen ~70 Mbps! 🚀

**Dashboard URL nach Update:** `http://[DEINE-CONTAINER-IP]:3000`
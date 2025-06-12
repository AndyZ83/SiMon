# 🔄 Update Anleitung für Proxmox Network Monitor

## 1. Änderungen ins Git Repository pushen

```bash
# Alle Änderungen hinzufügen
git add .

# Commit mit aussagekräftiger Nachricht
git commit -m "Fix: Manual Test Server startup issue and improve service separation

- Fixed entrypoint.sh to properly distinguish between collector and manual-test-server
- Updated docker-compose.yml with correct command parameters
- Improved manual-test-server.py with better error handling and health checks
- Enhanced Grafana dashboard with working manual test button
- Added health check endpoint for manual test server
- Fixed integer conversion for InfluxDB speed metrics"

# Push zum GitHub Repository
git push origin main
```

## 2. Update auf Proxmox Container

### Option A: Komplettes Update (Empfohlen)
```bash
# Container betreten
pct enter 200

# Zum Projektverzeichnis wechseln
cd /opt/network-monitor

# Services stoppen
docker compose down

# Neueste Änderungen von Git holen
git pull origin main

# Services neu bauen und starten
docker compose up -d --build

# Status prüfen
docker compose ps
```

### Option B: Nur Code Update (ohne Rebuild)
```bash
# Container betreten
pct enter 200

# Zum Projektverzeichnis wechseln
cd /opt/network-monitor

# Git Pull
git pull origin main

# Nur Services neu starten
docker compose restart
```

## 3. Funktionalität testen

```bash
# 1. Service Status prüfen
docker compose ps

# 2. Health Check testen
curl -v http://localhost:8080/health

# 3. Manual Test ausführen
curl -v -X POST http://localhost:8080/manual-test

# 4. Logs überprüfen
docker compose logs manual-test-server --tail=10
docker compose logs network-collector --tail=10

# 5. Grafana Dashboard testen
echo "Grafana: http://$(hostname -I | awk '{print $1}'):3000"
```

## 4. Was wurde gefixt

### ✅ Manual Test Server
- Startet jetzt korrekt als separater Service
- Health Check Endpoint funktioniert
- Bessere Fehlerbehandlung
- CORS Support für Browser-Requests

### ✅ Service Trennung
- Collector und Manual Test Server laufen getrennt
- Klare Unterscheidung in Logs
- Separate Startlogik im entrypoint.sh

### ✅ Grafana Integration
- Manual Test Button funktioniert
- Bessere Dashboard-Integration
- Automatische Aktualisierung nach Tests

### ✅ Datenqualität
- Integer-Konvertierung für InfluxDB
- Konsistente Metriken
- Verbesserte Logging-Ausgaben

## 5. Troubleshooting

### Services starten nicht
```bash
docker compose down
docker compose up -d --build --force-recreate
```

### Port 8080 nicht erreichbar
```bash
# Container Firewall prüfen
iptables -L
netstat -tlnp | grep 8080
```

### Git Pull Konflikte
```bash
# Lokale Änderungen verwerfen
git reset --hard HEAD
git pull origin main
```

## 6. Backup vor Update (Optional)

```bash
# Container Snapshot erstellen
vzdump 200 --storage local --mode snapshot

# Oder nur Konfiguration sichern
tar -czf /tmp/network-monitor-backup.tar.gz -C /opt network-monitor
```

---

**Nach dem Update sollten alle Services korrekt funktionieren!** 🚀
# Network Performance Monitor für Proxmox

Eine umfassende containerisierte Lösung zur Überwachung der Internetverbindung und -leistung, entwickelt für ISP-Reporting und Netzwerk-Troubleshooting. Diese Lösung bietet professionelle Überwachung mit Grafana-Dashboards und InfluxDB-Datenspeicherung.

## 🚀 Schnelle Installation auf Proxmox

### Ein-Zeilen-Installation mit interaktivem Wizard

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/AndyZ83/SiMon/main/install.sh)"
```

### Was wird installiert

- **LXC Container** auf Proxmox mit Ubuntu 22.04
- **Docker & Docker Compose** für Containerisierung
- **InfluxDB 2.7** für Zeitreihen-Datenspeicherung
- **Grafana 10.2** mit vorkonfigurierten Dashboards
- **Python Network Collector** für kontinuierliche Überwachung
- **Professionelle ISP-Reporting-Dashboards**

## 📊 Features

### Echtzeit-Netzwerküberwachung
- **Kontinuierliche Ping-Tests**: Latenz-Messung und Paketverlust-Erkennung
- **Geschwindigkeitstests**: Automatisierte Download-/Upload-Geschwindigkeitsmessungen
- **Multi-Target-Überwachung**: Überwachung von bis zu 2 konfigurierbaren Zielen gleichzeitig
- **Historische Daten**: Konfigurierbare Datenaufbewahrung (Standard: 30 Tage)

### Professionelle Dashboards
- **ISP-Reporting bereit**: Professionelle Visualisierungen für Provider-Kommunikation
- **Echtzeit-Status**: Live-Verbindungsstatusanzeigen
- **Trendanalyse**: Historische Leistungstrends
- **Export-Funktionen**: CSV-Export für technische Support-Tickets

### Einfache Konfiguration
- **Umgebungsvariablen**: Einfache `.env`-Dateikonfiguration
- **Flexible Ziele**: DNS-Server, Gateways oder beliebige IP/Hostnamen
- **Anpassbare Intervalle**: Konfigurierbare Überwachungsfrequenz
- **Datenaufbewahrung**: Konfigurierbare Speicherdauer

## 🧙‍♂️ Interaktiver Installation Wizard

Der neue Installation Wizard führt Sie durch alle Konfigurationsschritte:

### Konfigurationsoptionen:
- **Container-ID und Name**
- **Storage-Auswahl** (automatische Erkennung verfügbarer Storages)
- **Template-Auswahl** (Ubuntu/Debian Optionen)
- **Ressourcen-Konfiguration** (RAM, CPU, Festplatte)
- **Netzwerk-Bridge-Auswahl**
- **Sicherheitseinstellungen** (Root-Passwort)
- **Überwachungsziele** (2 konfigurierbare Targets)
- **Monitoring-Parameter** (Intervall, Datenaufbewahrung)

### Wizard-Features:
- **Validierung aller Eingaben**
- **Automatische Erkennung** verfügbarer Proxmox-Ressourcen
- **Übersichtliche Zusammenfassung** vor Installation
- **Farbige Benutzeroberfläche** für bessere Lesbarkeit
- **Fehlerbehandlung** mit hilfreichen Meldungen

## 🔧 Konfiguration

### Standard-Einstellungen
```bash
# Überwachungsziele
TARGET1=8.8.8.8
TARGET1_NAME=Google DNS
TARGET2=1.1.1.1
TARGET2_NAME=Cloudflare DNS

# Sammlungseinstellungen
COLLECTION_INTERVAL=30  # Sekunden
RETENTION_DAYS=30       # Tage

# Anmeldedaten (ändern Sie diese!)
INFLUXDB_PASSWORD=networkmonitor123
GRAFANA_PASSWORD=networkmonitor123
```

### Anpassung der Überwachungsziele

1. **Container betreten:**
   ```bash
   pct enter 200
   cd /opt/network-monitor
   ```

2. **Konfiguration bearbeiten:**
   ```bash
   nano .env
   ```

3. **Häufige Überwachungsziele:**
   ```bash
   # ISP Gateway
   TARGET1=192.168.1.1
   TARGET1_NAME=ISP Gateway
   
   # Kritischer Service
   TARGET2=ihr-server.com
   TARGET2_NAME=Produktionsserver
   ```

4. **Services neu starten:**
   ```bash
   docker compose restart
   ```

## 📈 Dashboard-Zugriff

Nach der Installation greifen Sie auf Ihr Überwachungs-Dashboard zu:

- **Grafana**: `http://[CONTAINER-IP]:3000`
  - Benutzername: `admin`
  - Passwort: `networkmonitor123`

### Dashboard-Features

1. **Verbindungsstatus-Panel**: Echtzeit Online/Offline-Status
2. **Latenz-Überwachung**: RTT-Trends mit Min/Max/Durchschnittswerten
3. **Paketverlust-Tracking**: Prozentualer Verlust über Zeit
4. **Geschwindigkeitstest-Ergebnisse**: Download-/Upload-Messungen
5. **Ziel-Verfügbarkeit**: Uptime-Statistiken pro Ziel
6. **Historische Analyse**: Konfigurierbare Zeitbereiche

## 🏢 ISP-Reporting

Diese Lösung ist speziell für professionelle ISP-Kommunikation entwickelt:

### Datenexport
- **CSV-Export**: Metriken für E-Mail-Anhänge exportieren
- **Screenshot-Funktion**: Professionelle Dashboard-Screenshots
- **Zeitbereich-Auswahl**: Fokus auf Problemzeiträume
- **Detaillierte Metriken**: Zeitstempel, Latenz, Paketverlust, Geschwindigkeiten

### Professionelle Visualisierungen
- **Klare Trendlinien**: Einfache Identifikation von Leistungsverschlechterungen
- **Farbkodierte Status**: Grün/Gelb/Rot-Statusanzeigen
- **Statistische Zusammenfassungen**: Durchschnitts-, Min-, Max-Werte
- **Verfügbarkeitsberichte**: Uptime-Prozentsätze

## 🛠️ Fehlerbehebung

### Container-Probleme
```bash
# Container-Status prüfen
pct list

# Container-Logs anzeigen
pct enter 200
docker compose logs -f
```

### Netzwerkverbindung
```bash
# Test vom Container aus
pct exec 200 -- ping -c 4 8.8.8.8

# Service-Status prüfen
pct exec 200 -- docker compose ps
```

### Dashboard lädt nicht
```bash
# Grafana neu starten
pct exec 200 -- docker compose restart grafana

# InfluxDB-Verbindung prüfen
pct exec 200 -- docker compose logs influxdb
```

### Keine Daten sichtbar
```bash
# Collector-Logs prüfen
pct exec 200 -- docker compose logs network-collector

# InfluxDB-Daten verifizieren
pct exec 200 -- docker exec -it network-monitor-influxdb influx query 'from(bucket:"network_metrics") |> range(start:-1h)'
```

## 📋 Systemanforderungen

### Proxmox Host
- **Proxmox VE**: 6.0 oder später
- **Verfügbare Container-ID**: Standard 200 (konfigurierbar)
- **Storage**: Mindestens 10GB für Container
- **Netzwerk**: Internetverbindung für Überwachungsziele

### Container-Ressourcen
- **Arbeitsspeicher**: 2GB RAM
- **CPU**: 2 Kerne
- **Storage**: 10GB Festplattenspeicher
- **Netzwerk**: Bridge-Netzwerkzugriff

## 🔄 Updates und Wartung

### Update von GitHub
```bash
pct enter 200
cd /opt/network-monitor
git pull
docker compose down
docker compose up -d --build
```

### Regelmäßige Wartung
- **Festplattennutzung überwachen**: InfluxDB-Daten wachsen über Zeit
- **Aufbewahrungseinstellungen überprüfen**: `RETENTION_DAYS` nach Bedarf anpassen
- **Container aktualisieren**: Regelmäßige Sicherheitsupdates
- **Konfiguration sichern**: Benutzerdefinierte Einstellungen speichern

## 📝 Lizenz

MIT License - siehe LICENSE-Datei für Details

## 🤝 Beitragen

1. Repository forken
2. Feature-Branch erstellen
3. Änderungen vornehmen
4. Pull Request einreichen

## 📞 Support

Für Probleme und Fragen:
1. Fehlerbehebungsabschnitt prüfen
2. Container-Logs überprüfen
3. Netzwerkverbindung verifizieren
4. GitHub Issues für ähnliche Probleme prüfen

---

**Perfekt für ISP-Reporting**: Diese Lösung bietet professionelle Netzwerküberwachung mit den Daten und Visualisierungen, die für qualifizierte Beschwerden bei Internetdienstanbietern über Verbindungsqualität und Leistungsprobleme benötigt werden.
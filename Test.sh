#!/bin/bash
# Systemdiagnose-Skript inkl. Fan-Test für Linux-PC/Server
# Dieses Skript installiert zunächst die benötigten Tools,
# führt eine Diagnose (Hardware, Software, Netzwerk etc.) durch und
# testet abschließend die Lüfter, indem es versucht, sie für 10 Sekunden
# auf 100% (Wert 255) zu stellen und anschließend die automatische Steuerung wiederherzustellen.
#
# Achtung: Das Skript MUSS als Root ausgeführt werden!

LOGFILE="/var/log/system_diagnose.log"

# Prüfen, ob Root-Rechte vorhanden sind
if [ "$EUID" -ne 0 ]; then
  echo "Bitte führen Sie dieses Skript mit Root-Rechten aus." >&2
  exit 1
fi

echo "----------------------------------"
echo "Paketmanager-Erkennung und Installation benötigter Tools..."

# Ermittlung des Paketmanagers und Installation der Tools
if command -v apt-get >/dev/null 2>&1; then
    PKG_MANAGER="apt-get"
    echo "apt-get gefunden. Aktualisiere Paketquellen..."
    apt-get update -qq
    echo "Installiere lsb-release, smartmontools und lm-sensors..."
    apt-get install -y lsb-release smartmontools lm-sensors
elif command -v yum >/dev/null 2>&1; then
    PKG_MANAGER="yum"
    echo "yum gefunden. Aktualisiere Paketquellen..."
    yum check-update -q
    echo "Installiere redhat-lsb, smartmontools und lm_sensors..."
    yum install -y redhat-lsb smartmontools lm_sensors
elif command -v dnf >/dev/null 2>&1; then
    PKG_MANAGER="dnf"
    echo "dnf gefunden. Aktualisiere Paketquellen..."
    dnf check-update -q
    echo "Installiere redhat-lsb, smartmontools und lm_sensors..."
    dnf install -y redhat-lsb smartmontools lm_sensors
else
    echo "Kein unterstützter Paketmanager gefunden (apt-get, yum, dnf). Skript wird beendet."
    exit 1
fi

echo "Alle benötigten Tools wurden installiert."
echo "----------------------------------"
echo ""

# Start der Systemdiagnose (Ausgabe auch in $LOGFILE)
echo "Systemdiagnose gestartet: $(date)" | tee "$LOGFILE"
echo "----------------------------------" | tee -a "$LOGFILE"

# 1. Systeminformationen
echo "=== Systeminformationen ===" | tee -a "$LOGFILE"
uname -a | tee -a "$LOGFILE"
if command -v lsb_release &>/dev/null; then
  lsb_release -a 2>/dev/null | tee -a "$LOGFILE"
fi
echo "----------------------------------" | tee -a "$LOGFILE"

# 2. CPU-Informationen
echo "=== CPU-Informationen ===" | tee -a "$LOGFILE"
lscpu | tee -a "$LOGFILE"
echo "----------------------------------" | tee -a "$LOGFILE"

# 3. Speicherinformationen
echo "=== Speicherinformationen ===" | tee -a "$LOGFILE"
free -h | tee -a "$LOGFILE"
echo "----------------------------------" | tee -a "$LOGFILE"

# 4. Festplatteninformationen und SMART-Status (falls verfügbar)
echo "=== Festplatteninformationen ===" | tee -a "$LOGFILE"
df -h | tee -a "$LOGFILE"
if command -v smartctl &>/dev/null; then
  echo "SMART Status der Festplatten:" | tee -a "$LOGFILE"
  # Annahme: Festplattenbezeichnungen beginnen mit /dev/sd?
  for disk in /dev/sd?; do
    if [ -e "$disk" ]; then
      echo "Prüfe $disk:" | tee -a "$LOGFILE"
      smartctl -H "$disk" | tee -a "$LOGFILE"
    fi
  done
fi
echo "----------------------------------" | tee -a "$LOGFILE"

# 5. Temperatur- und Lüfterstatus (falls lm-sensors verfügbar)
if command -v sensors &>/dev/null; then
  echo "=== Temperatur und Lüfterstatus ===" | tee -a "$LOGFILE"
  sensors | tee -a "$LOGFILE"
  echo "----------------------------------" | tee -a "$LOGFILE"
fi

# 6. Netzwerkinformationen
echo "=== Netzwerkinformationen ===" | tee -a "$LOGFILE"
ip a | tee -a "$LOGFILE"
echo "----------------------------------" | tee -a "$LOGFILE"

# 7. Installierte Pakete
echo "=== Installierte Pakete ===" | tee -a "$LOGFILE"
if command -v dpkg &>/dev/null; then
  dpkg -l | tee -a "$LOGFILE"
elif command -v rpm &>/dev/null; then
  rpm -qa | tee -a "$LOGFILE"
else
  echo "Paketmanager nicht erkannt." | tee -a "$LOGFILE"
fi
echo "----------------------------------" | tee -a "$LOGFILE"

# 8. Verfügbare Sicherheitsupdates (nur für apt-get-basierte Systeme)
if [ "$PKG_MANAGER" = "apt-get" ]; then
  echo "=== Verfügbare Sicherheitsupdates ===" | tee -a "$LOGFILE"
  apt-get update -qq
  apt-get -s upgrade | grep "^Inst" | grep -i security | tee -a "$LOGFILE"
  echo "----------------------------------" | tee -a "$LOGFILE"
fi

# 9. Systemlast und aktuelle Prozesse
echo "=== Systemlast und Prozesse ===" | tee -a "$LOGFILE"
uptime | tee -a "$LOGFILE"
echo "Top 20 Prozesse:" | tee -a "$LOGFILE"
top -b -n 1 | head -n 20 | tee -a "$LOGFILE"
echo "----------------------------------" | tee -a "$LOGFILE"

# 10. Fan-Test: Lüfter auf maximale Drehzahl setzen
echo "----------------------------------"
echo "Starte Lüftertest: Versuche, alle erkannten Lüfter manuell auf 100% (Wert 255) zu setzen..."
# Hinweis: Dieser Schritt greift in die Hardwaresteuerung ein und funktioniert
# nur, wenn dein System bzw. der entsprechende Sensor die manuelle Steuerung über Sysfs unterstützt.
for hwmon in /sys/class/hwmon/hwmon*; do
    # Durchsuche alle pwm-Dateien im jeweiligen hwmon-Verzeichnis
    for pwm_file in "$hwmon"/pwm*; do
       if [ -f "$pwm_file" ]; then
         pwm_base=$(basename "$pwm_file")
         enable_file="$hwmon/${pwm_base}_enable"
         # Falls eine Enable-Datei vorhanden ist, auf manuellen Modus setzen (Wert 1)
         if [ -f "$enable_file" ]; then
             echo "Aktiviere manuelle Steuerung für $pwm_file"
             echo 1 > "$enable_file"
         fi
         echo "Setze $pwm_file auf maximale Drehzahl (255)"
         echo 255 > "$pwm_file"
       fi
    done
done

echo "Alle erkannten Lüfter laufen nun 10 Sekunden lang mit voller Leistung..."
sleep 10

echo "Restoriere automatische Lüftersteuerung..."
for hwmon in /sys/class/hwmon/hwmon*; do
    for pwm_file in "$hwmon"/pwm*; do
       if [ -f "$pwm_file" ]; then
         pwm_base=$(basename "$pwm_file")
         enable_file="$hwmon/${pwm_base}_enable"
         if [ -f "$enable_file" ]; then
             echo "Setze $enable_file auf automatische Steuerung (0)"
             echo 0 > "$enable_file"
         fi
       fi
    done
done
echo "Lüftertest abgeschlossen."
echo "----------------------------------"

echo "Systemdiagnose abgeschlossen: $(date)" | tee -a "$LOGFILE"

#!/bin/bash
# Dieses Skript listet alle installierten Pakete inkl. ihrer Größe (in GB) auf, sortiert sie nach Größe absteigend 
# und speichert das Ergebnis in einer Log-Datei im Verzeichnis /home/${USER}/.Packet-Logs/.
# Die Log-Datei wird benannt als {Datum}-{Uhrzeit}-{Anzahl der Pakete}-{Ausführungszähler}.log

# Zielverzeichnis festlegen und erstellen, falls nicht vorhanden
LOG_DIR="/home/${USER}/.Packet-Logs"
mkdir -p "$LOG_DIR"

# Ausführungszähler verwalten: Zähler wird in einer versteckten Datei im Log-Verzeichnis gespeichert
COUNTER_FILE="${LOG_DIR}/.run_counter"
if [ -f "$COUNTER_FILE" ]; then
    run_count=$(cat "$COUNTER_FILE")
    run_count=$((run_count + 1))
else
    run_count=1
fi
echo "$run_count" > "$COUNTER_FILE"

# Datum und Uhrzeit erfassen
datum=$(date +%Y-%m-%d)
uhrzeit=$(date +%H-%M-%S)

# Anzahl der installierten Pakete ermitteln
package_count=$(dpkg-query -W -f='${Package}\n' | wc -l)
package_count=$(echo "$package_count" | tr -d ' ')  # Entfernt etwaige Leerzeichen

# Dateinamen gemäß Vorgabe zusammenstellen
filename="${LOG_DIR}/${datum}-${uhrzeit}-${package_count}-${run_count}.log"

# Ausgabe in die Log-Datei schreiben
{
    printf "%-40s %12s\n" "Paket" "Größe (GB)"
    printf "%-40s %12s\n" "----------------------------------------" "------------"
    dpkg-query -W -f='${Installed-Size}\t${Package}\n' | \
    awk '{ sizeGB = $1 / (1024*1024); printf "%-40s %12.3f\n", $2, sizeGB }' | sort -k2 -nr
} > "$filename"

echo "Ergebnis wurde gespeichert in: $filename"

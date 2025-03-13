#!/bin/bash
# Dieses Skript überwacht kontinuierlich alle installierten Pakete inkl. ihrer Größe (in GB)
# und speichert das Ergebnis in einer Log-Datei, sobald sich etwas ändert.
# Die Log-Datei wird im Verzeichnis /home/<user>/.Packet-Logs/ abgelegt und wie folgt benannt:
# {Datum}-{Uhrzeit}-{Anzahl der Pakete}-{Ausführungszähler}-{ausführender Benutzer}.log

# Ermitteln des tatsächlichen Benutzers: Falls mit sudo ausgeführt, dann $SUDO_USER verwenden
if [ -n "$SUDO_USER" ]; then
    actual_user="$SUDO_USER"
else
    actual_user="$USER"
fi

# Zielverzeichnis festlegen und erstellen, falls nicht vorhanden
LOG_DIR="/home/${actual_user}/.Packet-Logs"
mkdir -p "$LOG_DIR"

# Ausführungszähler initialisieren: Zähler wird in einer versteckten Datei im Log-Verzeichnis gespeichert
COUNTER_FILE="${LOG_DIR}/.run_counter"
if [ -f "$COUNTER_FILE" ]; then
    run_count=$(cat "$COUNTER_FILE")
else
    run_count=0
fi

# Variable zur Speicherung des vorherigen Zustands
prev_hash=""

# Endlosschleife, die regelmäßig den Paketstatus überprüft
while true; do
    # Erfassen der Paketinformationen inkl. Größe in GB, sortiert nach Größe absteigend
    package_status=$(dpkg-query -W -f='${Installed-Size}\t${Package}\n' | \
        awk '{ sizeGB = $1 / (1024*1024); printf "%-40s %12.3f\n", $2, sizeGB }' | sort -k2 -nr)

    # Berechnen eines Hashwerts des aktuellen Paketstatus
    curr_hash=$(echo "$package_status" | md5sum | awk '{print $1}')

    # Wenn sich der Hash geändert hat, wurde eine Änderung festgestellt
    if [ "$curr_hash" != "$prev_hash" ]; then
        # Zähler erhöhen und speichern
        run_count=$((run_count + 1))
        echo "$run_count" > "$COUNTER_FILE"

        # Datum, Uhrzeit und Paketanzahl erfassen
        datum=$(date +%Y-%m-%d)
        uhrzeit=$(date +%H-%M-%S)
        package_count=$(dpkg-query -W -f='${Package}\n' | wc -l | tr -d ' ')

        # Log-Dateinamen zusammenstellen
        filename="${LOG_DIR}/${datum}-${uhrzeit}-${package_count}-${run_count}-${actual_user}.log"

        # Log-Datei erstellen
        {
            printf "%-40s %12s\n" "Paket" "Größe (GB)"
            printf "%-40s %12s\n" "----------------------------------------" "------------"
            echo "$package_status"
        } > "$filename"

        echo "Änderung festgestellt. Log-Datei erstellt: $filename"
        # Update des gespeicherten Hashwerts
        prev_hash="$curr_hash"
    fi

    # Warte 60 Sekunden, bevor erneut geprüft wird (anpassbar)
    sleep 60
done

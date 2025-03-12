#!/bin/bash
# Dieses Skript listet alle installierten Pakete zusammen mit ihrer Größe (in GB) auf und sortiert sie absteigend.
# Hinweis: dpkg-query liefert die Größe in Kilobytes (Installed-Size). Zur Umrechnung wird durch 1024*1024 geteilt.

# Ausgabe-Header
printf "%-40s %12s\n" "Paket" "Größe (GB)"
printf "%-40s %12s\n" "----------------------------------------" "------------"

# Pakete abrufen, Größe umrechnen und nach Größe sortieren
dpkg-query -W -f='${Installed-Size}\t${Package}\n' | \
awk '{ sizeGB = $1 / (1024*1024); printf "%-40s %12.3f\n", $2, sizeGB }' | sort -k2 -nr

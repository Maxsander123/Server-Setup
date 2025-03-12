#!/bin/bash
# Dieses Skript sucht im Verzeichnis /home/<user>/.Packet-Logs/ nach Log-Dateien,
# lässt den Benutzer zwei Dateien auswählen und zeigt dann die Unterschiede zwischen diesen Dateien an.

# Ermitteln des tatsächlichen Benutzers (auch bei sudo)
if [ -n "$SUDO_USER" ]; then
    actual_user="$SUDO_USER"
else
    actual_user="$USER"
fi

# Log-Verzeichnis festlegen
LOG_DIR="/home/${actual_user}/.Packet-Logs"

# Überprüfen, ob das Log-Verzeichnis existiert
if [ ! -d "$LOG_DIR" ]; then
    echo "Das Verzeichnis $LOG_DIR existiert nicht."
    exit 1
fi

# Alle .log Dateien im Verzeichnis sammeln
files=("$LOG_DIR"/*.log)
if [ ${#files[@]} -eq 0 ]; then
    echo "Keine Log-Dateien im Verzeichnis $LOG_DIR gefunden."
    exit 1
fi

echo "Verfügbare Log-Dateien:"
index=1
for file in "${files[@]}"; do
    echo "$index) $(basename "$file")"
    index=$((index + 1))
done

# Benutzer wählt die erste Datei
echo -n "Wähle die Nummer der ersten Datei: "
read first_choice

# Benutzer wählt die zweite Datei
echo -n "Wähle die Nummer der zweiten Datei: "
read second_choice

# Eingabe validieren
if ! [[ "$first_choice" =~ ^[0-9]+$ ]] || ! [[ "$second_choice" =~ ^[0-9]+$ ]]; then
    echo "Ungültige Eingabe. Bitte Zahlen eingeben."
    exit 1
fi

if [ "$first_choice" -lt 1 ] || [ "$first_choice" -gt "${#files[@]}" ] || [ "$second_choice" -lt 1 ] || [ "$second_choice" -gt "${#files[@]}" ]; then
    echo "Auswahl außerhalb des gültigen Bereichs."
    exit 1
fi

file1="${files[$((first_choice-1))]}"
file2="${files[$((second_choice-1))]}"

echo ""
echo "Vergleiche $(basename "$file1") mit $(basename "$file2"):"
echo "----------------------------------------"
# Unterschiede anzeigen (unified diff Format)
diff -u "$file1" "$file2"

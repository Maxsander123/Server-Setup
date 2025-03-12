#!/bin/bash
# Skript: Execute.sh

# Eigener Dateiname ermitteln
script_name=$(basename "$0")

# Alle Bash-Dateien (*.sh) im aktuellen Ordner, außer der eigenen Datei, sammeln
sh_files=()
for file in *.sh; do
    if [[ "$file" != "$script_name" ]]; then
        sh_files+=("$file")
    fi
done

# Falls keine passenden Bash-Dateien gefunden werden, Skript beenden.
if [ ${#sh_files[@]} -eq 0 ]; then
    echo "Keine Bash-Dateien (außer '$script_name') im aktuellen Ordner gefunden."
    exit 1
fi

# Alle gefundenen Dateien ausführbar machen
for file in "${sh_files[@]}"; do
    chmod +x "$file"
    echo "Datei '$file' wurde ausführbar gemacht."
done

echo ""

# Benutzerabfrage: Für jede Datei wird gefragt, ob sie ausgeführt werden soll.
declare -a execute_files
for file in "${sh_files[@]}"; do
    read -p "Möchten Sie '$file' ausführen? (j/n): " choice
    if [[ "$choice" =~ ^[jJ]$ ]]; then
        execute_files+=("$file")
    fi
done

echo ""

# Ausführung der ausgewählten Dateien
if [ ${#execute_files[@]} -eq 0 ]; then
    echo "Keine Dateien wurden zur Ausführung ausgewählt."
else
    echo "Ausgewählte Dateien werden jetzt ausgeführt:"
    for file in "${execute_files[@]}"; do
        echo "Führe '$file' aus..."
        ./"$file"
    done
fi

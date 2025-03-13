#!/bin/bash
# Skript: Execute.sh
# Beschreibung:
#   Dieses Skript sucht im aktuellen Ordner nach allen Bash-Skripten (außer sich selbst),
#   macht diese ausführbar und zeigt dann einen full-screen, dialog-basierten 
#   Auswahlbildschirm (im MC-Stil) zur Auswahl der Skripte, die ausgeführt werden sollen.
#
# Hinweis:
#   Die grafische Oberfläche basiert auf "dialog". Falls "dialog" nicht installiert ist,
#   fragt das Skript, ob es installiert werden soll. Unterstützte Paketmanager sind apt-get und yum.

# Prüfen, ob dialog installiert ist; falls nicht, Benutzer fragen, ob installiert werden soll.
if ! command -v dialog >/dev/null 2>&1; then
    echo "Das Programm 'dialog' ist nicht installiert."
    read -p "Möchten Sie 'dialog' jetzt installieren? (j/n): " install_choice
    if [[ "$install_choice" =~ ^[jJ]$ ]]; then
        if command -v apt-get >/dev/null 2>&1; then
            sudo apt-get update && sudo apt-get install -y dialog
        elif command -v yum >/dev/null 2>&1; then
            sudo yum install -y dialog
        else
            echo "Kein unterstützter Paketmanager gefunden. Bitte installieren Sie 'dialog' manuell."
            exit 1
        fi
        # Überprüfen, ob dialog nun verfügbar ist.
        if ! command -v dialog >/dev/null 2>&1; then
            echo "Installation fehlgeschlagen. Bitte installieren Sie 'dialog' manuell und starten Sie das Skript erneut."
            exit 1
        fi
    else
        echo "Bitte installieren Sie 'dialog' und starten Sie das Skript erneut."
        exit 1
    fi
fi

# Eigener Dateiname ermitteln.
script_name=$(basename "$0")

# Alle Bash-Dateien (*.sh) im aktuellen Ordner, außer dieser Datei, sammeln.
sh_files=()
for file in *.sh; do
    if [[ "$file" != "$script_name" ]]; then
        sh_files+=("$file")
    fi
done

# Falls keine passenden Bash-Dateien gefunden werden, beenden.
if [ ${#sh_files[@]} -eq 0 ]; then
    dialog --msgbox "Keine Bash-Dateien (außer '$script_name') im aktuellen Ordner gefunden." 10 50
    clear
    exit 1
fi

# Alle gefundenen Dateien ausführbar machen.
for file in "${sh_files[@]}"; do
    chmod +x "$file"
done

# Die Checkliste für dialog vorbereiten. Neben dem Dateinamen wird zusätzlich die Dateigröße angezeigt.
checklist_items=()
for file in "${sh_files[@]}"; do
    filesize=$(stat -c%s "$file")
    checklist_items+=("$file" "Größe: ${filesize} bytes" "off")
done

# Temporäre Datei zur Speicherung der Benutzerwahl erstellen.
tempfile=$(mktemp 2>/dev/null) || tempfile=/tmp/test$$

# Anzeige der Full-Screen Checkliste im MC-Stil.
dialog --backtitle "Midnight Commander Style Script Executor" \
       --title "Skript-Auswahl" \
       --checklist "Verwenden Sie die Pfeiltasten, um zu navigieren und die Leertaste zum Auswählen. Drücken Sie ENTER, um fortzufahren." \
       20 70 10 "${checklist_items[@]}" 2> "$tempfile"

# Überprüfen, ob der Benutzer abgebrochen hat.
if [ $? -ne 0 ]; then
    dialog --msgbox "Abgebrochen." 10 30
    rm -f "$tempfile"
    clear
    exit 1
fi

# Ausgewählte Skripte aus der temporären Datei auslesen.
selected=$(cat "$tempfile")
rm -f "$tempfile"

if [ -z "$selected" ]; then
    dialog --msgbox "Keine Dateien wurden zur Ausführung ausgewählt." 10 50
    clear
    exit 1
fi

# Entfernen der doppelten Anführungszeichen und Umwandeln in ein Array.
selected=$(echo $selected | sed 's/"//g')
IFS=' ' read -r -a execute_files <<< "$selected"

# Bestätigung der Auswahl mittels einer Info-Box im MC-Stil.
dialog --backtitle "Midnight Commander Style Script Executor" \
       --title "Ausgewählte Skripte" \
       --msgbox "Folgende Skripte werden ausgeführt:\n\n${selected// /\\n}" 15 60

# Dialog-Oberfläche löschen.
clear

# Ausführung der ausgewählten Skripte.
for file in "${execute_files[@]}"; do
    echo "Führe '$file' aus..."
    ./"$file"
    echo "Drücken Sie eine beliebige Taste, um fortzufahren..."
    read -n 1 -s
done

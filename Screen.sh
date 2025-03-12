#!/bin/bash
# Dieses Skript installiert 'screen', falls nicht vorhanden, und bietet ein Menü
# zur Verwaltung von Screen-Sessions in einer Proxmox VNC Umgebung.
#
# In jeder Screen-Session soll der Alias "Exscreen" gesetzt werden, der den Befehl
# "screen -X detach" ausführt, um die Session zu verlassen und zum Skript zurückzukehren.
#
# Achtung: Das Einfügen des Aliases in bereits laufende Sessions erfolgt per "stuff".
# Dies funktioniert nur, wenn die Shell tatsächlich Eingaben entgegennimmt.

# Root-Rechte prüfen
if [[ $EUID -ne 0 ]]; then
    echo "Bitte führen Sie dieses Skript als root aus."
    exit 1
fi

# Installation von screen prüfen
if ! command -v screen &>/dev/null; then
    echo "Screen wurde nicht gefunden. Installation wird gestartet..."
    apt-get update && apt-get install -y screen
    if [ $? -ne 0 ]; then
        echo "Fehler bei der Installation von screen."
        exit 1
    fi
fi

# Funktion, um in einer bestehenden Session den Alias zu setzen
set_exscreen_alias() {
    local session_id="$1"
    # Sende den Alias-Befehl gefolgt von einem Carriage Return
    screen -S "$session_id" -X stuff "alias Exscreen='screen -X detach'\r"
}

while true; do
    echo "--------------------------------------------"
    echo "Screen-Helfer für Proxmox VNC"
    echo "--------------------------------------------"
    echo "1) Neue Screen-Session starten"
    echo "2) Aktuelle Screen-Sessions auflisten"
    echo "3) An eine bestehende Screen-Session anhängen"
    echo "4) Eine Screen-Session beenden"
    echo "5) Skript beenden"
    echo "--------------------------------------------"
    read -p "Bitte wählen Sie eine Option (1-5): " option

    case $option in
        1)
            read -p "Name der neuen Session: " session_name
            echo "Starte neue Screen-Session: $session_name"
            # Erstelle eine temporäre RC-Datei, die den Exscreen-Alias enthält
            tmp_rc=$(mktemp)
            echo "alias Exscreen='screen -X detach'" > "$tmp_rc"
            # Starte eine neue bash-Shell mit diesem RC-File innerhalb der neuen Screen-Session
            screen -S "$session_name" bash --rcfile "$tmp_rc"
            rm "$tmp_rc"
            ;;
        2)
            echo "Aktuelle Screen-Sessions:"
            screen -ls
            ;;
        3)
            echo "Aktuelle Screen-Sessions:"
            screen -ls
            read -p "Geben Sie den Namen oder die ID der Session ein, an die Sie anhängen möchten: " session_id
            # Versuche, den Alias in der bestehenden Session zu setzen
            set_exscreen_alias "$session_id"
            screen -r "$session_id"
            ;;
        4)
            echo "Aktuelle Screen-Sessions:"
            screen -ls
            read -p "Geben Sie den Namen oder die ID der Session ein, die Sie beenden möchten: " session_id
            screen -S "$session_id" -X quit
            echo "Session $session_id wurde beendet."
            ;;
        5)
            echo "Skript wird beendet."
            exit 0
            ;;
        *)
            echo "Ungültige Option. Bitte wählen Sie zwischen 1 und 5."
            ;;
    esac
done

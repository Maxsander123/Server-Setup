#!/bin/bash
# Pfad zur Konfigurationsdatei
CONFIG_FILE="$HOME/.monitor_config"

# Setup-Funktion: Erfragt per dialog die Email(s) und den zu überwachenden Ordner
setup() {
    # E-Mail-Adressen abfragen (getrennt durch Komma)
    EMAILS=$(dialog --title "Setup: Email-Adressen" \
                    --inputbox "Bitte geben Sie die Ziel-Email-Adressen ein (getrennt durch Komma):" \
                    8 60 3>&1 1>&2 2>&3 3>&-)
    retval=$?
    if [ $retval -ne 0 ]; then
        clear
        echo "Setup abgebrochen."
        exit 1
    fi

    # Ordner auswählen mittels Dialog (dselect)
    MONITOR_DIR=$(dialog --title "Setup: Überwachungsordner" \
                         --dselect "$HOME/" 14 60 3>&1 1>&2 2>&3 3>&-)
    retval=$?
    if [ $retval -ne 0 ]; then
        clear
        echo "Setup abgebrochen."
        exit 1
    fi

    # Konfiguration speichern
    {
      echo "EMAILS=\"$EMAILS\""
      echo "MONITOR_DIR=\"$MONITOR_DIR\""
    } > "$CONFIG_FILE"

    clear
    echo "Konfiguration gespeichert in $CONFIG_FILE"
}

# Funktion zur Überwachung des definierten Ordners und Versand der Email bei Änderungen
monitor_changes() {
    # Prüfen, ob Konfigurationsdatei existiert
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Konfigurationsdatei nicht gefunden. Führen Sie zuerst das Setup (--setup) aus."
        exit 1
    fi

    # Konfiguration laden
    source "$CONFIG_FILE"

    echo "Überwache Änderungen in: $MONITOR_DIR"
    echo "Ziel-Email(s): $EMAILS"

    # Endlosschleife zur Überwachung
    while true; do
        # Warten auf eine Änderung (modify, create, delete, move) rekursiv im Ordner
        EVENT=$(inotifywait -r -e modify,create,delete,move "$MONITOR_DIR")
        if [ $? -eq 0 ]; then
            SUBJECT="Änderung in $MONITOR_DIR festgestellt"
            BODY="Folgende Änderung wurde festgestellt: $EVENT"
            # Mehrere Email-Adressen abarbeiten
            IFS=',' read -ra ADDR <<< "$EMAILS"
            for email in "${ADDR[@]}"; do
                echo "$BODY" | mail -s "$SUBJECT" "$email"
            done
            echo "Benachrichtigung an $EMAILS gesendet."
        fi
    done
}

# Hauptprogramm: Setup oder Monitoring starten
if [ "$1" == "--setup" ]; then
    setup
else
    monitor_changes
fi

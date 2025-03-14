#!/bin/bash
# Simulation eines Ubuntu-Server-Updateprozesses (nur Anzeige, keine echten Updates)
# Das Skript läuft unendlich, bis STRG+C gedrückt wird.
# Mehrere Funktionen sorgen für Animationen und eine längere Darstellung.

# Funktion: Spinner-Animation (dreht solange, bis der übergebene Prozess endet)
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while kill -0 "$pid" 2>/dev/null; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep "$delay"
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Funktion: Simuliere eine Aktion mit Spinner, um einen Fortschritt zu demonstrieren
simulate_action() {
    local action_message=$1
    local duration=$2
    echo -n "$action_message"
    ( sleep "$duration" ) &
    spinner $!
    echo " Fertig."
}

# Funktion: Fortschrittsbalken, der für eine bestimmte Dauer läuft
progress_bar() {
    local duration=$1
    local interval=0.2
    local steps=$(echo "$duration / $interval" | bc)
    echo -n "["
    for ((i=0; i<=steps; i++)); do
        sleep "$interval"
        echo -n "#"
    done
    echo "]"
}

# Funktion: Update-Simulation mit mehreren Schritten und Animationen
simulate_update() {
    echo "------------------------------------------"
    echo " Starte Update-Simulation für Ubuntu Server"
    echo "------------------------------------------"
    
    simulate_action "Aktualisiere Paketquellen...      " 2
    simulate_action "Hole Paketlisten...             " 2
    simulate_action "Erstelle Abhängigkeitsbaum...     " 2
    simulate_action "Lese Statusinformationen...     " 2
    simulate_action "Überprüfe installierte Pakete...  " 2
    simulate_action "Simuliere Sicherheitsupdates...   " 2

    echo "Berechne neue Paketversionen:"
    progress_bar 4

    echo "Prüfe Systemintegrität:"
    progress_bar 3

    echo "Überprüfe Konfigurationsdateien:"
    simulate_action "Vergleiche Konfigurationen...    " 2

    echo "Alle Pakete sind aktuell."
    echo "Update-Simulation abgeschlossen."
}

# Signal Trap, um das Skript bei STRG+C zu beenden
trap "echo -e '\nSimulation beendet.'; exit 0" SIGINT

# Endlosschleife, die die Update-Simulation wiederholt
while true; do
    clear
    simulate_update
    echo ""
    echo "Nächster Durchlauf in 10 Sekunden. Drücke STRG+C zum Beenden."
    sleep 10
done

#!/bin/bash
set -e  # Skript bei Fehlern abbrechen

# 1. Python Virtual Environment erstellen und aktivieren
echo "Erstelle Python-venv..."
python3 -m venv venv
source venv/bin/activate

# Pip aktualisieren und open-webui installieren
echo "Aktualisiere pip und installiere open-webui..."
pip install --upgrade pip
pip install open-webui

# 2. Ollama installieren
echo "Installiere Ollama..."
curl -fsSL https://ollama.com/install.sh | sh

# 3. Llama2 über Ollama starten (im Hintergrund)
echo "Starte Ollama mit llama2:13b..."
ollama run llama2:13b &
OLLAMA_PID=$!

# Kurze Pause, um Ollama Zeit zum Starten zu geben
echo "Warte auf die Initialisierung von Ollama..."
sleep 10

# 4. Open-WebUI starten (im venv)
echo "Starte open-webui..."
open-webui serve &
OPENWEBUI_PID=$!

# Kurze Pause, um open-webui hochfahren zu lassen
echo "Warte auf die Initialisierung von open-webui..."
sleep 5

# 5. Browser öffnen (Linux: xdg-open, macOS: open)
URL="http://127.0.0.1:5000"
if command -v xdg-open >/dev/null 2>&1; then
    echo "Öffne Browser mit $URL ..."
    xdg-open "$URL"
elif command -v open >/dev/null 2>&1; then
    echo "Öffne Browser mit $URL ..."
    open "$URL"
else
    echo "Bitte öffne manuell deinen Browser und gehe zu: $URL"
fi

# Optional: Warte, bis die gestarteten Prozesse beendet werden
wait $OPENWEBUI_PID
wait $OLLAMA_PID

#!/bin/bash
# This script installs and configures UFW using a dialog-based GUI.
# It lists detected listening ports, allows you to choose which of them to allow,
# provides a checklist for standard ports (SSH, HTTP, HTTPS) so you can choose those,
# and lets you add custom ports as well.
# Finally, it sets UFW default policies and enables the firewall.

# Ensure the script is run as root.
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script with sudo or as root."
    exit 1
fi

# Check if UFW is installed; if not, install it.
if ! command -v ufw &> /dev/null; then
    echo "UFW not found. Installing UFW..."
    apt-get update && apt-get install -y ufw
fi

# Check if netstat is available (from net-tools). If not, install net-tools.
if ! command -v netstat &> /dev/null; then
    echo "netstat command not found. Installing net-tools..."
    apt-get update && apt-get install -y net-tools
fi

# Check if dialog is installed; if not, install it.
if ! command -v dialog &> /dev/null; then
    echo "dialog not found. Installing dialog..."
    apt-get update && apt-get install -y dialog
fi

# Present a checklist for standard ports.
standard_ports=$(dialog --title "Standard Ports" --checklist "Select standard ports to allow:" 10 60 3 \
    "SSH" "Secure Shell (22/tcp)" off \
    "HTTP" "HTTP (80/tcp)" off \
    "HTTPS" "HTTPS (443/tcp)" off \
    3>&1 1>&2 2>&3 3>&-)

# Process standard ports selection.
for port in $standard_ports; do
    # Remove surrounding quotes.
    port=$(echo $port | tr -d '"')
    case "$port" in
        SSH)
            ufw allow ssh
            ;;
        HTTP)
            ufw allow http
            ;;
        HTTPS)
            ufw allow https
            ;;
    esac
done

# Detect listening ports along with protocol and service names.
LISTENING_SERVICES=$(netstat -tulnp | awk 'NR>2 {
    proto = $1;
    split($4, addr, ":");
    port = addr[length(addr)];
    service = "Unknown";
    if ($7 != "" && $7 != "-") {
        split($7, proc, "/");
        if (length(proc) > 1) {
            service = proc[2];
        }
    }
    if (port ~ /^[0-9]+$/) {
        print port, proto, service;
    }
}' | sort -n | uniq)

# Prepare checklist items for detected listening ports.
declare -a checklist_items
while read -r port proto service; do
    # Use "port/protocol" as the tag (e.g., "80/tcp").
    tag="${port}/${proto}"
    checklist_items+=("$tag" "Service: $service" "off")
done <<< "$LISTENING_SERVICES"

# If detected listening ports exist, allow selection.
if [ ${#checklist_items[@]} -gt 0 ]; then
    selected_detected=$(dialog --title "Detected Listening Ports" --checklist "Select detected ports to allow incoming traffic:" 15 60 8 "${checklist_items[@]}" 3>&1 1>&2 2>&3 3>&-)
    
    for entry in $selected_detected; do
        # Remove surrounding quotes.
        entry=$(echo $entry | tr -d '"')
        ufw allow "$entry"
    done
else
    dialog --title "No Detected Ports" --msgbox "No listening ports detected." 6 40
fi

# Prompt the user to add custom ports.
dialog --title "Custom Ports" --yesno "Would you like to add custom port(s)?" 7 50
custom_response=$?
if [ $custom_response -eq 0 ]; then
    while true; do
        custom_entry=$(dialog --title "Add Custom Port" --inputbox "Enter custom port in the format port/protocol (e.g., 8080/tcp):" 8 60 3>&1 1>&2 2>&3 3>&-)
        ret_code=$?
        if [ $ret_code -ne 0 ] || [ -z "$custom_entry" ]; then
            break
        fi

        # Optionally, prompt for a description (not used further).
        custom_desc=$(dialog --title "Custom Port Description" --inputbox "Enter a description for $custom_entry (optional):" 8 60 3>&1 1>&2 2>&3 3>&-)
        
        ufw allow "$custom_entry"
        
        dialog --title "Add Another?" --yesno "Do you want to add another custom port?" 7 50
        another_response=$?
        if [ $another_response -ne 0 ]; then
            break
        fi
    done
fi

# Set UFW default policies.
dialog --infobox "Setting default UFW policies..." 4 40
ufw default deny incoming
ufw default allow outgoing
sleep 2

# Enable UFW.
dialog --infobox "Enabling UFW..." 4 40
ufw --force enable
sleep 2

# Inform the user that configuration is complete.
dialog --title "UFW Configuration" --msgbox "UFW configuration completed." 6 40

# Clear the screen after closing dialog boxes.
clear

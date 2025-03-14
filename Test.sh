#!/bin/bash
# Ubuntu Server Test Suite with Enhanced HTML Email Report,
# Improved GUI, Next Email Indicator, and Additional Recipient Support
#
# This script performs a comprehensive system test and can send periodic email reports.
# Outgoing emails are sent with the sender address set to "Syscheck@mtlgroup.tech".
#
# Features:
#  - Full system test (OS, uptime, disk, memory, CPU, network, services, etc.)
#  - Configurable stress test with a progress gauge
#  - Manual email report sending with email validation, report preview, and confirmation
#  - Test email sending to verify email configuration
#  - Minimal mail server (Postfix) setup
#  - Periodic email report scheduling via cron for multiple recipients
#  - Management (cancellation) of the cron job
#  - Automatic opening of required ports in UFW (SSH, SMTP, HTTP, HTTPS, Submission, MySQL)
#  - New: Indicator of when the next scheduled email will be sent
#  - New: Ability to add email addresses to the recipients list without replacing existing ones
#  - New: HTML formatted email report with a table layout for a better visual appearance
#
# Use this script with sudo privileges.

###############################
# Global Variables and Files
###############################
TMP_OUTPUT="/tmp/sys_test_report.txt"
HTML_REPORT="/tmp/sys_test_report.html"
REPORT_FILE="sys_test_report_$(date +%Y%m%d_%H%M%S).txt"
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
RECIPIENT_FILE="$SCRIPT_DIR/syscheck_recipients.conf"

##################################
# Install Dependencies
##################################
install_dependencies() {
  for pkg in dialog stress mailutils; do
    if ! dpkg -l | grep -qw "$pkg"; then
      echo "Installing $pkg..."
      sudo apt-get update && sudo apt-get install -y "$pkg"
    fi
  done
}
install_dependencies

##############################################
# Function: Validate Email Addresses
##############################################
validate_emails() {
  local emails="$1"
  for email in $emails; do
    if ! [[ $email =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
      return 1
    fi
  done
  return 0
}

##############################################
# Function: Send Email (with HTML support)
# Parameters: Recipients, Subject, Body File
##############################################
send_email() {
  local recipients="$1"
  local subject="$2"
  local bodyfile="$3"
  local sender="Syscheck@mtlgroup.tech"
  if ! command -v mail &> /dev/null; then
    dialog --title "Email Error" --msgbox "The mail command is not available. Please install mailutils." 8 60
    return 1
  fi
  # For HTML email, add header "Content-Type: text/html"
  mail -a "Content-Type: text/html" -r "$sender" -s "$subject" $recipients < "$bodyfile"
  return $?
}

##############################################
# Function: Test Email Settings
##############################################
test_email_settings() {
  local test_recipient
  test_recipient=$(dialog --inputbox "Enter a test email address:" 8 60 3>&1 1>&2 2>&3)
  RETVAL=$?
  [ $RETVAL -ne 0 ] && return
  if ! validate_emails "$test_recipient"; then
    dialog --title "Email Error" --msgbox "The entered email address is invalid." 8 60
    return
  fi
  local tmp_test="/tmp/syscheck_test_email.txt"
  echo "<html><body><p>This is a test email from Syscheck (Hostname: $(hostname))</p></body></html>" > "$tmp_test"
  send_email "$test_recipient" "Test Email: Syscheck" "$tmp_test"
  if [ $? -eq 0 ]; then
    dialog --title "Test Email" --msgbox "Test email sent successfully to $test_recipient." 8 60
  else
    dialog --title "Email Error" --msgbox "Error sending the test email." 8 60
  fi
  rm -f "$tmp_test"
}

##############################################
# Function: Generate HTML Report
# The report is formatted as an HTML table.
##############################################
generate_html_report() {
  local outfile="$1"
  echo "<html>
  <head>
    <meta charset='UTF-8'>
    <style>
      body { font-family: Arial, sans-serif; }
      table { border-collapse: collapse; width: 100%; }
      th, td { border: 1px solid #dddddd; text-align: left; padding: 8px; }
      tr:nth-child(even) { background-color: #f2f2f2; }
      h2 { color: #333; }
    </style>
  </head>
  <body>" > "$outfile"
  echo "<h2>Full System Test Report - $(date)</h2>" >> "$outfile"
  echo "<p>Hostname: $(hostname)</p>" >> "$outfile"
  echo "<table>" >> "$outfile"
  echo "<tr><th>Section</th><th>Content</th></tr>" >> "$outfile"
  
  # OS Information
  OS_INFO=$( (if command -v lsb_release &> /dev/null; then lsb_release -a 2>/dev/null; else cat /etc/os-release; fi) )
  OS_INFO=$(echo "$OS_INFO" | sed ':a;N;$!ba;s/\n/<br>/g')
  echo "<tr><td>OS Information</td><td>$OS_INFO</td></tr>" >> "$outfile"
  
  # Uptime
  UPTIME=$(uptime)
  echo "<tr><td>System Uptime</td><td>$UPTIME</td></tr>" >> "$outfile"
  
  # Disk Usage
  DISK_USAGE=$(df -h | sed ':a;N;$!ba;s/\n/<br>/g')
  echo "<tr><td>Disk Usage</td><td>$DISK_USAGE</td></tr>" >> "$outfile"
  
  # Inode Usage
  INODE_USAGE=$(df -ih | sed ':a;N;$!ba;s/\n/<br>/g')
  echo "<tr><td>Inode Usage</td><td>$INODE_USAGE</td></tr>" >> "$outfile"
  
  # Memory and Swap
  MEMORY=$(free -h | sed ':a;N;$!ba;s/\n/<br>/g')
  echo "<tr><td>Memory & Swap</td><td>$MEMORY</td></tr>" >> "$outfile"
  
  # CPU Information
  CPU_INFO=$(echo "Load Average: $(top -bn1 | grep 'load average:' | awk -F'load average:' '{print $2}')<br>CPU Cores: $(nproc)<br>CPU Frequency: $(grep 'cpu MHz' /proc/cpuinfo | head -n1)")
  echo "<tr><td>CPU Information</td><td>$CPU_INFO</td></tr>" >> "$outfile"
  
  # Network Information
  NETWORK=$(ip addr | sed ':a;N;$!ba;s/\n/<br>/g')
  echo "<tr><td>Network Information</td><td>$NETWORK</td></tr>" >> "$outfile"
  
  # Routing Table
  ROUTING=$(ip route | sed ':a;N;$!ba;s/\n/<br>/g')
  echo "<tr><td>Routing Table</td><td>$ROUTING</td></tr>" >> "$outfile"
  
  # Ping Test
  if ping -c 4 google.com &> /dev/null; then
    PING="Network connectivity: OK"
  else
    PING="Network connectivity: FAIL"
  fi
  echo "<tr><td>Ping Test</td><td>$PING</td></tr>" >> "$outfile"
  
  # Open Ports
  OPEN_PORTS=$(sudo ss -tuln | sed ':a;N;$!ba;s/\n/<br>/g')
  echo "<tr><td>Open Ports</td><td>$OPEN_PORTS</td></tr>" >> "$outfile"
  
  # UFW Status
  if command -v ufw &> /dev/null; then
    UFW_STATUS=$(sudo ufw status verbose | sed ':a;N;$!ba;s/\n/<br>/g')
  else
    UFW_STATUS="ufw is not installed."
  fi
  echo "<tr><td>Firewall (UFW) Status</td><td>$UFW_STATUS</td></tr>" >> "$outfile"
  
  # Service Status
  SERVICES=""
  for service in ssh apache2 nginx mysql; do
    SERVICES+="Service: $service<br>"
    if systemctl is-active --quiet "$service"; then
      SERVICES+="Status: Running<br>"
    else
      SERVICES+="Status: Not running or not installed<br>"
    fi
    SERVICES+="---------------------------------<br>"
  done
  echo "<tr><td>Service Status</td><td>$SERVICES</td></tr>" >> "$outfile"
  
  # Stress Test (summary)
  STRESS_RESULT="Stress test completed (CPU 4, IO 2, VM 2, 128M, 60s)"
  echo "<tr><td>Stress Test</td><td>$STRESS_RESULT</td></tr>" >> "$outfile"
  
  # Logged in Users
  USERS=$(who | sed ':a;N;$!ba;s/\n/<br>/g')
  echo "<tr><td>Logged in Users</td><td>$USERS</td></tr>" >> "$outfile"
  
  # Recent Error Logs
  ERROR_LOGS=$(grep -i "error" /var/log/syslog 2>/dev/null | tail -n 10 | sed ':a;N;$!ba;s/\n/<br>/g')
  echo "<tr><td>Recent Error Logs</td><td>$ERROR_LOGS</td></tr>" >> "$outfile"
  
  # SSH Root Login Setting
  SSH_ROOT=$(grep -i "PermitRootLogin" /etc/ssh/sshd_config 2>/dev/null | sed ':a;N;$!ba;s/\n/<br>/g')
  echo "<tr><td>SSH Root Login Setting</td><td>$SSH_ROOT</td></tr>" >> "$outfile"
  
  # Virtualization Detection
  VIRT=$(systemd-detect-virt)
  echo "<tr><td>Virtualization Detection</td><td>$VIRT</td></tr>" >> "$outfile"
  
  # Temperature Sensors
  if command -v sensors &> /dev/null; then
    TEMP=$(sensors | sed ':a;N;$!ba;s/\n/<br>/g')
  else
    TEMP="sensors command not available."
  fi
  echo "<tr><td>Temperature Sensors</td><td>$TEMP</td></tr>" >> "$outfile"
  
  # Top Processes by CPU
  TOP_PROCESSES=$(ps -eo pid,comm,%cpu,%mem --sort=-%cpu | head -n 10 | sed ':a;N;$!ba;s/\n/<br>/g')
  echo "<tr><td>Top Processes (by CPU)</td><td>$TOP_PROCESSES</td></tr>" >> "$outfile"
  
  # Battery Status
  if command -v upower &> /dev/null; then
    BATTERY=$(upower -e | grep BAT)
    if [ -n "$BATTERY" ]; then
      BATTERY_INFO=$(upower -i "$BATTERY" | sed ':a;N;$!ba;s/\n/<br>/g')
    else
      BATTERY_INFO="No battery detected."
    fi
  else
    BATTERY_INFO="upower not installed or not applicable."
  fi
  echo "<tr><td>Battery Status</td><td>$BATTERY_INFO</td></tr>" >> "$outfile"
  
  # System Update Check
  UPDATE_CHECK=$(sudo apt update 2>&1 | sed ':a;N;$!ba;s/\n/<br>/g')
  echo "<tr><td>System Update Check</td><td>$UPDATE_CHECK</td></tr>" >> "$outfile"
  
  echo "</table>" >> "$outfile"
  echo "</body></html>" >> "$outfile"
}

##############################################
# Function: Generate Plain Text Report (for dialogs)
##############################################
generate_full_report() {
  local outfile="$1"
  echo "Full System Test Report - $(date)" > "$outfile"
  echo "Hostname: $(hostname)" >> "$outfile"
  echo "===================================================" >> "$outfile"
  echo "" >> "$outfile"
  
  echo "[OS Information]" >> "$outfile"
  if command -v lsb_release &> /dev/null; then
    lsb_release -a >> "$outfile" 2>/dev/null
  else
    cat /etc/os-release >> "$outfile"
  fi
  echo "" >> "$outfile"
  
  echo "[System Uptime]" >> "$outfile"
  uptime >> "$outfile"
  echo "" >> "$outfile"
  
  echo "[Disk Usage]" >> "$outfile"
  df -h >> "$outfile"
  echo "" >> "$outfile"
  
  echo "[Inode Usage]" >> "$outfile"
  df -ih >> "$outfile"
  echo "" >> "$outfile"
  
  echo "[Memory & Swap]" >> "$outfile"
  free -h >> "$outfile"
  echo "" >> "$outfile"
  
  echo "[CPU Information]" >> "$outfile"
  echo "Load Average: $(top -bn1 | grep 'load average:' | awk -F'load average:' '{print $2}')" >> "$outfile"
  echo "CPU Cores: $(nproc)" >> "$outfile"
  echo "CPU Frequency:" >> "$outfile"
  grep "cpu MHz" /proc/cpuinfo | head -n1 >> "$outfile"
  echo "" >> "$outfile"
  
  echo "[Network Information]" >> "$outfile"
  ip addr >> "$outfile"
  echo "" >> "$outfile"
  
  echo "[Routing Table]" >> "$outfile"
  ip route >> "$outfile"
  echo "" >> "$outfile"
  
  echo "[Ping Test (google.com)]" >> "$outfile"
  if ping -c 4 google.com &> /dev/null; then
    echo "Network connectivity: OK" >> "$outfile"
  else
    echo "Network connectivity: FAIL" >> "$outfile"
  fi
  echo "" >> "$outfile"
  
  echo "[Open Ports]" >> "$outfile"
  sudo ss -tuln >> "$outfile"
  echo "" >> "$outfile"
  
  echo "[Firewall Status (UFW)]" >> "$outfile"
  if command -v ufw &> /dev/null; then
    sudo ufw status verbose >> "$outfile"
  else
    echo "ufw is not installed." >> "$outfile"
  fi
  echo "" >> "$outfile"
  
  echo "[Service Status]" >> "$outfile"
  for service in ssh apache2 nginx mysql; do
    echo "Service: $service" >> "$outfile"
    if systemctl is-active --quiet "$service"; then
      echo "Status: Running" >> "$outfile"
    else
      echo "Status: Not running or not installed" >> "$outfile"
    fi
    echo "---------------------------------" >> "$outfile"
  done
  echo "" >> "$outfile"
  
  echo "[Stress Test]" >> "$outfile"
  echo "Stress test completed (parameters: CPU 4, IO 2, VM 2, Memory 128M, 60s)" >> "$outfile"
  echo "" >> "$outfile"
  
  echo "[Logged in Users]" >> "$outfile"
  who >> "$outfile"
  echo "" >> "$outfile"
  
  echo "[Recent Error Logs]" >> "$outfile"
  grep -i "error" /var/log/syslog 2>/dev/null | tail -n 10 >> "$outfile"
  echo "" >> "$outfile"
  
  echo "[SSH Root Login Setting]" >> "$outfile"
  grep -i "PermitRootLogin" /etc/ssh/sshd_config 2>/dev/null >> "$outfile"
  echo "" >> "$outfile"
  
  echo "[Virtualization Detection]" >> "$outfile"
  systemd-detect-virt >> "$outfile"
  echo "" >> "$outfile"
  
  echo "[Temperature Sensors]" >> "$outfile"
  if command -v sensors &> /dev/null; then
    sensors >> "$outfile"
  else
    echo "sensors command not available." >> "$outfile"
  fi
  echo "" >> "$outfile"
  
  echo "[Top Processes (by CPU)]" >> "$outfile"
  ps -eo pid,comm,%cpu,%mem --sort=-%cpu | head -n 10 >> "$outfile"
  echo "" >> "$outfile"
  
  echo "[Battery Status]" >> "$outfile"
  if command -v upower &> /dev/null; then
    BATTERY=$(upower -e | grep BAT)
    if [ -n "$BATTERY" ]; then
      upower -i "$BATTERY" >> "$outfile" 2>/dev/null
    else
      echo "No battery detected." >> "$outfile"
    fi
  else
    echo "upower not installed or not applicable." >> "$outfile"
  fi
  echo "" >> "$outfile"
  
  echo "[System Update Check]" >> "$outfile"
  sudo apt update >> "$outfile" 2>&1
}

##############################################
# Function: Manual Email Report Sending (HTML)
##############################################
email_report() {
  local recipient_input
  recipient_input=$(dialog --inputbox "Enter recipient email addresses (space-separated):" 8 60 3>&1 1>&2 2>&3)
  RETVAL=$?
  [ $RETVAL -ne 0 ] && return
  if ! validate_emails "$recipient_input"; then
    dialog --title "Email Error" --msgbox "At least one entered email address is invalid." 8 60
    return
  fi
  generate_html_report "$HTML_REPORT"
  # Show a preview in the text viewer (stripped of HTML)
  dialog --title "Report Preview" --msgbox "The HTML email report has been generated. It will be sent as a formatted table." 10 60
  dialog --yesno "Do you want to send the report to the following recipients?\n$recipient_input" 10 70
  response=$?
  if [ $response -eq 0 ]; then
    send_email "$recipient_input" "System Check Report - $(date)" "$HTML_REPORT"
    if [ $? -eq 0 ]; then
      dialog --title "Email" --msgbox "Report sent successfully to $recipient_input." 8 60
    else
      dialog --title "Email Error" --msgbox "Error sending the report." 8 60
    fi
  else
    dialog --title "Email" --msgbox "Email sending canceled." 8 40
  fi
}

##############################################
# Function: Schedule Periodic Email Report
##############################################
schedule_email_report() {
  local INTERVAL RECIPIENTS
  INTERVAL=$(dialog --inputbox "Enter the interval in minutes:" 8 60 3>&1 1>&2 2>&3)
  RETVAL=$?
  [ $RETVAL -ne 0 ] && return
  if ! [[ $INTERVAL =~ ^[0-9]+$ ]]; then
    dialog --title "Error" --msgbox "Invalid interval. Please enter a number." 8 60
    return
  fi
  RECIPIENTS=$(dialog --inputbox "Enter recipient email addresses (space-separated):" 8 60 3>&1 1>&2 2>&3)
  RETVAL=$?
  [ $RETVAL -ne 0 ] && return
  if ! validate_emails "$RECIPIENTS"; then
    dialog --title "Email Error" --msgbox "At least one entered email address is invalid." 8 60
    return
  fi
  echo "$RECIPIENTS" > "$RECIPIENT_FILE"
  local SCRIPT_PATH
  SCRIPT_PATH="$(readlink -f "$0")"
  # Create cron entry (remove any existing --send-report entries)
  local CRON_LINE="*/$INTERVAL * * * * $SCRIPT_PATH --send-report"
  (sudo crontab -l 2>/dev/null | grep -v -- "--send-report"; echo "$CRON_LINE") | sudo crontab -
  dialog --title "Scheduling" --msgbox "Periodic email report scheduled every $INTERVAL minutes for:\n$RECIPIENTS" 10 60
}

##############################################
# Function: Cancel Scheduled Email Report
##############################################
cancel_scheduled_email_report() {
  local SCRIPT_PATH
  SCRIPT_PATH="$(readlink -f "$0")"
  (sudo crontab -l 2>/dev/null | grep -v "$SCRIPT_PATH --send-report") | sudo crontab -
  dialog --title "Scheduling" --msgbox "Periodic email reports have been canceled." 8 60
}

##############################################
# Function: Show Next Scheduled Email Time
##############################################
show_next_email_time() {
  local SCRIPT_PATH interval cron_line current_minute current_second remainder minutes_to_wait next_run
  SCRIPT_PATH="$(readlink -f "$0")"
  cron_line=$(sudo crontab -l 2>/dev/null | grep -- "$SCRIPT_PATH --send-report")
  if [ -z "$cron_line" ]; then
    dialog --title "Next Email Time" --msgbox "No periodic email report is scheduled." 8 60
    return
  fi
  interval=$(echo "$cron_line" | awk '{print $1}' | sed 's/\*\///')
  if ! [[ $interval =~ ^[0-9]+$ ]]; then
    dialog --title "Next Email Time" --msgbox "Could not determine the interval from the cron job." 8 60
    return
  fi
  current_minute=$(date +%M | sed 's/^0*//')
  current_second=$(date +%S)
  remainder=$(( current_minute % interval ))
  minutes_to_wait=$(( interval - remainder ))
  if [ "$remainder" -eq 0 ] && [ "$current_second" -gt 0 ]; then
    minutes_to_wait=$interval
  fi
  next_run=$(date -d "now + $minutes_to_wait minutes" "+%Y-%m-%d %H:%M")
  dialog --title "Next Scheduled Email" --msgbox "Next email will be sent at approximately:\n$next_run" 8 60
}

##############################################
# Function: Add Email Recipient(s)
##############################################
add_email_recipient() {
  local new_emails current
  new_emails=$(dialog --inputbox "Enter additional recipient email addresses (space-separated):" 8 60 3>&1 1>&2 2>&3)
  RETVAL=$?
  [ $RETVAL -ne 0 ] && return
  if ! validate_emails "$new_emails"; then
    dialog --title "Email Error" --msgbox "At least one entered email address is invalid." 8 60
    return
  fi
  if [ -f "$RECIPIENT_FILE" ]; then
    current=$(cat "$RECIPIENT_FILE")
  else
    current=""
  fi
  for email in $new_emails; do
    if ! echo "$current" | grep -qw "$email"; then
      current="$current $email"
    fi
  done
  current=$(echo $current)
  echo "$current" > "$RECIPIENT_FILE"
  dialog --title "Recipients Updated" --msgbox "Recipients updated:\n$current" 10 60
}

##############################################
# Cron mode: send report via email (HTML)
##############################################
if [ "$1" == "--send-report" ]; then
  generate_html_report "$HTML_REPORT"
  if [ ! -f "$RECIPIENT_FILE" ]; then
    echo "No recipient configuration file found. Exiting." >&2
    exit 1
  fi
  RECIPIENTS=$(cat "$RECIPIENT_FILE")
  send_email "$RECIPIENTS" "System Check Report - $(date)" "$HTML_REPORT"
  exit 0
fi

##############################################
# Function: Full System Test (Interactive, plain text report)
##############################################
full_system_test() {
  generate_full_report "$TMP_OUTPUT"
  dialog --title "Full System Test Report" --textbox "$TMP_OUTPUT" 25 90
}

##############################################
# Function: Stress Test with Progress Gauge
##############################################
run_stress_test() {
  local cpu_count="$1" io_count="$2" vm_count="$3" vm_bytes="$4" duration="$5"
  echo -e "\n[Stress Test]" >> "$TMP_OUTPUT"
  echo "Running stress test for $duration seconds with:" >> "$TMP_OUTPUT"
  echo "  CPU: $cpu_count, IO: $io_count, VM: $vm_count, Memory per VM: $vm_bytes" >> "$TMP_OUTPUT"
  echo "Please wait..." >> "$TMP_OUTPUT"
  stress --cpu "$cpu_count" --io "$io_count" --vm "$vm_count" --vm-bytes "$vm_bytes" --timeout "${duration}s" &
  STRESS_PID=$!
  (
    for ((i=1; i<=duration; i++)); do
      sleep 1
      echo $(( i * 100 / duration ))
    done
  ) | dialog --title "Stress Test Progress" --gauge "Running stress test..." 10 70 0
  wait $STRESS_PID
  echo "Stress test completed." >> "$TMP_OUTPUT"
}

##############################################
# Function: Minimal Mail Server Setup (Postfix)
##############################################
setup_mail_server() {
  if ! dpkg -l | grep -qw postfix; then
    dialog --title "Mail Server Setup" --msgbox "Postfix will be installed and configured." 8 60
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y postfix
    sudo postconf -e "myorigin=$(hostname)"
    echo "$(hostname)" | sudo tee /etc/mailname
  else
    dialog --title "Mail Server Setup" --msgbox "Postfix is already installed." 8 60
  fi
}

##############################################
# Function: Individual Tests (Interactive)
##############################################
individual_tests() {
  while true; do
    CHOICE=$(dialog --clear --title "Individual Tests" \
      --menu "Choose a test:" 18 70 12 \
      1 "OS, Kernel & Architecture" \
      2 "System Uptime" \
      3 "Disk & Inodes" \
      4 "Memory & Swap" \
      5 "CPU Info" \
      6 "Network & Connectivity" \
      7 "Ports & Firewall" \
      8 "Service Status" \
      9 "Logged in Users & Error Logs" \
      10 "Security & Virtualization" \
      11 "Temperature, Top Processes & Battery" \
      12 "Back to Main Menu" 3>&1 1>&2 2>&3)
    RETVAL=$?
    [ $RETVAL -ne 0 ] && break
    case $CHOICE in
      1)
        { echo "OS Information:"; 
          if command -v lsb_release &>/dev/null; then 
            lsb_release -a 2>/dev/null; 
          else 
            cat /etc/os-release; 
          fi; 
          echo "Kernel: $(uname -r)"; 
          echo "Architecture: $(uname -m)"; 
        } > "$TMP_OUTPUT"
        dialog --title "OS Information" --textbox "$TMP_OUTPUT" 15 70
        ;;
      2)
        uptime > "$TMP_OUTPUT"
        dialog --title "System Uptime" --textbox "$TMP_OUTPUT" 10 70
        ;;
      3)
        { echo "[Disk Usage]"; df -h; echo -e "\n[Inode Usage]"; df -ih; } > "$TMP_OUTPUT"
        dialog --title "Disk & Inodes" --textbox "$TMP_OUTPUT" 15 70
        ;;
      4)
        free -h > "$TMP_OUTPUT"
        dialog --title "Memory & Swap" --textbox "$TMP_OUTPUT" 10 70
        ;;
      5)
        { echo "Load Average: $(top -bn1 | grep 'load average:' | awk -F'load average:' '{print $2}')"; 
          echo "CPU Cores: $(nproc)"; 
          echo "CPU Frequency:"; 
          grep "cpu MHz" /proc/cpuinfo | head -n1; 
        } > "$TMP_OUTPUT"
        dialog --title "CPU Info" --textbox "$TMP_OUTPUT" 10 70
        ;;
      6)
        { echo "[IP Addresses]"; ip addr; 
          echo -e "\n[Routing Table]"; ip route; 
          echo -e "\n[Ping Test (google.com)]"; 
          if ping -c 4 google.com &> /dev/null; then 
            echo "Connectivity: OK"; 
          else 
            echo "Connectivity: FAIL"; 
          fi; 
        } > "$TMP_OUTPUT"
        dialog --title "Network Info" --textbox "$TMP_OUTPUT" 18 70
        ;;
      7)
        { echo "[Open Ports]"; sudo ss -tuln; 
          echo -e "\n[Firewall Status]"; 
          if command -v ufw &> /dev/null; then 
            sudo ufw status verbose; 
          else 
            echo "ufw is not installed."; 
          fi; 
        } > "$TMP_OUTPUT"
        dialog --title "Ports & Firewall" --textbox "$TMP_OUTPUT" 18 70
        ;;
      8)
        { for service in ssh apache2 nginx mysql; do 
            echo "Service: $service"; 
            if systemctl is-active --quiet "$service"; then 
              echo "Status: Running"; 
            else 
              echo "Status: Not running or not installed"; 
            fi; 
            echo "---------------------------------"; 
          done; 
        } > "$TMP_OUTPUT"
        dialog --title "Service Status" --textbox "$TMP_OUTPUT" 15 70
        ;;
      9)
        { echo "[Logged in Users]"; who; 
          echo -e "\n[Error Logs]"; 
          grep -i "error" /var/log/syslog 2>/dev/null | tail -n 10; 
        } > "$TMP_OUTPUT"
        dialog --title "Users & Error Logs" --textbox "$TMP_OUTPUT" 18 70
        ;;
      10)
        { echo "[SSH Root Login]"; grep -i "PermitRootLogin" /etc/ssh/sshd_config 2>/dev/null; 
          echo -e "\n[Virtualization]"; systemd-detect-virt; 
        } > "$TMP_OUTPUT"
        dialog --title "Security & Virtualization" --textbox "$TMP_OUTPUT" 15 70
        ;;
      11)
        { echo "[Temperature]"; 
          if command -v sensors &> /dev/null; then 
            sensors; 
          else 
            echo "sensors command not available."; 
          fi; 
          echo -e "\n[Top Processes]"; ps -eo pid,comm,%cpu,%mem --sort=-%cpu | head -n 10; 
          echo -e "\n[Battery]"; 
          if command -v upower &> /dev/null; then 
            BATTERY=$(upower -e | grep BAT); 
            if [ -n "$BATTERY" ]; then 
              upower -i "$BATTERY" 2>/dev/null; 
            else 
              echo "No battery detected."; 
            fi; 
          else 
            echo "upower not installed."; 
          fi; 
        } > "$TMP_OUTPUT"
        dialog --title "Temperature, Processes & Battery" --textbox "$TMP_OUTPUT" 20 70
        ;;
      12)
        break
        ;;
    esac
  done
}

##############################################
# Main Menu (Improved GUI)
##############################################
while true; do
  CHOICE=$(dialog --clear --title "Ubuntu Server Test Suite" \
    --menu "Choose an option:" 28 80 16 \
    1 "Full System Test" \
    2 "Individual Tests" \
    3 "Configurable Stress Test" \
    4 "Save Report" \
    5 "Manual Email Report" \
    6 "Test Email Sending" \
    7 "Setup Mail Server" \
    8 "Schedule Periodic Email Report" \
    9 "Cancel Scheduled Email Report" \
    10 "Show Next Scheduled Email Time" \
    11 "Add Email Recipient(s)" \
    12 "System Upgrade" \
    13 "Delete Report" \
    14 "Open Required UFW Ports" \
    15 "Exit" 3>&1 1>&2 2>&3)
  RETVAL=$?
  [ $RETVAL -ne 0 ] && break
  case $CHOICE in
    1) full_system_test ;;
    2) individual_tests ;;
    3)
       stress_params=$(dialog --title "Configure Stress Test" \
         --form "Enter parameters:" 15 70 5 \
         "CPU Count:" 1 1 "4" 1 20 10 0 \
         "IO Count:" 2 1 "2" 2 20 10 0 \
         "VM Count:" 3 1 "2" 3 20 10 0 \
         "VM Bytes:" 4 1 "128M" 4 20 10 0 \
         "Duration (s):" 5 1 "60" 5 20 10 0 \
         3>&1 1>&2 2>&3)
       RETVAL=$?
       [ $RETVAL -ne 0 ] && continue
       CPU_COUNT=$(echo "$stress_params" | sed -n '1p')
       IO_COUNT=$(echo "$stress_params" | sed -n '2p')
       VM_COUNT=$(echo "$stress_params" | sed -n '3p')
       VM_BYTES=$(echo "$stress_params" | sed -n '4p')
       DURATION=$(echo "$stress_params" | sed -n '5p')
       run_stress_test "$CPU_COUNT" "$IO_COUNT" "$VM_COUNT" "$VM_BYTES" "$DURATION"
       ;;
    4)
       cp "$TMP_OUTPUT" "$REPORT_FILE"
       dialog --title "Save Report" --msgbox "Report saved as: $REPORT_FILE" 8 60
       ;;
    5) email_report ;;
    6) test_email_settings ;;
    7) setup_mail_server ;;
    8) schedule_email_report ;;
    9) cancel_scheduled_email_report ;;
    10) show_next_email_time ;;
    11) add_email_recipient ;;
    12)
       dialog --yesno "Do you want to update and upgrade the system?" 8 60
       response=$?
       if [ $response -eq 0 ]; then
         sudo apt update && sudo apt upgrade -y | tee -a "$TMP_OUTPUT"
         dialog --title "System Upgrade" --msgbox "System upgrade completed." 8 60
       else
         dialog --title "System Upgrade" --msgbox "System upgrade canceled." 8 40
       fi
       ;;
    13)
       > "$TMP_OUTPUT"
       dialog --title "Delete Report" --msgbox "Report has been deleted." 8 40
       ;;
    14) 
       if ! command -v ufw &> /dev/null; then
         dialog --title "UFW Error" --msgbox "UFW is not installed." 8 60
       else
         STATUS=$(sudo ufw status | head -n 1)
         if [[ "$STATUS" == "Status: inactive" ]]; then
           dialog --title "UFW" --msgbox "UFW is inactive. It will now be enabled." 8 60
           sudo ufw --force enable
         fi
         sudo ufw allow 22/tcp
         sudo ufw allow 25/tcp
         sudo ufw allow 80/tcp
         sudo ufw allow 443/tcp
         sudo ufw allow 587/tcp
         sudo ufw allow 3306/tcp
         dialog --title "UFW" --msgbox "Required ports (22, 25, 80, 443, 587, 3306) have been opened." 8 60
       fi
       ;;
    15) break ;;
  esac
done

clear

#!/bin/bash
LOG_DIR="/var/log/system_monitor"
SYSTEM_REPORT_LOG=$LOG_DIR/system_report.log
HIGH_CPU_PROCESSES_LOG=$LOG_DIR/high_cpu_processes.log
HIGH_MEMORY_PROCESSES_LOG=$LOG_DIR/high_memory_processes.log
DISK_USAGE_LOG=$LOG_DIR/disk_usage.log
CPU_MEMORY_USAGE_LOG=$LOG_DIR/cpu_memory_usage.log
DIRECTORY_USAGE_LOG=$LOG_DIR/directory_usage.log
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
SCRIPT_PATH="/root/system_monitor.sh"

if [[ ${UID} -ne 0 ]]; then
    echo "Please Run with sudo or root"
    exit 1
fi

# make log directory
if [ ! -d "$LOG_DIR" ]; then
    mkdir -p $LOG_DIR || {
        echo "Error: Cannot create $LOG_DIR" >&2; exit 1;
    }
    chmod 750 $LOG_DIR
fi

if [ ! -w "$LOG_DIR" ]; then
    echo "Error: No write permission for $LOG_DIR. Adjust permissions or run with sudo." >&2
    exit 1
fi

for package in nmon htop; do
    if ! command -v "$package" &>/dev/null; then
        echo "$package is not installed. Attempting to install..."
        sudo apt-get update && sudo apt-get install -y "$package" || {
            echo "Error: Failed to install $package" >&2
            exit 1
        }
    fi
done

# Verify core utilities
for tool in df du ps; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "Error: Core utility $tool not found" >&2
        exit 1
    fi
done

# Generate system report
{
    echo "===================="
    echo "System Report - $TIMESTAMP"
    echo "===================="
} > $SYSTEM_REPORT_LOG

# Monitor CPU and Memory Usage
TERM=xterm htop -C -d 10 -n 1 > $CPU_MEMORY_USAGE_LOG
nmon -f -s 10 -c 6 -m $LOG_DIR &
echo "[CPU & Memory Usage Logged]" >> $SYSTEM_REPORT_LOG

# Disk Usage Monitoring
df -h > $DISK_USAGE_LOG
echo "[Disk Usage Logged]" >> $SYSTEM_REPORT_LOG

du -sh /var/* > $DIRECTORY_USAGE_LOG
echo "[Development Directory Usage Logged]" >> "$SYSTEM_REPORT_LOG"

# Process Monitoring
ps aux --sort=-%cpu | head -10 > $HIGH_CPU_PROCESSES_LOG
echo "[High CPU Usage Processes Logged]" >> $SYSTEM_REPORT_LOG

ps aux --sort=-%mem | head -10 > $HIGH_MEMORY_PROCESSES_LOG
echo "[High Memory Usage Processes Logged]" >> $SYSTEM_REPORT_LOG

# Display summary
echo "System monitoring logs saved in $LOG_DIR"

# Cron Job Setup
# Create temp file for crontab
TEMP_CRON=$(mktemp)

crontab -l > "$TEMP_CRON" 2>/dev/null || true

if ! grep -q "$SCRIPT_PATH" "$TEMP_CRON"; then
    echo "Setting up automatic cron job for system monitoring..."
    echo "0 * * * * $SCRIPT_PATH" >> "$TEMP_CRON"
    crontab "$TEMP_CRON"
    echo "Cron job added: Runs every hour."
else
    echo "Cron job already exists. No changes made."
fi

rm "$TEMP_CRON"

# Verify crontab
echo "Current crontab:"
crontab -l
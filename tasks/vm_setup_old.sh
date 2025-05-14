#!/bin/bash

# Configuration
VM_USER="intern"
VM_IP="192.168.168.156"
ERROR_LOG="/home/pranav/Desktop/error.log"
LOCAL_FILE="/home/pranav/Desktop/test.txt"
REMOTE_FILE="/home/intern/test.txt"
VM_ERROR_LOG="/home/intern/error.log"

# Ensure error log exists on host
touch "$ERROR_LOG" || { echo "Error: Cannot create $ERROR_LOG"; exit 1; }

# Function to log errors
log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$ERROR_LOG"
}

# Check SSH connectivity
check_ssh() {
    ssh -q -o ConnectTimeout=5 "$VM_USER@$VM_IP" exit 2>/dev/null
    if [ $? -ne 0 ]; then
        log_error "SSH connection to $VM_IP failed"
        echo "Error: Cannot reach VM. Check IP or SSH service."
        exit 1
    fi
}

# Task 1: Install MySQL, enable service, verify, create database
task_mysql() {
    check_ssh
    ssh "$VM_USER@$VM_IP" << 'EOF' 2>> "$ERROR_LOG"
        set -e
        # Check if MySQL is installed and running
        if command -v mysql >/dev/null 2>&1 && sudo -n systemctl is-active --quiet mysql 2>/dev/null; then
            echo "MySQL already installed and running"
            # Check if 'test' database exists
            if sudo -n mysql -e "SHOW DATABASES;" 2>/dev/null | grep -q "^test$"; then
                echo "Database 'test' already exists"
                exit 0
            fi
            # Create database
            sudo -n mysql -e "CREATE DATABASE IF NOT EXISTS test;" 2>> "$HOME/error.log" && echo "Database 'test' created" || { echo "Failed to create database" >> "$HOME/error.log"; exit 1; }
            exit 0
        fi
        # Install MySQL
        sudo -n apt update 2>> "$HOME/error.log" || { echo "apt update failed" >> "$HOME/error.log"; exit 1; }
        sudo -n apt install -y mysql-server 2>> "$HOME/error.log" || { echo "MySQL installation failed" >> "$HOME/error.log"; exit 1; }
        sudo -n systemctl enable mysql 2>> "$HOME/error.log" || { echo "MySQL enable failed" >> "$HOME/error.log"; exit 1; }
        sudo -n systemctl start mysql 2>> "$HOME/error.log" || { echo "MySQL start failed" >> "$HOME/error.log"; exit 1; }
        if ! sudo -n systemctl is-active --quiet mysql 2>/dev/null; then
            echo "MySQL service not running" >> "$HOME/error.log"
            exit 1
        fi
        echo "MySQL is running"
        # Create database
        sudo -n mysql -e "CREATE DATABASE IF NOT EXISTS test;" 2>> "$HOME/error.log" && echo "Database 'test' created" || { echo "Failed to create database" >> "$HOME/error.log"; exit 1; }
EOF
    if [ $? -eq 0 ]; then
        echo "Task 1: MySQL setup completed"
    else
        log_error "Task 1: MySQL setup failed"
        echo "Task 1 failed. Check $ERROR_LOG and $VM_ERROR_LOG on VM"
        return 1
    fi
}

# Task 2: Install htop, curl
task_tools() {
    check_ssh
    ssh "$VM_USER@$VM_IP" << 'EOF' 2>> "$ERROR_LOG"
        set -e
        if command -v htop >/dev/null 2>&1 && command -v curl >/dev/null 2>&1; then
            echo "htop and curl already installed"
            htop --version
            curl --version
            exit 0
        fi
        sudo -n apt update 2>> "$HOME/error.log" || { echo "apt update failed" >> "$HOME/error.log"; exit 1; }
        sudo -n apt install -y htop curl 2>> "$HOME/error.log" || { echo "htop/curl installation failed" >> "$HOME/error.log"; exit 1; }
        htop --version 2>> "$HOME/error.log"
        curl --version 2>> "$HOME/error.log"
EOF
    if [ $? -eq 0 ]; then
        echo "Task 2: htop and curl installed"
    else
        log_error "Task 2: htop/curl installation failed"
        echo "Task 2 failed. Check $ERROR_LOG and $VM_ERROR_LOG on VM"
        return 1
    fi
}

# Task 3: Install Python, print version
task_python() {
    check_ssh
    ssh "$VM_USER@$VM_IP" << 'EOF' 2>> "$ERROR_LOG"
        set -e
        if command -v python3 >/dev/null 2>&1; then
            python3 --version
            exit 0
        fi
        sudo -n apt update 2>> "$HOME/error.log" || { echo "apt update failed" >> "$HOME/error.log"; exit 1; }
        sudo -n apt install -y python3 python3-pip 2>> "$HOME/error.log" || { echo "Python installation failed" >> "$HOME/error.log"; exit 1; }
        python3 --version 2>> "$HOME/error.log"
EOF
    if [ $? -eq 0 ]; then
        echo "Task 3: Python installed"
    else
        log_error "Task 3: Python installation failed"
        echo "Task 3 failed. Check $ERROR_LOG and $VM_ERROR_LOG on VM"
        return 1
    fi
}

# Task 4: Install Go, print version
task_golang() {
    check_ssh
    ssh "$VM_USER@$VM_IP" << 'EOF' 2>> "$ERROR_LOG"
        set -e
        export PATH=$PATH:/usr/local/go/bin
        if command -v go >/dev/null 2>&1; then
            go version
            exit 0
        fi
        sudo -n apt update 2>> "$HOME/error.log" || { echo "apt update failed" >> "$HOME/error.log"; exit 1; }
        sudo -n apt install -y wget 2>> "$HOME/error.log" || { echo "wget installation failed" >> "$HOME/error.log"; exit 1; }
        wget https://go.dev/dl/go1.22.7.linux-amd64.tar.gz -O /tmp/go.tar.gz 2>> "$HOME/error.log" || { echo "Go download failed" >> "$HOME/error.log"; exit 1; }
        sudo -n tar -C /usr/local -xzf /tmp/go.tar.gz 2>> "$HOME/error.log" || { echo "Go extraction failed" >> "$HOME/error.log"; exit 1; }
        if ! grep -q "/usr/local/go/bin" "$HOME/.profile"; then
            echo 'export PATH=$PATH:/usr/local/go/bin' >> "$HOME/.profile" 2>> "$HOME/error.log"
        fi
        export PATH=$PATH:/usr/local/go/bin
        go version 2>> "$HOME/error.log" || { echo "Go version check failed" >> "$HOME/error.log"; exit 1; }
EOF
    if [ $? -eq 0 ]; then
        echo "Task 4: Go installed"
    else
        log_error "Task 4: Go installation failed"
        echo "Task 4 failed. Check $ERROR_LOG and $VM_ERROR_LOG on VM"
        return 1
    fi
}

# Task 5: Install Docker, enable non-root user, pull nginx
task_docker() {
    check_ssh
    ssh "$VM_USER@$VM_IP" << 'EOF' 2>> "$ERROR_LOG"
        set -e
        if command -v docker >/dev/null 2>&1 && docker info --format '{{.ServerVersion}}' >/dev/null 2>&1; then
            echo "Docker is running"
            if docker images nginx >/dev/null 2>&1; then
                echo "NGINX image already pulled"
                exit 0
            fi
        fi
        sudo -n apt update 2>> "$HOME/error.log" || { echo "apt update failed" >> "$HOME/error.log"; exit 1; }
        sudo -n apt install -y ca-certificates curl gnupg 2>> "$HOME/error.log" || { echo "Docker dependencies failed" >> "$HOME/error.log"; exit 1; }
        sudo -n install -m 0755 -d /etc/apt/keyrings 2>> "$HOME/error.log"
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo -n gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>> "$HOME/error.log" || { echo "Docker key failed" >> "$HOME/error.log"; exit 1; }
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu noble stable" | sudo -n tee /etc/apt/sources.list.d/docker.list >/dev/null 2>> "$HOME/error.log"
        sudo -n apt update 2>> "$HOME/error.log" || { echo "apt update failed" >> "$HOME/error.log"; exit 1; }
        sudo -n apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin 2>> "$HOME/error.log" || { echo "Docker installation failed" >> "$HOME/error.log"; exit 1; }
        sudo -n systemctl enable docker 2>> "$HOME/error.log" || { echo "Docker enable failed" >> "$HOME/error.log"; exit 1; }
        sudo -n systemctl start docker 2>> "$HOME/error.log" || { echo "Docker start failed" >> "$HOME/error.log"; exit 1; }
        if ! sudo -n systemctl is-active --quiet docker 2>/dev/null; then
            echo "Docker service not running" >> "$HOME/error.log"
            exit 1
        fi
        echo "Docker is running"
        sudo -n usermod -aG docker "$USER" 2>> "$HOME/error.log" || { echo "Docker user permission failed" >> "$HOME/error.log"; exit 1; }
        # Apply group changes in current session
        newgrp docker << 'INNER'
            docker --version 2>> "$HOME/error.log" || { echo "Docker non-root access failed" >> "$HOME/error.log"; exit 1; }
            docker pull nginx 2>> "$HOME/error.log" || { echo "NGINX pull failed" >> "$HOME/error.log"; exit 1; }
            echo "NGINX image pulled"
INNER
        if [ $? -ne 0 ]; then
            echo "Docker non-root commands failed" >> "$HOME/error.log"
            exit 1
        fi
EOF
    if [ $? -eq 0 ]; then
        echo "Task 5: Docker setup completed"
    else
        log_error "Task 5: Docker setup failed"
        echo "Task 5 failed. Check $ERROR_LOG and $VM_ERROR_LOG on VM"
        return 1
    fi
}

# Task 6: Copy file, verify checksum
task_file_copy() {
    check_ssh
    # Create test file on host if not exists
    if [ ! -f "$LOCAL_FILE" ]; then
        echo "Test file content" > "$LOCAL_FILE"
    fi
    # Copy file
    scp "$LOCAL_FILE" "$VM_USER@$VM_IP:$REMOTE_FILE" 2>> "$ERROR_LOG"
    if [ $? -ne 0 ]; then
        log_error "Task 6: File copy failed"
        echo "Task 6 failed. Check $ERROR_LOG"
        return 1
    fi
    # Verify checksum
    LOCAL_SUM=$(sha256sum "$LOCAL_FILE" | cut -d' ' -f1)
    REMOTE_SUM=$(ssh "$VM_USER@$VM_IP" "sha256sum $REMOTE_FILE" 2>> "$ERROR_LOG" | cut -d' ' -f1)
    if [ "$LOCAL_SUM" = "$REMOTE_SUM" ]; then
        echo "Task 6: File copied, checksums match ($LOCAL_SUM)"
    else
        log_error "Task 6: Checksum mismatch (Local: $LOCAL_SUM, Remote: $REMOTE_SUM)"
        echo "Task 6 failed. Check $ERROR_LOG"
        return 1
    fi
}

# Interactive menu
echo "Select a task to perform on the VM:"
echo "1) Install MySQL, create 'test' database"
echo "2) Install htop, curl"
echo "3) Install Python, print version"
echo "4) Install Go, print version"
echo "5) Install Docker, pull nginx"
echo "6) Copy file and verify checksum"
echo -n "Enter task number (1-6): "
read -r TASK

case $TASK in
    1) task_mysql ;;
    2) task_tools ;;
    3) task_python ;;
    4) task_golang ;;
    5) task_docker ;;
    6) task_file_copy ;;
    *) echo "Invalid choice"; exit 1 ;;
esac

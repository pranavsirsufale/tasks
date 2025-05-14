#!/bin/bash

# Setup variables
VM_USER="intern"
VM_IP="192.168.168.156"
ERROR_LOG="/home/pranav/Desktop/error.log"
VM_ERROR_LOG="/home/intern/error.log"
LOCAL_FILE="/home/pranav/Desktop/test.txt"
REMOTE_FILE="/home/intern/test.txt"

# Create error log file
touch $ERROR_LOG
if [ $? -ne 0 ]; then
    echo "Error: Cannot create error log at $ERROR_LOG"
    exit 1
fi

# Function to add error to log
log_error() {
    echo "[$(date)] $1" >> $ERROR_LOG
}

# Check if VM is reachable
check_ssh() {
    ssh -q -o ConnectTimeout=5 $VM_USER@$VM_IP "exit" 2>/dev/null
    if [ $? -ne 0 ]; then
        log_error "Cannot connect to VM at $VM_IP"
        echo "Error: Cannot reach VM. Check IP or SSH service."
        exit 1
    fi
}

# Task 1: Install MySQL and create 'test' database
task_mysql() {
    check_ssh
    ssh $VM_USER@$VM_IP bash -c '
        if command -v mysql >/dev/null && sudo -n systemctl is-active mysql >/dev/null; then
            echo "MySQL already installed and running"
            if sudo -n mysql -e "SHOW DATABASES;" | grep -q "^test$"; then
                echo "Database test already exists"
                exit 0
            fi
            sudo -n mysql -e "CREATE DATABASE test;" 2>>$HOME/error.log
            if [ $? -eq 0 ]; then
                echo "Database test created"
                exit 0
            else
                echo "Failed to create database" >>$HOME/error.log
                exit 1
            fi
        fi
        echo "Installing MySQL..."
        sudo -n apt update 2>>$HOME/error.log
        sudo -n apt install -y mysql-server 2>>$HOME/error.log
        sudo -n systemctl enable mysql 2>>$HOME/error.log
        sudo -n systemctl start mysql 2>>$HOME/error.log
        if sudo -n systemctl is-active mysql >/dev/null; then
            echo "MySQL is running"
            sudo -n mysql -e "CREATE DATABASE test;" 2>>$HOME/error.log
            if [ $? -eq 0 ]; then
                echo "Database test created"
                exit 0
            else
                echo "Failed to create database" >>$HOME/error.log
                exit 1
            fi
        else
            echo "MySQL not running" >>$HOME/error.log
            exit 1
        fi
    '
    if [ $? -eq 0 ]; then
        echo "Task 1: MySQL setup done"
    else
        log_error "Task 1: MySQL setup failed"
        echo "Task 1 failed. Check $ERROR_LOG and $VM_ERROR_LOG on VM"
        return 1
    fi
}

# Task 2: Install htop and curl
task_tools() {
    check_ssh
    ssh $VM_USER@$VM_IP bash -c '
        if command -v htop >/dev/null && command -v curl >/dev/null; then
            echo "htop and curl already installed"
            htop --version
            curl --version
            exit 0
        fi
        echo "Installing htop and curl..."
        sudo -n apt update 2>>$HOME/error.log
        sudo -n apt install -y htop curl 2>>$HOME/error.log
        if [ $? -eq 0 ]; then
            htop --version
            curl --version
            exit 0
        else
            echo "htop/curl install failed" >>$HOME/error.log
            exit 1
        fi
    '
    if [ $? -eq 0 ]; then
        echo "Task 2: htop and curl installed"
    else
        log_error "Task 2: htop/curl install failed"
        echo "Task 2 failed. Check $ERROR_LOG and $VM_ERROR_LOG on VM"
        return 1
    fi
}

# Task 3: Install Python and show version
task_python() {
    check_ssh
    ssh $VM_USER@$VM_IP bash -c '
        if command -v python3 >/dev/null; then
            python3 --version
            exit 0
        fi
        echo "Installing Python..."
        sudo -n apt update 2>>$HOME/error.log
        sudo -n apt install -y python3 python3-pip 2>>$HOME/error.log
        if [ $? -eq 0 ]; then
            python3 --version
            exit 0
        else
            echo "Python install failed" >>$HOME/error.log
            exit 1
        fi
    '
    if [ $? -eq 0 ]; then
        echo "Task 3: Python installed"
    else
        log_error "Task 3: Python install failed"
        echo "Task 3 failed. Check $ERROR_LOG and $VM_ERROR_LOG on VM"
        return 1
    fi
}

# Task 4: Install Go and show version
task_golang() {
    check_ssh
    ssh $VM_USER@$VM_IP bash -c '
        export PATH=$PATH:/usr/local/go/bin
        if command -v go >/dev/null; then
            go version
            exit 0
        fi
        echo "Installing Go..."
        sudo -n apt update 2>>$HOME/error.log
        sudo -n apt install -y wget 2>>$HOME/error.log
        wget https://go.dev/dl/go1.22.7.linux-amd64.tar.gz -O /tmp/go.tar.gz 2>>$HOME/error.log
        sudo -n tar -C /usr/local -xzf /tmp/go.tar.gz 2>>$HOME/error.log
        if ! grep -q "/usr/local/go/bin" $HOME/.profile; then
            echo "export PATH=\$PATH:/usr/local/go/bin" >> $HOME/.profile
        fi
        export PATH=$PATH:/usr/local/go/bin
        if go version 2>>$HOME/error.log; then
            exit 0
        else
            echo "Go install failed" >>$HOME/error.log
            exit 1
        fi
    '
    if [ $? -eq 0 ]; then
        echo "Task 4: Go installed"
    else
        log_error "Task 4: Go install failed"
        echo "Task 4 failed. Check $ERROR_LOG and $VM_ERROR_LOG on VM"
        return 1
    fi
}

# Task 5: Install Docker and pull nginx
task_docker() {
    check_ssh
    ssh $VM_USER@$VM_IP bash -c '
        if command -v docker >/dev/null && docker info >/dev/null 2>&1; then
            echo "Docker is running"
            if docker images nginx >/dev/null 2>&1; then
                echo "NGINX image already pulled"
                exit 0
            fi
        fi
        echo "Installing Docker..."
        sudo -n apt update 2>>$HOME/error.log
        sudo -n apt install -y ca-certificates curl gnupg 2>>$HOME/error.log
        sudo -n mkdir -p /etc/apt/keyrings 2>>$HOME/error.log
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo -n gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>>$HOME/error.log
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu noble stable" | sudo -n tee /etc/apt/sources.list.d/docker.list >/dev/null 2>>$HOME/error.log
        sudo -n apt update 2>>$HOME/error.log
        sudo -n apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin 2>>$HOME/error.log
        sudo -n systemctl enable docker 2>>$HOME/error.log
        sudo -n systemctl start docker 2>>$HOME/error.log
        if sudo -n systemctl is-active docker >/dev/null; then
            echo "Docker is running"
            sudo -n usermod -aG docker $USER 2>>$HOME/error.log
            if docker --version 2>>$HOME/error.log; then
                docker pull nginx 2>>$HOME/error.log
                if [ $? -eq 0 ]; then
                    echo "NGINX image pulled"
                    exit 0
                else
                    echo "NGINX pull failed" >>$HOME/error.log
                    exit 1
                fi
            else
                echo "Docker non-root access failed" >>$HOME/error.log
                exit 1
            fi
        else
            echo "Docker not running" >>$HOME/error.log
            exit 1
        fi
    '
    if [ $? -eq 0 ]; then
        echo "Task 5: Docker setup done"
    else
        log_error "Task 5: Docker setup failed"
        echo "Task 5 failed. Check $ERROR_LOG and $VM_ERROR_LOG on VM"
        return 1
    fi
}

# Task 6: Copy file and check checksum
task_file_copy() {
    check_ssh
    if [ ! -f "$LOCAL_FILE" ]; then
        echo "Test file content" > $LOCAL_FILE
    fi
    scp $LOCAL_FILE $VM_USER@$VM_IP:$REMOTE_FILE 2>>$ERROR_LOG
    if [ $? -ne 0 ]; then
        log_error "Task 6: File copy failed"
        echo "Task 6 failed. Check $ERROR_LOG"
        return 1
    fi
    LOCAL_SUM=$(sha256sum $LOCAL_FILE | cut -d" " -f1)
    REMOTE_SUM=$(ssh $VM_USER@$VM_IP "sha256sum $REMOTE_FILE" 2>>$ERROR_LOG | cut -d" " -f1)
    if [ "$LOCAL_SUM" = "$REMOTE_SUM" ]; then
        echo "Task 6: File copied, checksums match ($LOCAL_SUM)"
    else
        log_error "Task 6: Checksum mismatch (Local: $LOCAL_SUM, Remote: $REMOTE_SUM)"
        echo "Task 6 failed. Check $ERROR_LOG"
        return 1
    fi
}

# Show menu
echo "Select a task to perform on the VM:"
echo "1) Install MySQL, create 'test' database"
echo "2) Install htop, curl"
echo "3) Install Python, print version"
echo "4) Install Go, print version"
echo "5) Install Docker, pull nginx"
echo "6) Copy file and verify checksum"
echo -n "Enter task number (1-6): "
read TASK

# Run selected task
if [ "$TASK" = "1" ]; then
    task_mysql
elif [ "$TASK" = "2" ]; then
    task_tools
elif [ "$TASK" = "3" ]; then
    task_python
elif [ "$TASK" = "4" ]; then
    task_golang
elif [ "$TASK" = "5" ]; then
    task_docker
elif [ "$TASK" = "6" ]; then
    task_file_copy
else
    echo "Invalid choice"
    exit 1
fi

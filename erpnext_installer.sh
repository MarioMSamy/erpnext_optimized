#!/usr/bin/env bash

# Setting error handler
handle_error() {
    local line=$1
    local exit_code=$2
    echo -e "${RED}An error occurred on line $line with exit status $exit_code${NC}"
    rollback
    exit $exit_code
}

trap 'handle_error $LINENO $?' ERR
set -euo pipefail

# Retrieve server IP
server_ip=$(hostname -I | awk '{print $1}')

# Setting up colors for echo commands
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
LIGHT_BLUE='\033[1;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    local log_file="/var/log/erpnext_installer.log"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "[$timestamp] $1" | tee -a "$log_file"
}

# Rollback function
rollback() {
    echo -e "${RED}Rolling back changes...${NC}"

    # Remove installed packages
    sudo apt remove --purge mariadb-server redis-server nginx -y
    sudo apt autoremove -y

    # Remove NVM and Node.js
    rm -rf ~/.nvm
    sed -i '/NVM_DIR/d' ~/.profile

    # Restore /etc/sysctl.conf
    if [[ -f /etc/sysctl.conf.backup ]]; then
        sudo mv /etc/sysctl.conf.backup /etc/sysctl.conf
    fi

    # Restore MariaDB configuration
    if [[ -f /etc/mysql/my.cnf.backup ]]; then
        sudo mv /etc/mysql/my.cnf.backup /etc/mysql/my.cnf
    fi

    # Remove Bench installation
    if [[ -d ~/frappe-bench ]]; then
        rm -rf ~/frappe-bench
    fi

    echo -e "${YELLOW}Rollback complete.${NC}"
}

# Validate domain name
validate_domain() {
    local domain="$1"
    if [[ ! "$domain" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        echo -e "${RED}Invalid domain name. Please enter a valid domain (e.g., example.com).${NC}"
        return 1
    fi
    return 0
}

# Validate password strength
validate_password() {
    local password="$1"
    if [[ ${#password} -lt 8 ]]; then
        echo -e "${RED}Password must be at least 8 characters long.${NC}"
        return 1
    fi
    return 0
}

# Function to securely prompt for input twice (e.g., passwords)
ask_twice() {
    local prompt="$1"
    local is_password="$2"
    local value1=""
    local value2=""

    while true; do
        if [[ "$is_password" == "true" ]]; then
            read -sp "$prompt: " value1
            echo
            read -sp "Confirm $prompt: " value2
            echo
        else
            read -p "$prompt: " value1
            read -p "Confirm $prompt: " value2
        fi

        if [[ "$value1" == "$value2" ]]; then
            echo "$value1"
            return 0
        else
            echo -e "${RED}Inputs do not match. Please try again.${NC}"
        fi
    done
}

# Retry mechanism for failed commands
retry_command() {
    local command="$1"
    local max_retries=3
    local retry_delay=5

    for ((i = 1; i <= max_retries; i++)); do
        if eval "$command"; then
            return 0
        else
            echo -e "${YELLOW}Attempt $i failed. Retrying in $retry_delay seconds...${NC}"
            sleep "$retry_delay"
        fi
    done

    echo -e "${RED}Command failed after $max_retries attempts.${NC}"
    return 1
}

# Function to optimize MariaDB based on server resources
optimize_mariadb() {
    local total_ram=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local ram_mb=$((total_ram / 1024))
    local cpu_cores=$(nproc)

    log "${YELLOW}Optimizing MariaDB configuration based on server resources...${NC}"

    # Calculate InnoDB buffer pool size (70% of total RAM, max 16GB)
    local innodb_buffer_pool_size=$((ram_mb * 70 / 100))
    if [[ $innodb_buffer_pool_size -gt 16384 ]]; then
        innodb_buffer_pool_size=16384
    fi

    # Calculate max connections (based on CPU cores)
    local max_connections=$((cpu_cores * 100))

    # Backup existing configuration
    sudo cp /etc/mysql/my.cnf /etc/mysql/my.cnf.backup

    # Append optimized settings to my.cnf
    sudo bash -c "cat << EOF >> /etc/mysql/my.cnf
[mysqld]
# InnoDB Settings
innodb_buffer_pool_size = ${innodb_buffer_pool_size}M
innodb_log_file_size = 512M
innodb_log_buffer_size = 64M
innodb_flush_log_at_trx_commit = 1
innodb_file_per_table = 1
innodb_flush_method = O_DIRECT

# Connection Settings
max_connections = $max_connections
max_user_connections = 100
wait_timeout = 600
interactive_timeout = 600

# Query Cache Settings (disabled for MariaDB 10+)
query_cache_type = 0
query_cache_size = 0

# Threading Settings
thread_cache_size = $cpu_cores
thread_stack = 256K

# Buffer Settings
key_buffer_size = 64M
sort_buffer_size = 4M
read_buffer_size = 4M
read_rnd_buffer_size = 4M
join_buffer_size = 4M

# Logging Settings
slow_query_log = 1
slow_query_log_file = /var/log/mysql/slow.log
long_query_time = 2
log_queries_not_using_indexes = 1

# Temporary Tables
tmp_table_size = 64M
max_heap_table_size = 64M
EOF"

    # Restart MariaDB to apply changes
    sudo systemctl restart mariadb
    log "${GREEN}MariaDB optimization complete!${NC}"
}

# Function to optimize system-wide settings
optimize_system() {
    log "${YELLOW}Optimizing system-wide settings...${NC}"

    # Backup /etc/sysctl.conf
    sudo cp /etc/sysctl.conf /etc/sysctl.conf.backup

    # Increase file descriptor limits
    sudo bash -c "echo '* soft nofile 65535' >> /etc/security/limits.conf"
    sudo bash -c "echo '* hard nofile 65535' >> /etc/security/limits.conf"

    # Adjust kernel parameters for better performance
    sudo bash -c "cat << EOF >> /etc/sysctl.conf
# Increase TCP buffer sizes
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216

# Increase the number of open files
fs.file-max = 65535

# Reduce swap usage (prioritize RAM)
vm.swappiness = 10
vm.dirty_ratio = 60
vm.dirty_background_ratio = 2

# Increase the number of incoming connections
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 65535

# Enable TCP fast open
net.ipv4.tcp_fastopen = 3
EOF"

    # Apply kernel settings
    sudo sysctl -p

    # Optimize disk I/O (if using SSDs)
    if [[ $(lsblk -d -o rota | grep -c 0) -gt 0 ]]; then
        log "${YELLOW}SSD detected. Optimizing disk I/O...${NC}"
        sudo bash -c "echo 'noop' > /sys/block/$(lsblk -nd -o name)/queue/scheduler"
        sudo bash -c "echo 'vm.dirty_background_ratio = 5' >> /etc/sysctl.conf"
        sudo bash -c "echo 'vm.dirty_ratio = 10' >> /etc/sysctl.conf"
        sudo sysctl -p
    fi

    log "${GREEN}System-wide optimization complete!${NC}"
}

# Function to check disk space
check_disk_space() {
    local required_space=2048 # 2GB in MB
    local available_space=$(df -m / | awk 'NR==2 {print $4}')

    if [[ $available_space -lt $required_space ]]; then
        echo -e "${RED}Insufficient disk space. At least 2GB of free space is required.${NC}"
        exit 1
    fi
}

# Function to install dependencies
install_dependencies() {
    log "${YELLOW}Installing dependencies...${NC}"
    retry_command "sudo apt update"
    retry_command "sudo apt install software-properties-common git curl -y"
    retry_command "sudo apt install python3-dev python3-setuptools python3-venv python3-pip redis-server -y"
}

# Function to install Python 3.10
install_python() {
    log "${YELLOW}Installing Python 3.10...${NC}"
    retry_command "sudo apt -qq install build-essential zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev libssl-dev libreadline-dev libffi-dev libsqlite3-dev wget libbz2-dev -y"
    retry_command "wget https://www.python.org/ftp/python/3.10.11/Python-3.10.11.tgz"
    tar -xf Python-3.10.11.tgz
    cd Python-3.10.11
    ./configure --prefix=/usr/local --enable-optimizations --enable-shared LDFLAGS="-Wl,-rpath /usr/local/lib"
    make -j $(nproc)
    sudo make altinstall
    cd ..
    sudo rm -rf Python-3.10.11
    sudo rm Python-3.10.11.tgz
    pip3.10 install --user --upgrade pip
    log "${GREEN}Python3.10 installation successful!${NC}"
}

# Function to install wkhtmltox
install_wkhtmltox() {
    log "${YELLOW}Installing wkhtmltox...${NC}"
    local arch=$(uname -m)
    case $arch in
        x86_64) arch="amd64" ;;
        aarch64) arch="arm64" ;;
        *) log "${RED}Unsupported architecture: $arch${NC}"; exit 1 ;;
    esac

    retry_command "wget https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-2/wkhtmltox_0.12.6.1-2.jammy_$arch.deb"
    retry_command "sudo dpkg -i wkhtmltox_0.12.6.1-2.jammy_$arch.deb || true"
    sudo cp /usr/local/bin/wkhtmlto* /usr/bin/
    sudo chmod a+x /usr/bin/wk*
    sudo rm wkhtmltox_0.12.6.1-2.jammy_$arch.deb
    retry_command "sudo apt --fix-broken install -y"
    retry_command "sudo apt install fontconfig xvfb libfontconfig xfonts-base xfonts-75dpi libxrender1 -y"
    log "${GREEN}wkhtmltox installation successful!${NC}"
}

# Function to install MariaDB
install_mariadb() {
    log "${YELLOW}Installing MariaDB...${NC}"
    retry_command "sudo apt install mariadb-server mariadb-client -y"
    log "${GREEN}MariaDB installation successful!${NC}"
}

# Function to configure MariaDB
configure_mariadb() {
    log "${YELLOW}Configuring MariaDB...${NC}"
    sqlpasswrd=$(ask_twice "Enter the MariaDB root password" "true")
    retry_command "sudo mysql -e \"ALTER USER 'root'@'localhost' IDENTIFIED BY '$sqlpasswrd';\""
    retry_command "sudo mysql -u root -p\"$sqlpasswrd\" -e \"ALTER USER 'root'@'localhost' IDENTIFIED BY '$sqlpasswrd';\""
    retry_command "sudo mysql -u root -p\"$sqlpasswrd\" -e \"DELETE FROM mysql.user WHERE User='';\""
    retry_command "sudo mysql -u root -p\"$sqlpasswrd\" -e \"DROP DATABASE IF EXISTS test;DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';\""
    retry_command "sudo mysql -u root -p\"$sqlpasswrd\" -e \"FLUSH PRIVILEGES;\""

    sudo bash -c 'cat << EOF >> /etc/mysql/my.cnf
[mysqld]
character-set-client-handshake = FALSE
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci

[mysql]
default-character-set = utf8mb4
EOF'

    retry_command "sudo service mysql restart"
    log "${GREEN}MariaDB configuration successful!${NC}"
}

# Function to install Node.js, and Yarn
install_nodejs() {
    log "${YELLOW}Installing Node.js, and Yarn...${NC}"

    # Install NVM
    retry_command "curl https://raw.githubusercontent.com/creationix/nvm/master/install.sh | bash"

    # Install Node.js based on bench version
    if [[ "$bench_version" == "version-15" ]]; then
        retry_command "nvm install 18"
        node_version="18"
    else
        retry_command "nvm install 16"
        node_version="16"
    fi

    # Install Yarn
    retry_command "sudo apt-get -qq install npm -y"
    retry_command "sudo npm install -g yarn"

    log "${GREEN}Node.js and Yarn installation successful!${NC}"
}

# Function to install Bench
install_bench() {
    log "${YELLOW}Installing Bench...${NC}"
    retry_command "sudo apt install python3-pip -y"
    retry_command "sudo pip3 install frappe-bench"
    log "${GREEN}Bench installation successful!${NC}"
}

# Function to initialize Bench
initialize_bench() {
    log "${YELLOW}Initializing Bench...${NC}"
    retry_command "bench init frappe-bench --version $bench_version --verbose"
    log "${GREEN}Bench initialization successful!${NC}"
}

# Function to create a new site
create_site() {
    log "${YELLOW}Creating new site...${NC}"
    retry_command "bench new-site $site_name --db-root-password $sqlpasswrd --admin-password $adminpasswrd"
    log "${GREEN}Site creation successful!${NC}"
}

# Function to install ERPNext
install_erpnext() {
    log "${YELLOW}Installing ERPNext...${NC}"
    retry_command "bench get-app erpnext --branch $bench_version"
    retry_command "bench --site $site_name install-app erpnext"
    log "${GREEN}ERPNext installation successful!${NC}"
}

# Function to configure production environment
configure_production() {
    log "${YELLOW}Configuring production environment...${NC}"
    yes | sudo bench setup production $USER
    retry_command "sudo service supervisor restart"
    retry_command "bench --site $site_name scheduler enable"
    retry_command "bench --site $site_name scheduler resume"
    if [[ "$bench_version" == "version-15" ]]; then
        retry_command "bench setup socketio"
        yes | bench setup supervisor
        retry_command "bench setup redis"
        retry_command "sudo supervisorctl reload"
    fi
    log "${GREEN}Production configuration successful!${NC}"
}

# Function to install SSL
install_ssl() {
    log "${YELLOW}Installing SSL certificate...${NC}"
    retry_command "sudo apt install snapd -y"
    retry_command "sudo snap install core"
    retry_command "sudo snap refresh core"
    retry_command "sudo snap install --classic certbot"
    retry_command "sudo ln -s /snap/bin/certbot /usr/bin/certbot"
    retry_command "sudo certbot --nginx --non-interactive --agree-tos --email $email_address -d $site_name"
    log "${GREEN}SSL certificate installation successful!${NC}"
}

# Function to clean up temporary files
cleanup() {
    log "${YELLOW}Cleaning up temporary files...${NC}"
    rm -rf $temp_dir
    log "${GREEN}Cleanup complete!${NC}"
}

# Main script execution
log "${LIGHT_BLUE}Welcome to the ERPNext Installer...${NC}"
sleep 2

# Check disk space
check_disk_space

# Create temporary workspace
temp_dir=$(mktemp -d)
cd $temp_dir

# Install dependencies
install_dependencies

# Install Python 3.10 if required
py_version=$(python3 --version 2>&1 | awk '{print $2}')
py_major=$(echo "$py_version" | cut -d '.' -f 1)
py_minor=$(echo "$py_version" | cut -d '.' -f 2)

if [ -z "$py_version" ] || [ "$py_major" -lt 3 ] || [ "$py_major" -eq 3 -a "$py_minor" -lt 10 ]; then
    install_python
fi

# Install wkhtmltox
install_wkhtmltox

# Install MariaDB
install_mariadb

# Configure MariaDB
configure_mariadb

# Install NVM, Node.js, and Yarn
install_nodejs

# Install Bench
install_bench

# Initialize Bench
initialize_bench

# Prompt user for site name
log "${YELLOW}Preparing for Production installation. This could take a minute... or two so please be patient.${NC}"
read -p "Enter the site name (If you wish to install SSL later, please enter a FQDN): " site_name
while ! validate_domain "$site_name"; do
    read -p "Enter the site name (If you wish to install SSL later, please enter a FQDN): " site_name
done
sleep 1
adminpasswrd=$(ask_twice "Enter the Administrator password" "true")
while ! validate_password "$adminpasswrd"; do
    adminpasswrd=$(ask_twice "Enter the Administrator password" "true")
done
echo -e "\n"
sleep 2

# Create a new site
create_site

# Install ERPNext
install_erpnext

# Configure production environment
configure_production

# Install SSL if requested
log "${YELLOW}Would you like to install SSL? (yes/no)${NC}"
read -p "Response: " continue_ssl
continue_ssl=$(echo "$continue_ssl" | tr '[:upper:]' '[:lower:]')

case "$continue_ssl" in
    "yes" | "y")
        read -p "Enter your email address: " email_address
        install_ssl
        ;;
    *)
        log "${RED}Skipping SSL installation...${NC}"
        sleep 3
        ;;
esac

# Clean up temporary files
cleanup

# Display installation summary
log "${GREEN}--------------------------------------------------------------------------------"
log "Congratulations! You have successfully installed ERPNext $version_choice."
log "You can start using your new ERPNext installation by visiting https://$site_name"
log "(if you have enabled SSL and used a Fully Qualified Domain Name"
log "during installation) or http://$server_ip to begin."
log "Install additional apps as required. Visit https://docs.erpnext.com for Documentation."
log "Enjoy using ERPNext!"
log "--------------------------------------------------------------------------------${NC}"

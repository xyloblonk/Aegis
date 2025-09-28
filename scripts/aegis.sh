#!/bin/bash

# Aegis Advanced Backup Automator - Guided Setup for Cloud Backups
# Author: XyloBlonk
# Version: 2.0

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

CONFIG_DIR="/etc/aegis-backup"
LOG_DIR="/var/log/aegis-backup"
BACKUP_SCRIPTS_DIR="/usr/local/bin/aegis"
CRON_DIR="/etc/cron.d"
TEMP_DIR="/tmp/aegis-setup"
BACKUP_ROOT="/backups"
MONITORING_DIR="/var/lib/aegis-monitoring"

declare -A PROVIDERS
declare -A BACKUP_JOBS
declare -A BACKEND_CONFIGS
CURRENT_STEP=0
TOTAL_STEPS=0

PROVIDERS=(
    ["s3"]="Amazon S3"
    ["b2"]="Backblaze B2" 
    ["gcs"]="Google Cloud Storage"
    ["wasabi"]="Wasabi"
    ["digitalocean"]="DigitalOcean Spaces"
    ["minio"]="MinIO"
    ["ftp"]="FTP/FTPS"
    ["sftp"]="SFTP"
)

BACKENDS=(
    ["traditional"]="Traditional (tar/gzip)"
    ["borg"]="BorgBackup (Deduplicating)"
    ["restic"]="Restic (Encrypted Deduplication)"
)

print_header() {
    clear
    echo -e "${PURPLE}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                   AEGIS BACKUP AUTOMATOR                    ║"
    echo "║                 Advanced Backup System v2.0                 ║"
    echo "║                  -------------------------                  ║"
    echo "║                github.com/xyloblonk/aegis                   ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "${CYAN}Features: Incremental Backups • Borg/Restic • Parallel Uploads • Monitoring${NC}"
    echo
}

init_directories() {
    echo -e "${BLUE}${BOLD}[1/${TOTAL_STEPS}] Initializing system directories...${NC}"
    
    mkdir -p "$CONFIG_DIR"/{providers,backups,encryption,templates,backends} \
             "$LOG_DIR" "$BACKUP_SCRIPTS_DIR" "$TEMP_DIR" "$BACKUP_ROOT" \
             "$MONITORING_DIR"
    
    chmod 750 "$CONFIG_DIR" "$LOG_DIR" "$BACKUP_ROOT" "$MONITORING_DIR"
    chmod 700 "$CONFIG_DIR/encryption" "$TEMP_DIR"
    
    echo -e "${GREEN}✓ Directory structure created${NC}"
}

check_dependencies() {
    echo -e "${BLUE}${BOLD}[2/${TOTAL_STEPS}] Checking system dependencies...${NC}"
    
    local deps=("curl" "tar" "gzip" "openssl" "jq" "crontab" "parallel")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${YELLOW}Installing missing dependencies: ${missing[*]}${NC}"
        apt-get update > /dev/null 2>&1
        apt-get install -y "${missing[@]}" > /dev/null 2>&1
    fi
    
    if ! command -v aws &> /dev/null; then
        echo -e "${YELLOW}Installing AWS CLI...${NC}"
        apt-get install -y awscli > /dev/null 2>&1
    fi
    
    echo -e "${GREEN}✓ All dependencies satisfied${NC}"
}

install_backup_backends() {
    echo -e "${BLUE}${BOLD}[3/${TOTAL_STEPS}] Installing backup backends...${NC}"
    
    if ! command -v borg &> /dev/null; then
        echo -e "${YELLOW}Installing BorgBackup...${NC}"
        apt-get install -y borgbackup > /dev/null 2>&1
    fi
    
    if ! command -v restic &> /dev/null; then
        echo -e "${YELLOW}Installing Restic...${NC}"
        wget -q https://github.com/restic/restic/releases/latest/download/restic_linux_amd64.bz2
        bzip2 -d restic_linux_amd64.bz2
        chmod +x restic_linux_amd64
        mv restic_linux_amd64 /usr/local/bin/restic
    fi
    
    echo -e "${GREEN}✓ Backup backends installed${NC}"
}

print_step() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    echo -e "\n${CYAN}${BOLD}Step ${CURRENT_STEP}/${TOTAL_STEPS}: $1${NC}"
}

prompt() {
    local prompt_text="$1"
    local var_name="$2"
    local default="${3:-}"
    local required="${4:-false}"
    
    while true; do
        if [ -n "$default" ]; then
            read -p "$prompt_text [$default]: " input
            input="${input:-$default}"
        else
            read -p "$prompt_text: " input
        fi
        
        if [ "$required" = "true" ] && [ -z "$input" ]; then
            echo -e "${RED}This field is required. Please enter a value.${NC}"
        else
            break
        fi
    done
    
    eval "$var_name=\"$input\""
}

prompt_password() {
    local prompt_text="$1"
    local var_name="$2"
    local confirm="${3:-false}"
    
    while true; do
        read -s -p "$prompt_text: " password
        echo
        if [ -z "$password" ]; then
            echo -e "${RED}Password cannot be empty.${NC}"
            continue
        fi
        
        if [ "$confirm" = "true" ]; then
            read -s -p "Confirm password: " password_confirm
            echo
            if [ "$password" != "$password_confirm" ]; then
                echo -e "${RED}Passwords do not match. Please try again.${NC}"
                continue
            fi
        fi
        break
    done
    
    eval "$var_name=\"$password\""
}

prompt_yes_no() {
    local prompt_text="$1"
    local var_name="$2"
    local default="${3:-yes}"
    
    while true; do
        read -p "$prompt_text [y/n] ($default): " input
        input="${input:-$default}"
        case "${input,,}" in
            y|yes) eval "$var_name=true"; break ;;
            n|no) eval "$var_name=false"; break ;;
            *) echo -e "${RED}Please enter y or n${NC}" ;;
        esac
    done
}

select_option() {
    local prompt_text="$1"
    local options=("${!2}")
    local var_name="$3"
    
    echo -e "\n${prompt_text}"
    for i in "${!options[@]}"; do
        echo "  $((i+1))) ${options[$i]}"
    done
    
    while true; do
        read -p "Enter your choice [1-${#options[@]}]: " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#options[@]}" ]; then
            eval "$var_name=\"${options[$((choice-1))]}\""
            break
        else
            echo -e "${RED}Invalid choice. Please enter a number between 1 and ${#options[@]}${NC}"
        fi
    done
}

select_backup_backend() {
    print_step "Select Backup Backend Technology"
    
    echo -e "\n${BOLD}Available Backup Backends:${NC}"
    echo -e "  ${GREEN}Traditional${NC}: Simple tar/gzip backups (full backups only)"
    echo -e "  ${GREEN}BorgBackup${NC}: Deduplicating backups with compression and encryption"
    echo -e "  ${GREEN}Restic${NC}: Encrypted, deduplicated backups with cloud support"
    
    local backend_names=()
    for key in "${!BACKENDS[@]}"; do
        backend_names+=("${BACKENDS[$key]}")
    done
    
    select_option "Choose your backup backend:" backend_names[@] SELECTED_BACKEND_NAME
    
    for key in "${!BACKENDS[@]}"; do
        if [ "${BACKENDS[$key]}" = "$SELECTED_BACKEND_NAME" ]; then
            BACKEND_KEY="$key"
            break
        fi
    done
    
    echo -e "${GREEN}Selected: ${SELECTED_BACKEND_NAME}${NC}"
}

configure_backend() {
    case "$BACKEND_KEY" in
        borg)
            configure_borg_backend ;;
        restic)
            configure_restic_backend ;;
        traditional)
            configure_traditional_backend ;;
    esac
}

configure_borg_backend() {
    print_step "Configuring BorgBackup"
    
    prompt "Enter Borg repository path (local or ssh)" BORG_REPO "" true
    prompt_password "Enter Borg encryption passphrase" BORG_PASSPHRASE true
    
    BACKEND_CONFIGS["type"]="borg"
    BACKEND_CONFIGS["repo"]="$BORG_REPO"
    BACKEND_CONFIGS["passphrase"]="$BORG_PASSPHRASE"
    
    echo -e "\n${YELLOW}Initializing Borg repository...${NC}"
    export BORG_PASSPHRASE="$BORG_PASSPHRASE"
    borg init --encryption=repokey "$BORG_REPO" 2>/dev/null || true
    
    echo -e "${GREEN}✓ BorgBackup configured${NC}"
}

configure_restic_backend() {
    print_step "Configuring Restic"
    
    prompt_password "Enter Restic repository password" RESTIC_PASSWORD true
    
    BACKEND_CONFIGS["type"]="restic"
    BACKEND_CONFIGS["password"]="$RESTIC_PASSWORD"
    
    echo -e "${GREEN}✓ Restic configured${NC}"
}

configure_traditional_backend() {
    print_step "Configuring Traditional Backups"
    
    prompt_yes_no "Enable incremental backups?" ENABLE_INCREMENTAL true
    prompt_yes_no "Enable differential backups?" ENABLE_DIFFERENTIAL false
    
    BACKEND_CONFIGS["type"]="traditional"
    BACKEND_CONFIGS["incremental"]="$ENABLE_INCREMENTAL"
    BACKEND_CONFIGS["differential"]="$ENABLE_DIFFERENTIAL"
    
    echo -e "${GREEN}✓ Traditional backups configured${NC}"
}

select_provider() {
    print_step "Select Cloud Storage Provider"
    
    echo -e "\n${BOLD}Available Cloud Storage Providers:${NC}"
    local provider_names=()
    for key in "${!PROVIDERS[@]}"; do
        provider_names+=("${PROVIDERS[$key]}")
    done
    
    select_option "Choose your cloud storage provider:" provider_names[@] SELECTED_PROVIDER_NAME
    
    for key in "${!PROVIDERS[@]}"; do
        if [ "${PROVIDERS[$key]}" = "$SELECTED_PROVIDER_NAME" ]; then
            PROVIDER_KEY="$key"
            break
        fi
    done
    
    echo -e "${GREEN}Selected: ${SELECTED_PROVIDER_NAME}${NC}"
}

configure_provider() {
    case "$PROVIDER_KEY" in
        s3|wasabi|digitalocean|minio)
            configure_s3_compatible ;;
        b2)
            configure_b2 ;;
        gcs)
            configure_gcs ;;
        ftp)
            configure_ftp ;;
        sftp)
            configure_sftp ;;
    esac
}

configure_s3_compatible() {
    print_step "Configure ${SELECTED_PROVIDER_NAME} Connection"
    
    local endpoint_map=(
        ["s3"]="s3.amazonaws.com"
        ["wasabi"]="s3.wasabisys.com" 
        ["digitalocean"]="nyc3.digitaloceanspaces.com"
        ["minio"]=""
    )
    
    prompt "Enter Access Key ID" ACCESS_KEY "" true
    prompt_password "Enter Secret Access Key" SECRET_KEY
    prompt "Enter Bucket Name" BUCKET_NAME "" true
    prompt "Enter bucket region" REGION "us-east-1"
    
    if [ -n "${endpoint_map[$PROVIDER_KEY]}" ]; then
        ENDPOINT="${endpoint_map[$PROVIDER_KEY]}"
    else
        prompt "Enter S3 endpoint URL" ENDPOINT "" true
    fi
    
    prompt "Enter backup path in bucket" BACKUP_PATH "backups/"
    prompt "Number of parallel uploads" PARALLEL_UPLOADS "4"
    
    echo -e "\n${YELLOW}Testing connection to ${SELECTED_PROVIDER_NAME}...${NC}"
    if test_s3_connection; then
        echo -e "${GREEN}✓ Connection successful${NC}"
    else
        echo -e "${RED}✗ Connection failed${NC}"
        prompt_yes_no "Continue anyway?" CONTINUE_SETUP
        if ! $CONTINUE_SETUP; then
            exit 1
        fi
    fi
    
    save_s3_config
}

test_s3_connection() {
    local date_iso=$(date -u +"%a, %d %b %Y %T %Z")
    local resource="/${BUCKET_NAME}/"
    local string_to_sign="HEAD\n\n\n${date_iso}\n${resource}"
    local signature=$(echo -en "${string_to_sign}" | openssl sha1 -hmac "${SECRET_KEY}" -binary | base64)
    
    curl -I -s --max-time 10 \
        -H "Host: ${ENDPOINT}" \
        -H "Date: ${date_iso}" \
        -H "Authorization: AWS ${ACCESS_KEY}:${signature}" \
        "https://${ENDPOINT}${resource}" | head -1 | grep -q "200\|404"
}

save_s3_config() {
    cat > "$CONFIG_DIR/providers/${PROVIDER_KEY}.conf" << EOF
PROVIDER_TYPE="s3"
S3_ENDPOINT="${ENDPOINT}"
S3_ACCESS_KEY="${ACCESS_KEY}"
S3_SECRET_KEY="${SECRET_KEY}"
S3_BUCKET="${BUCKET_NAME}"
S3_REGION="${REGION}"
S3_PATH="${BACKUP_PATH}"
PARALLEL_UPLOADS="${PARALLEL_UPLOADS}"
EOF
    chmod 600 "$CONFIG_DIR/providers/${PROVIDER_KEY}.conf"
}

configure_b2() {
    print_step "Configure Backblaze B2 Connection"
    
    prompt "Enter B2 Account ID" B2_ACCOUNT_ID "" true
    prompt "Enter B2 Application Key" B2_APPLICATION_KEY "" true
    prompt "Enter B2 Bucket Name" B2_BUCKET "" true
    prompt "Enter backup path in bucket" B2_PATH "backups/"
    prompt "Number of parallel uploads" PARALLEL_UPLOADS "4"
    
    echo -e "\n${YELLOW}Testing B2 connection...${NC}"
    if test_b2_connection; then
        echo -e "${GREEN}✓ B2 connection successful${NC}"
    else
        echo -e "${RED}✗ B2 connection failed${NC}"
        prompt_yes_no "Continue anyway?" CONTINUE_SETUP
    fi
    
    cat > "$CONFIG_DIR/providers/b2.conf" << EOF
PROVIDER_TYPE="b2"
B2_ACCOUNT_ID="${B2_ACCOUNT_ID}"
B2_APPLICATION_KEY="${B2_APPLICATION_KEY}"
B2_BUCKET="${B2_BUCKET}"
B2_PATH="${B2_PATH}"
PARALLEL_UPLOADS="${PARALLEL_UPLOADS}"
EOF
    chmod 600 "$CONFIG_DIR/providers/b2.conf"
}

test_b2_connection() {
    local response=$(curl -s --max-time 10 \
        -u "${B2_ACCOUNT_ID}:${B2_APPLICATION_KEY}" \
        "https://api.backblazeb2.com/b2api/v2/b2_authorize_account")
    
    echo "$response" | jq -e '.accountId' > /dev/null 2>&1
}

configure_backup_sources() {
    print_step "Configure What to Backup"
    
    echo -e "\n${BOLD}What would you like to backup?${NC}"
    
    prompt_yes_no "Backup files and directories?" BACKUP_FILES
    prompt_yes_no "Backup MySQL databases?" BACKUP_MYSQL
    prompt_yes_no "Backup PostgreSQL databases?" BACKUP_POSTGRES
    prompt_yes_no "Backup Docker volumes?" BACKUP_DOCKER
    prompt_yes_no "Backup system configuration?" BACKUP_SYSTEM
    
    if $BACKUP_FILES; then
        configure_file_backups
    fi
    
    if $BACKUP_MYSQL; then
        configure_mysql_backups
    fi
    
    if $BACKUP_POSTGRES; then
        configure_postgresql_backups
    fi
    
    if $BACKUP_DOCKER; then
        configure_docker_backups
    fi
    
    if $BACKUP_SYSTEM; then
        configure_system_backups
    fi
}

configure_file_backups() {
    print_step "Configure File and Directory Backups"
    
    local backup_count=0
    
    while true; do
        echo -e "\n${BOLD}File Backup #$((backup_count + 1))${NC}"
        
        local name=""
        local path=""
        local excludes=""
        
        prompt "Enter name for this backup" name "" true
        prompt "Enter directory path to backup" path "" true
        
        if [ ! -d "$path" ]; then
            echo -e "${YELLOW}Warning: Directory '$path' does not exist${NC}"
            prompt_yes_no "Continue anyway?" CONTINUE_BACKUP
            if ! $CONTINUE_BACKUP; then
                continue
            fi
        fi
        
        prompt "Enter exclude patterns (comma-separated)" excludes "*.log,*.tmp,cache,node_modules"
        
        BACKUP_JOBS["files_${backup_count}"]="type=files;name=${name};path=${path};excludes=${excludes}"
        
        backup_count=$((backup_count + 1))
        
        prompt_yes_no "Add another directory to backup?" ADD_ANOTHER
        if ! $ADD_ANOTHER; then
            break
        fi
    done
}

configure_mysql_backups() {
    print_step "Configure MySQL Database Backups"
    
    prompt_yes_no "Backup all MySQL databases automatically?" MYSQL_BACKUP_ALL true
    
    if ! $MYSQL_BACKUP_ALL; then
        prompt "Enter database names (comma-separated)" MYSQL_DATABASES "" true
    fi
    
    prompt "Enter MySQL username" MYSQL_USER "root"
    prompt_password "Enter MySQL password" MYSQL_PASSWORD
    
    echo -e "\n${YELLOW}Testing MySQL connection...${NC}"
    if mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "SHOW DATABASES;" &> /dev/null; then
        echo -e "${GREEN}✓ MySQL connection successful${NC}"
    else
        echo -e "${RED}✗ MySQL connection failed${NC}"
        prompt_yes_no "Continue anyway?" CONTINUE_MYSQL
        if ! $CONTINUE_MYSQL; then
            return
        fi
    fi
    
    BACKUP_JOBS["mysql"]="type=mysql;user=${MYSQL_USER};password=${MYSQL_PASSWORD};backup_all=${MYSQL_BACKUP_ALL};databases=${MYSQL_DATABASES}"
}

configure_postgresql_backups() {
    print_step "Configure PostgreSQL Database Backups"
    
    prompt_yes_no "Backup all PostgreSQL databases automatically?" POSTGRES_BACKUP_ALL true
    
    if ! $POSTGRES_BACKUP_ALL; then
        prompt "Enter database names (comma-separated)" POSTGRES_DATABASES "" true
    fi
    
    prompt "Enter PostgreSQL username" POSTGRES_USER "postgres"
    
    echo -e "\n${YELLOW}Testing PostgreSQL connection...${NC}"
    if sudo -u postgres psql -c "\l" &> /dev/null; then
        echo -e "${GREEN}✓ PostgreSQL connection successful${NC}"
    else
        echo -e "${YELLOW}Note: Running as current user${NC}"
    fi
    
    BACKUP_JOBS["postgresql"]="type=postgresql;user=${POSTGRES_USER};backup_all=${POSTGRES_BACKUP_ALL};databases=${POSTGRES_DATABASES}"
}

configure_monitoring() {
    print_step "Configure Monitoring and Alerting"
    
    prompt_yes_no "Enable Prometheus metrics export?" ENABLE_PROMETHEUS true
    prompt_yes_no "Enable email alerts?" ENABLE_EMAIL_ALERTS false
    prompt_yes_no "Enable Slack alerts?" ENABLE_SLACK_ALERTS false
    
    if $ENABLE_EMAIL_ALERTS; then
        prompt "Enter email address for alerts" ALERT_EMAIL "" true
        prompt "Enter SMTP server" SMTP_SERVER "localhost"
        prompt "Enter SMTP port" SMTP_PORT "25"
    fi
    
    if $ENABLE_SLACK_ALERTS; then
        prompt "Enter Slack webhook URL" SLACK_WEBHOOK "" true
    fi
    
    # Save monitoring configuration
    cat > "$CONFIG_DIR/monitoring.conf" << EOF
ENABLE_PROMETHEUS="${ENABLE_PROMETHEUS}"
ENABLE_EMAIL_ALERTS="${ENABLE_EMAIL_ALERTS}"
ENABLE_SLACK_ALERTS="${ENABLE_SLACK_ALERTS}"
ALERT_EMAIL="${ALERT_EMAIL}"
SMTP_SERVER="${SMTP_SERVER}"
SMTP_PORT="${SMTP_PORT}"
SLACK_WEBHOOK="${SLACK_WEBHOOK}"
EOF
    
    echo -e "${GREEN}✓ Monitoring configured${NC}"
}

configure_scheduling() {
    print_step "Configure Backup Schedule"
    
    echo -e "\n${BOLD}Available Schedule Options:${NC}"
    local schedule_options=(
        "Hourly (every hour)"
        "Daily (at 2 AM)"
        "Weekly (Sunday at 3 AM)" 
        "Custom (configure manually)"
    )
    
    select_option "Choose backup frequency:" schedule_options[@] SCHEDULE_CHOICE
    
    case "$SCHEDULE_CHOICE" in
        "Hourly"*)
            CRON_SCHEDULE="0 * * * *" ;;
        "Daily"*)
            CRON_SCHEDULE="0 2 * * *" ;;
        "Weekly"*)
            CRON_SCHEDULE="0 3 * * 0" ;;
        "Custom"*)
            configure_custom_schedule ;;
    esac
    
    echo -e "${GREEN}Schedule: ${CRON_SCHEDULE}${NC}"
}

configure_custom_schedule() {
    echo -e "\n${BOLD}Custom Cron Schedule${NC}"
    echo "Format: minute hour day month weekday"
    echo "Examples:"
    echo "  '0 2 * * *'  - Daily at 2 AM"
    echo "  '0 3 * * 0'  - Weekly on Sunday at 3 AM"
    echo "  '0 */6 * * *' - Every 6 hours"
    
    prompt "Enter cron schedule" CRON_SCHEDULE "0 2 * * *" true
}

configure_retention() {
    print_step "Configure Retention Policy"
    
    prompt "Keep hourly backups for (hours)" RETAIN_HOURLY "24"
    prompt "Keep daily backups for (days)" RETAIN_DAILY "7"
    prompt "Keep weekly backups for (weeks)" RETAIN_WEEKLY "4"
    prompt "Keep monthly backups for (months)" RETAIN_MONTHLY "12"
    
    cat > "$CONFIG_DIR/retention.conf" << EOF
RETAIN_HOURLY=${RETAIN_HOURLY}
RETAIN_DAILY=${RETAIN_DAILY}
RETAIN_WEEKLY=${RETAIN_WEEKLY}
RETAIN_MONTHLY=${RETAIN_MONTHLY}
EOF
}

generate_backup_scripts() {
    print_step "Generating Backup Scripts"
    
    create_main_backup_script
    create_upload_script
    create_restore_script
    create_monitoring_script
    create_cron_job
    
    echo -e "${GREEN}✓ All scripts generated${NC}"
}

create_main_backup_script() {
    cat > "$BACKUP_SCRIPTS_DIR/run_backup.sh" << 'EOF'
#!/bin/bash

# Aegis Main Backup Script
# Generated by Aegis Backup Automator
# github.com/xyloblonk/aegis

set -euo pipefail

CONFIG_DIR="/etc/aegis-backup"
LOG_DIR="/var/log/aegis-backup"
BACKUP_ROOT="/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$BACKUP_ROOT/$TIMESTAMP"
MONITORING_DIR="/var/lib/aegis-monitoring"

source "$CONFIG_DIR/backends/main.conf"
source "$CONFIG_DIR/retention.conf"

mkdir -p "$BACKUP_DIR" "$LOG_DIR" "$MONITORING_DIR"
LOG_FILE="$LOG_DIR/backup_${TIMESTAMP}.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*" | tee -a "$LOG_FILE"
    exit 1
}

send_alert() {
    local level="$1"
    local message="$2"
    
    # Implementation for alerts would go here
    log "ALERT $level: $message"
}

incremental_backup() {
    local source_dir="$1"
    local backup_name="$2"
    local snapshot_file="$CONFIG_DIR/backups/${backup_name}.snapshot"
    
    if [ -f "$snapshot_file" ]; then
        log "Performing incremental backup: $backup_name"
        tar --create --gzip --file="$BACKUP_DIR/${backup_name}_inc.tar.gz" \
            --listed-incremental="$snapshot_file" \
            --directory="$source_dir" . || error "Incremental backup failed"
    else
        log "Performing full backup (no snapshot found): $backup_name"
        tar --create --gzip --file="$BACKUP_DIR/${backup_name}_full.tar.gz" \
            --listed-incremental="$snapshot_file" \
            --directory="$source_dir" . || error "Full backup failed"
    fi
}

borg_backup() {
    local source_dir="$1"
    local backup_name="$2"
    
    export BORG_PASSPHRASE="${BACKEND_CONFIGS["passphrase"]}"
    local repo="${BACKEND_CONFIGS["repo"]}"
    
    log "Performing Borg backup: $backup_name"
    borg create --compression lz4 --stats \
        "$repo::${backup_name}-{now}" \
        "$source_dir" || error "Borg backup failed"
}

restic_backup() {
    local source_dir="$1"
    local backup_name="$2"
    
    export RESTIC_PASSWORD="${BACKEND_CONFIGS["password"]}"
    local repo="${BACKEND_CONFIGS["repo"]}"
    
    log "Performing Restic backup: $backup_name"
    restic -r "$repo" backup "$source_dir" \
        --tag "$backup_name" || error "Restic backup failed"
}

create_backup() {
    log "Starting backup process with backend: ${BACKEND_CONFIGS["type"]}"
    
    case "${BACKEND_CONFIGS["type"]}" in
        traditional)
            for job_key in "${!BACKUP_JOBS[@]}"; do
                if [[ "$job_key" == files_* ]]; then
                    IFS=';' read -r -a job <<< "${BACKUP_JOBS[$job_key]}"
                    declare -A job_map
                    for item in "${job[@]}"; do
                        IFS='=' read -r key value <<< "$item"
                        job_map["$key"]="$value"
                    done
                    
                    if [ "${BACKEND_CONFIGS["incremental"]}" = "true" ]; then
                        incremental_backup "${job_map["path"]}" "${job_map["name"]}"
                    else
                        log "Backing up files: ${job_map["name"]}"
                        tar --exclude="${job_map["excludes"]}" \
                            -czf "$BACKUP_DIR/files_${job_map["name"]}.tar.gz" \
                            -C "${job_map["path"]}" . || error "File backup failed"
                    fi
                fi
            done
            ;;
        borg)
            for job_key in "${!BACKUP_JOBS[@]}"; do
                if [[ "$job_key" == files_* ]]; then
                    IFS=';' read -r -a job <<< "${BACKUP_JOBS[$job_key]}"
                    declare -A job_map
                    for item in "${job[@]}"; do
                        IFS='=' read -r key value <<< "$item"
                        job_map["$key"]="$value"
                    done
                    borg_backup "${job_map["path"]}" "${job_map["name"]}"
                fi
            done
            ;;
        restic)
            for job_key in "${!BACKUP_JOBS[@]}"; do
                if [[ "$job_key" == files_* ]]; then
                    IFS=';' read -r -a job <<< "${BACKUP_JOBS[$job_key]}"
                    declare -A job_map
                    for item in "${job[@]}"; do
                        IFS='=' read -r key value <<< "$item"
                        job_map["$key"]="$value"
                    done
                    restic_backup "${job_map["path"]}" "${job_map["name"]}"
                fi
            done
            ;;
    esac
    
    # Database backups (always traditional)
    if [ -n "${BACKUP_JOBS["mysql"]:-}" ]; then
        IFS=';' read -r -a mysql_job <<< "${BACKUP_JOBS["mysql"]}"
        declare -A mysql_map
        for item in "${mysql_job[@]}"; do
            IFS='=' read -r key value <<< "$item"
            mysql_map["$key"]="$value"
        done
        
        log "Backing up MySQL databases"
        if [ "${mysql_map["backup_all"]}" = "true" ]; then
            mysqldump -u"${mysql_map["user"]}" -p"${mysql_map["password"]}" \
                     --all-databases | gzip > "$BACKUP_DIR/mysql_all.sql.gz" \
                     || error "MySQL backup failed"
        else
            IFS=',' read -r -a dbs <<< "${mysql_map["databases"]}"
            for db in "${dbs[@]}"; do
                mysqldump -u"${mysql_map["user"]}" -p"${mysql_map["password"]}" \
                         "$db" | gzip > "$BACKUP_DIR/mysql_${db}.sql.gz" \
                         || error "MySQL backup failed for $db"
            done
        fi
    fi
    
    log "Backup creation completed"
}

update_metrics() {
    local status="$1"
    local size="$2"
    
    cat > "$MONITORING_DIR/backup_metrics.prom" << METRICS
# HELP aegis_backup_status Last backup status (0=success, 1=failure)
# TYPE aegis_backup_status gauge
aegis_backup_status $status

# HELP aegis_backup_size_bytes Size of last backup in bytes
# TYPE aegis_backup_size_bytes gauge
aegis_backup_size_bytes $size

# HELP aegis_backup_timestamp_seconds Timestamp of last backup
# TYPE aegis_backup_timestamp_seconds gauge
aegis_backup_timestamp_seconds $(date +%s)
METRICS
}

main() {
    local start_time=$(date +%s)
    
    trap 'error "Backup interrupted"; update_metrics 1 0; exit 1' INT TERM
    
    log "Starting Aegis backup process"
    
    create_backup
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local backup_size=$(du -sb "$BACKUP_DIR" 2>/dev/null | cut -f1)
    
    update_metrics 0 "$backup_size"
    
    log "Backup completed successfully in ${duration}s"
    log "Backup size: $(numfmt --to=iec $backup_size)"
    
    # Upload if using traditional backend
    if [ "${BACKEND_CONFIGS["type"]}" = "traditional" ]; then
        log "Uploading backup to cloud storage"
        "$BACKUP_SCRIPTS_DIR/upload_backup.sh" "$BACKUP_DIR"
    fi
    
    # Cleanup
    if [ "${BACKEND_CONFIGS["type"]}" = "traditional" ]; then
        log "Cleaning up local backup files"
        rm -rf "$BACKUP_DIR"
    fi
}

main "$@"
EOF

    chmod 700 "$BACKUP_SCRIPTS_DIR/run_backup.sh"
}

create_upload_script() {
    cat > "$BACKUP_SCRIPTS_DIR/upload_backup.sh" << 'EOF'
#!/bin/bash

# Aegis Parallel Upload Script
# Supports multiple cloud providers with parallel uploads
# Generated by Aegis Backup Automator
# github.com/xyloblonk/aegis

set -euo pipefail

BACKUP_DIR="$1"
CONFIG_DIR="/etc/aegis-backup"

if [ ! -d "$BACKUP_DIR" ]; then
    echo "Invalid backup directory: $BACKUP_DIR" >&2
    exit 1
fi

# Find provider config
PROVIDER_CONFIG=$(find "$CONFIG_DIR/providers" -name "*.conf" | head -1)
if [ ! -f "$PROVIDER_CONFIG" ]; then
    echo "No provider configuration found" >&2
    exit 1
fi

source "$PROVIDER_CONFIG"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

upload_file_s3() {
    local file="$1"
    local remote_path="${S3_PATH}/$(basename "$BACKUP_DIR")/$(basename "$file")"
    
    AWS_ACCESS_KEY_ID="$S3_ACCESS_KEY" \
    AWS_SECRET_ACCESS_KEY="$S3_SECRET_KEY" \
    aws s3 --endpoint-url "https://$S3_ENDPOINT" cp \
        "$file" "s3://$S3_BUCKET/$remote_path" --region "$S3_REGION" \
        --only-show-errors
}

upload_file_b2() {
    local file="$1"
    local remote_path="${B2_PATH}/$(basename "$BACKUP_DIR")/$(basename "$file")"
    
    b2 upload-file "$B2_BUCKET" "$file" "$remote_path" \
        --quiet
}

export -f upload_file_s3
export -f upload_file_b2
export S3_ENDPOINT S3_ACCESS_KEY S3_SECRET_KEY S3_BUCKET S3_PATH S3_REGION
export B2_ACCOUNT_ID B2_APPLICATION_KEY B2_BUCKET B2_PATH

log "Starting parallel upload with ${PARALLEL_UPLOADS:-4} workers"

find "$BACKUP_DIR" -type f | parallel -j "${PARALLEL_UPLOADS:-4}" "
    file={}
    log_file='/tmp/aegis_upload_\$(basename {}).log'
    
    case '$PROVIDER_TYPE' in
        s3)
            upload_file_s3 \"\$file\" 2> \"\$log_file\" ;;
        b2)
            upload_file_b2 \"\$file\" 2> \"\$log_file\" ;;
        *)
            echo 'Unsupported provider: $PROVIDER_TYPE' >&2
            exit 1 ;;
    esac
    
    if [ \$? -eq 0 ]; then
        echo \"✓ Uploaded: \$(basename \$file)\"
        rm -f \"\$log_file\"
    else
        echo \"✗ Failed: \$(basename \$file)\"
        cat \"\$log_file\"
        rm -f \"\$log_file\"
        exit 1
    fi
"

log "Parallel upload completed"
EOF

    chmod 700 "$BACKUP_SCRIPTS_DIR/upload_backup.sh"
}

create_restore_script() {
    cat > "$BACKUP_SCRIPTS_DIR/restore_backup.sh" << 'EOF'
#!/bin/bash

# Aegis Restore Script
# Supports restoration from all backup backends
# Generated by Aegis Backup Automator
# github.com/xyloblonk/aegis

set -euo pipefail

CONFIG_DIR="/etc/aegis-backup"
RESTORE_ROOT="/restore"
LOG_DIR="/var/log/aegis-backup"

source "$CONFIG_DIR/backends/main.conf"

mkdir -p "$RESTORE_ROOT" "$LOG_DIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

list_borg_archives() {
    export BORG_PASSPHRASE="${BACKEND_CONFIGS["passphrase"]}"
    local repo="${BACKEND_CONFIGS["repo"]}"
    
    borg list "$repo"
}

list_restic_snapshots() {
    export RESTIC_PASSWORD="${BACKEND_CONFIGS["password"]}"
    local repo="${BACKEND_CONFIGS["repo"]}"
    
    restic -r "$repo" snapshots
}

restore_borg() {
    local archive="$1"
    local target="$2"
    
    export BORG_PASSPHRASE="${BACKEND_CONFIGS["passphrase"]}"
    local repo="${BACKEND_CONFIGS["repo"]}"
    
    log "Restoring Borg archive: $archive"
    borg extract "$repo::$archive" --destination "$target"
}

restore_restic() {
    local snapshot="$1"
    local target="$2"
    
    export RESTIC_PASSWORD="${BACKEND_CONFIGS["password"]}"
    local repo="${BACKEND_CONFIGS["repo"]}"
    
    log "Restoring Restic snapshot: $snapshot"
    restic -r "$repo" restore "$snapshot" --target "$target"
}

case "${BACKEND_CONFIGS["type"]}" in
    borg)
        echo "Available Borg archives:"
        list_borg_archives
        echo
        read -p "Enter archive name to restore: " archive_name
        read -p "Enter restore target directory [$RESTORE_ROOT]: " restore_target
        restore_target="${restore_target:-$RESTORE_ROOT}"
        restore_borg "$archive_name" "$restore_target"
        ;;
    restic)
        echo "Available Restic snapshots:"
        list_restic_snapshots
        echo
        read -p "Enter snapshot ID to restore: " snapshot_id
        read -p "Enter restore target directory [$RESTORE_ROOT]: " restore_target
        restore_target="${restore_target:-$RESTORE_ROOT}"
        restore_restic "$snapshot_id" "$restore_target"
        ;;
    traditional)
        echo "Traditional backups can be restored manually from cloud storage"
        echo "Use the download functionality in the upload script to retrieve files"
        ;;
esac

log "Restore completed to: $restore_target"
EOF

    chmod 700 "$BACKUP_SCRIPTS_DIR/restore_backup.sh"
}

create_monitoring_script() {
    cat > "$BACKUP_SCRIPTS_DIR/monitoring_exporter.sh" << 'EOF'
#!/bin/bash

# Aegis Monitoring Exporter
# Provides Prometheus metrics for backup status
# Generated by Aegis Backup Automator
# github.com/xyloblonk/aegis

set -euo pipefail

MONITORING_DIR="/var/lib/aegis-monitoring"
CONFIG_DIR="/etc/aegis-backup"
PORT="9110"

if [ -f "$CONFIG_DIR/monitoring.conf" ]; then
    source "$CONFIG_DIR/monitoring.conf"
fi

generate_metrics() {
    local metrics_file="$MONITORING_DIR/backup_metrics.prom"
    
    if [ ! -f "$metrics_file" ]; then
        cat > "$metrics_file" << METRICS
# HELP aegis_backup_status Last backup status (0=success, 1=failure)
# TYPE aegis_backup_status gauge
aegis_backup_status 1

# HELP aegis_backup_size_bytes Size of last backup in bytes
# TYPE aegis_backup_size_bytes gauge
aegis_backup_size_bytes 0

# HELP aegis_backup_timestamp_seconds Timestamp of last backup
# TYPE aegis_backup_timestamp_seconds gauge
aegis_backup_timestamp_seconds 0
METRICS
    fi
    
    cat "$metrics_file"
    echo "# HELP aegis_exporter_up Aegis exporter is running"
    echo "# TYPE aegis_exporter_up gauge"
    echo "aegis_exporter_up 1"
}

start_http_server() {
    while true; do
        {
            echo -e "HTTP/1.1 200 OK\r"
            echo -e "Content-Type: text/plain; version=0.0.4\r"
            echo -e "Connection: close\r"
            echo -e "\r"
            generate_metrics
        } | nc -l -p "$PORT" -q 1
    done
}

case "${1:-}" in
    start)
        echo "Starting Aegis monitoring exporter on port $PORT"
        start_http_server
        ;;
    metrics)
        generate_metrics
        ;;
    *)
        echo "Usage: $0 {start|metrics}"
        exit 1
        ;;
esac
EOF

    chmod 700 "$BACKUP_SCRIPTS_DIR/monitoring_exporter.sh"
}

create_cron_job() {
    cat > "$CRON_DIR/aegis-backup" << EOF
# Aegis Backup Automator - Generated Cron Job
# github.com/xyloblonk/aegis
# Do not edit manually

${CRON_SCHEDULE} root $BACKUP_SCRIPTS_DIR/run_backup.sh >> $LOG_DIR/cron.log 2>&1

# Monitoring exporter - start on boot
@reboot root $BACKUP_SCRIPTS_DIR/monitoring_exporter.sh start >> $LOG_DIR/monitoring.log 2>&1

# Retention cleanup - runs daily at 1 AM
0 1 * * * root $BACKUP_SCRIPTS_DIR/cleanup_retention.sh >> $LOG_DIR/retention.log 2>&1
EOF

    echo -e "${GREEN}✓ Cron job installed${NC}"
}

finalize_setup() {
    print_step "Finalizing Setup"
    
    for key in "${!BACKUP_JOBS[@]}"; do
        echo "BACKUP_JOBS[$key]=\"${BACKUP_JOBS[$key]}\"" >> "$CONFIG_DIR/backup_jobs.conf"
    done
    
    for key in "${!BACKEND_CONFIGS[@]}"; do
        echo "BACKEND_CONFIGS[$key]=\"${BACKEND_CONFIGS[$key]}\"" >> "$CONFIG_DIR/backends/main.conf"
    done
    
    systemctl reload crond > /dev/null 2>&1 || /etc/init.d/cron reload > /dev/null 2>&1
    
    nohup "$BACKUP_SCRIPTS_DIR/monitoring_exporter.sh" start >> "$LOG_DIR/monitoring.log" 2>&1 &
    
    prompt_yes_no "Run test backup now?" RUN_TEST_BACKUP true
    
    if $RUN_TEST_BACKUP; then
        echo -e "\n${YELLOW}Running test backup...${NC}"
        if $BACKUP_SCRIPTS_DIR/run_backup.sh; then
            echo -e "${GREEN}✓ Test backup completed successfully${NC}"
        else
            echo -e "${RED}✗ Test backup failed${NC}"
        fi
    fi
    
    display_summary
}

display_summary() {
    print_step "Setup Complete"
    
    echo -e "\n${GREEN}${BOLD}✓ AEGIS BACKUP SYSTEM CONFIGURED SUCCESSFULLY${NC}"
    echo -e "\n${BOLD}Configuration Summary:${NC}"
    echo -e "  Backup Backend: ${SELECTED_BACKEND_NAME}"
    echo -e "  Cloud Provider: ${SELECTED_PROVIDER_NAME}"
    echo -e "  Schedule: ${CRON_SCHEDULE}"
    echo -e "  Backup Jobs: ${#BACKUP_JOBS[@]}"
    echo -e "  Parallel Uploads: ${PARALLEL_UPLOADS:-4}"
    
    echo -e "\n${BOLD}Important Files:${NC}"
    echo -e "  Config Directory: ${CONFIG_DIR}"
    echo -e "  Backup Scripts: ${BACKUP_SCRIPTS_DIR}"
    echo -e "  Logs: ${LOG_DIR}"
    echo -e "  Monitoring: ${MONITORING_DIR}"
    
    echo -e "\n${BOLD}Available Commands:${NC}"
    echo -e "  ${CYAN}Run Backup:${NC}     $BACKUP_SCRIPTS_DIR/run_backup.sh"
    echo -e "  ${CYAN}Restore:${NC}        $BACKUP_SCRIPTS_DIR/restore_backup.sh"
    echo -e "  ${CYAN}Monitoring:${NC}     $BACKUP_SCRIPTS_DIR/monitoring_exporter.sh"
    
    echo -e "\n${YELLOW}${BOLD}Next Steps:${NC}"
    echo -e "  1. Check cron job: ${CRON_DIR}/aegis-backup"
    echo -e "  2. Monitor backups in: ${LOG_DIR}"
    echo -e "  3. Access metrics: curl http://localhost:9110/metrics"
    echo -e "  4. Test restoration process"
    echo -e "  5. Set up Grafana dashboard using Prometheus metrics"
    
    echo -e "\n${GREEN}Your advanced backup system is now ready!${NC}"
}

main() {
    TOTAL_STEPS=12
    
    print_header
    echo -e "${GREEN}Welcome to Aegis Advanced Backup Automation${NC}"
    echo -e "This guided setup will configure enterprise-grade backups for your system.\n"
    
    read -p "Press Enter to continue..."
    
    init_directories
    check_dependencies
    install_backup_backends
    select_backup_backend
    configure_backend
    select_provider
    configure_provider
    configure_backup_sources
    configure_monitoring
    configure_scheduling
    configure_retention
    generate_backup_scripts
    finalize_setup
}

main "$@"

#!/bin/bash

# Aegis Advanced Backup Automator - Guided Setup for Cloud Backups
# Author: XyloBlonk
# Version: 1.0

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

CONFIG_DIR="/etc/backup-automator"
LOG_DIR="/var/log/backup-automator"
BACKUP_SCRIPTS_DIR="/usr/local/bin/backup-scripts"
CRON_DIR="/etc/cron.d"
TEMP_DIR="/tmp/backup-setup"
BACKUP_ROOT="/backups"

declare -A PROVIDERS
declare -A BACKUP_JOBS
declare -A ENCRYPTION_KEYS
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

init_directories() {
    echo -e "${BLUE}${BOLD}[1/${TOTAL_STEPS}] Initializing system directories...${NC}"
    
    mkdir -p "$CONFIG_DIR"/{providers,backups,encryption,templates} \
             "$LOG_DIR" "$BACKUP_SCRIPTS_DIR" "$TEMP_DIR" "$BACKUP_ROOT"
    
    chmod 750 "$CONFIG_DIR" "$LOG_DIR" "$BACKUP_ROOT"
    chmod 700 "$CONFIG_DIR/encryption" "$TEMP_DIR"
    
    echo -e "${GREEN}✓ Directory structure created${NC}"
}

check_dependencies() {
    echo -e "${BLUE}${BOLD}[2/${TOTAL_STEPS}] Checking system dependencies...${NC}"
    
    local deps=("curl" "tar" "gzip" "openssl" "jq" "crontab")
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

print_header() {
    clear
    echo -e "${PURPLE}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                 BACKUP AUTOMATION SETUP                     ║"
    echo "║                  Complete Guided Setup                      ║"
    echo "║                  ---------------------                      ║"
    echo "║                github.com/xyloblonk/aegis                   ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
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
EOF
    chmod 600 "$CONFIG_DIR/providers/${PROVIDER_KEY}.conf"
}

configure_b2() {
    print_step "Configure Backblaze B2 Connection"
    
    prompt "Enter B2 Account ID" B2_ACCOUNT_ID "" true
    prompt "Enter B2 Application Key" B2_APPLICATION_KEY "" true
    prompt "Enter B2 Bucket Name" B2_BUCKET "" true
    prompt "Enter backup path in bucket" B2_PATH "backups/"
    
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

configure_encryption() {
    print_step "Configure Backup Encryption"
    
    prompt_yes_no "Enable encryption for backups?" ENABLE_ENCRYPTION true
    
    if $ENABLE_ENCRYPTION; then
        echo -e "\n${YELLOW}Generating encryption key...${NC}"
        
        openssl rand -base64 32 > "$CONFIG_DIR/encryption/key.bin"
        chmod 600 "$CONFIG_DIR/encryption/key.bin"
        
        create_encryption_scripts
        
        echo -e "${GREEN}✓ Encryption enabled${NC}"
        echo -e "${YELLOW}Important: Backup your encryption key from ${CONFIG_DIR}/encryption/key.bin${NC}"
    else
        echo -e "${YELLOW}Encryption disabled${NC}"
    fi
}

create_encryption_scripts() {
    cat > "$BACKUP_SCRIPTS_DIR/encrypt_backup.sh" << 'EOF'
#!/bin/bash

set -euo pipefail

CONFIG_DIR="/etc/backup-automator"
KEY_FILE="$CONFIG_DIR/encryption/key.bin"

if [ ! -f "$KEY_FILE" ]; then
    echo "Encryption key not found!" >&2
    exit 1
fi

INPUT_FILE="$1"
OUTPUT_FILE="${INPUT_FILE}.enc"

openssl enc -aes-256-cbc -salt -pbkdf2 \
    -in "$INPUT_FILE" \
    -out "$OUTPUT_FILE" \
    -pass file:"$KEY_FILE"

rm -f "$INPUT_FILE"

echo "$OUTPUT_FILE"
EOF

    chmod 700 "$BACKUP_SCRIPTS_DIR/encrypt_backup.sh"
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
    create_retention_script
    create_cron_job
}

create_main_backup_script() {
    cat > "$BACKUP_SCRIPTS_DIR/run_backup.sh" << 'EOF'
#!/bin/bash

# Main Backup Script
# Generated by Aegis
# github.com/xyloblonk/aegis

set -euo pipefail

CONFIG_DIR="/etc/backup-automator"
LOG_DIR="/var/log/backup-automator"
BACKUP_ROOT="/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$BACKUP_ROOT/$TIMESTAMP"

PROVIDER_CONFIG="$CONFIG_DIR/providers/${1:-default}.conf"
if [ ! -f "$PROVIDER_CONFIG" ]; then
    echo "Provider configuration not found: $PROVIDER_CONFIG" >&2
    exit 1
fi
source "$PROVIDER_CONFIG"

source "$CONFIG_DIR/retention.conf"

mkdir -p "$BACKUP_DIR" "$LOG_DIR"
LOG_FILE="$LOG_DIR/backup_${TIMESTAMP}.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*" | tee -a "$LOG_FILE"
    exit 1
}

log "Starting backup process"

create_backup() {
    log "Creating backup in: $BACKUP_DIR"
    
    for job_key in "${!BACKUP_JOBS[@]}"; do
        if [[ "$job_key" == files_* ]]; then
            IFS=';' read -r -a job <<< "${BACKUP_JOBS[$job_key]}"
            declare -A job_map
            for item in "${job[@]}"; do
                IFS='=' read -r key value <<< "$item"
                job_map["$key"]="$value"
            done
            
            log "Backing up files: ${job_map["name"]}"
            tar --exclude="${job_map["excludes"]}" \
                -czf "$BACKUP_DIR/files_${job_map["name"]}.tar.gz" \
                -C "${job_map["path"]}" . || error "File backup failed"
        fi
    done
    
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

encrypt_backup() {
    if [ -f "$CONFIG_DIR/encryption/key.bin" ]; then
        log "Encrypting backup files"
        for file in "$BACKUP_DIR"/*; do
            if [ -f "$file" ] && [[ "$file" != *.enc ]]; then
                "$BACKUP_SCRIPTS_DIR/encrypt_backup.sh" "$file"
            fi
        done
    fi
}

upload_backup() {
    log "Uploading backup to cloud storage"
    "$BACKUP_SCRIPTS_DIR/upload_backup.sh" "$BACKUP_DIR" "$PROVIDER_CONFIG"
}

cleanup_local() {
    log "Cleaning up local backup files"
    rm -rf "$BACKUP_DIR"
}

create_backup
encrypt_backup
upload_backup
cleanup_local

log "Backup process completed successfully"
EOF

    chmod 700 "$BACKUP_SCRIPTS_DIR/run_backup.sh"
}

create_upload_script() {
    cat > "$BACKUP_SCRIPTS_DIR/upload_backup.sh" << 'EOF'
#!/bin/bash

# Cloud Upload Script
# Supports multiple cloud providers
# Generated by Aegis
# github.com/xyloblonk/aegis

set -euo pipefail

BACKUP_DIR="$1"
PROVIDER_CONFIG="$2"

if [ ! -d "$BACKUP_DIR" ] || [ ! -f "$PROVIDER_CONFIG" ]; then
    echo "Invalid arguments" >&2
    exit 1
fi

source "$PROVIDER_CONFIG"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

upload_to_s3() {
    local file="$1"
    local remote_path="${S3_PATH}/$(basename "$BACKUP_DIR")/$(basename "$file")"
    
    AWS_ACCESS_KEY_ID="$S3_ACCESS_KEY" \
    AWS_SECRET_ACCESS_KEY="$S3_SECRET_KEY" \
    aws s3 --endpoint-url "https://$S3_ENDPOINT" cp \
        "$file" "s3://$S3_BUCKET/$remote_path" --region "$S3_REGION"
}

for file in "$BACKUP_DIR"/*; do
    if [ -f "$file" ]; then
        log "Uploading: $(basename "$file")"
        
        case "$PROVIDER_TYPE" in
            s3)
                upload_to_s3 "$file" ;;
            *)
                echo "Unsupported provider: $PROVIDER_TYPE" >&2
                exit 1 ;;
        esac
    fi
done

log "Upload completed"
EOF

    chmod 700 "$BACKUP_SCRIPTS_DIR/upload_backup.sh"
}

create_cron_job() {
    cat > "$CRON_DIR/backup-automator" << EOF
# Backup Automator - Generated Cron Job
# Generated by Aegis
# github.com/xyloblonk/aegis
# Do not edit manually

${CRON_SCHEDULE} root $BACKUP_SCRIPTS_DIR/run_backup.sh default >> $LOG_DIR/cron.log 2>&1

0 1 * * * root $BACKUP_SCRIPTS_DIR/cleanup_retention.sh >> $LOG_DIR/retention.log 2>&1
EOF

    echo -e "${GREEN}✓ Cron job installed${NC}"
}

finalize_setup() {
    print_step "Finalizing Setup"
    
    for key in "${!BACKUP_JOBS[@]}"; do
        echo "BACKUP_JOBS[$key]=\"${BACKUP_JOBS[$key]}\"" >> "$CONFIG_DIR/backup_jobs.conf"
    done
    
    systemctl reload crond > /dev/null 2>&1 || /etc/init.d/cron reload > /dev/null 2>&1
    
    prompt_yes_no "Run test backup now?" RUN_TEST_BACKUP true
    
    if $RUN_TEST_BACKUP; then
        echo -e "\n${YELLOW}Running test backup...${NC}"
        if $BACKUP_SCRIPTS_DIR/run_backup.sh default; then
            echo -e "${GREEN}✓ Test backup completed successfully${NC}"
        else
            echo -e "${RED}✗ Test backup failed${NC}"
        fi
    fi
    
    display_summary
}

display_summary() {
    print_step "Setup Complete"
    
    echo -e "\n${GREEN}${BOLD}✓ BACKUP SYSTEM CONFIGURED SUCCESSFULLY${NC}"
    echo -e "\n${BOLD}Configuration Summary:${NC}"
    echo -e "  Provider: ${SELECTED_PROVIDER_NAME}"
    echo -e "  Schedule: ${CRON_SCHEDULE}"
    echo -e "  Backup Jobs: ${#BACKUP_JOBS[@]}"
    echo -e "  Encryption: $($ENABLE_ENCRYPTION && echo "Enabled" || echo "Disabled")"
    
    echo -e "\n${BOLD}Important Files:${NC}"
    echo -e "  Config Directory: ${CONFIG_DIR}"
    echo -e "  Backup Scripts: ${BACKUP_SCRIPTS_DIR}"
    echo -e "  Logs: ${LOG_DIR}"
    
    echo -e "\n${YELLOW}${BOLD}Next Steps:${NC}"
    echo -e "  1. Check cron job: ${CRON_DIR}/backup-automator"
    echo -e "  2. Monitor first backup in: ${LOG_DIR}"
    echo -e "  3. Backup your encryption key: ${CONFIG_DIR}/encryption/key.bin"
    echo -e "  4. Test restoration process"
    
    echo -e "\n${GREEN}Your automated backup system is now ready!${NC}"
}

main() {
    TOTAL_STEPS=10
    
    print_header
    echo -e "${GREEN}Welcome to the Aegis Backup Automation Setup${NC}"
    echo -e "This guided setup will configure automated backups for your system.\n"
    
    read -p "Press Enter to continue..."
    
    init_directories
    check_dependencies
    select_provider
    configure_provider
    configure_backup_sources
    configure_encryption
    configure_scheduling
    configure_retention
    generate_backup_scripts
    finalize_setup
}

main "$@"

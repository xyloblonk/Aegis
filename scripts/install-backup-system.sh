#!/bin/bash

# Aegis Advanced Backup Automator - Guided Setup for Cloud Backups
# Author: XyloBlonk
# Version: 1.0

# Installation script for Backup Automator

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Installing Backup Automation System...${NC}"

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root: sudo ./install-backup-system.sh${NC}"
    exit 1
fi

if [ ! -f "backup-automator.sh" ]; then
    echo -e "${RED}backup-automator.sh not found in current directory${NC}"
    exit 1
fi

chmod +x backup-automator.sh

cp backup-automator.sh /usr/local/bin/backup-automator
chmod +x /usr/local/bin/backup-automator

echo -e "${GREEN}Installation complete!${NC}"
echo -e "\nStart the setup with:"
echo -e "  ${YELLOW}sudo backup-automator${NC}"
echo -e "\nThis will guide you through the complete backup configuration process."

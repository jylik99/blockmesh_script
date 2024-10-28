#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${YELLOW}Choose an action:${NC}"
echo -e "${CYAN}1) Install node${NC}"
echo -e "${CYAN}2) Uninstall node${NC}"
echo -e "${YELLOW}Enter the number:${NC}"
read choice

case $choice in
    1)
        if ! command -v bc &> /dev/null; then
            sudo apt update
            sudo apt install bc -y
        fi
        sleep 1

        UBUNTU_VERSION=$(lsb_release -rs)
        REQUIRED_VERSION=22.04

        if (( $(echo "$UBUNTU_VERSION < $REQUIRED_VERSION" | bc -l) )); then
            echo -e "${RED}Minimum required Ubuntu version is 22.04${NC}"
            exit 1
        fi

        if ! command -v tar &> /dev/null; then
            sudo apt install tar -y
        fi
        sleep 1

        if ! command -v wget &> /dev/null; then
            sudo apt install wget -y
        fi
        sleep 1

        LATEST_RELEASE_URL=$(wget -qO- https://api.github.com/repos/block-mesh/block-mesh-monorepo/releases/latest | grep "browser_download_url.*blockmesh-cli-x86_64-unknown-linux-gnu.tar.gz" | cut -d '"' -f 4)
        LATEST_VERSION=$(wget -qO- https://api.github.com/repos/block-mesh/block-mesh-monorepo/releases/latest | grep '"tag_name":' | cut -d '"' -f 4)

        echo -e "${YELLOW}Latest version: $LATEST_VERSION${NC}"

        wget $LATEST_RELEASE_URL
        tar -xzvf blockmesh-cli-x86_64-unknown-linux-gnu.tar.gz
        sleep 1

        rm blockmesh-cli-x86_64-unknown-linux-gnu.tar.gz

        cd target/release

        echo -e "${YELLOW}Enter your email:${NC}"
        read USER_EMAIL

        echo -e "${YELLOW}Enter your password:${NC}"
        read -s USER_PASSWORD

        USERNAME=$(whoami)

        if [ "$USERNAME" == "root" ]; then
            HOME_DIR="/root"
        else
            HOME_DIR="/home/$USERNAME"
        fi

        sudo bash -c "cat <<EOT > /etc/systemd/system/blockmesh.service

[Unit]
Description=BlockMesh CLI Service
After=network.target

[Service]
User=$USERNAME
ExecStart=$HOME_DIR/target/release/blockmesh-cli login --email $USER_EMAIL --password $USER_PASSWORD
WorkingDirectory=$HOME_DIR/target/release
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOT"

        sudo systemctl daemon-reload
        sleep 1
        sudo systemctl enable blockmesh
        sudo systemctl start blockmesh

        echo -e "${GREEN}Node installed! Enable logging...${NC}"

        echo -e "${YELLOW}logs:${NC}"
        sudo journalctl -u blockmesh -f
        ;;
    2)
        echo -e "${BLUE}Uninstalling BlockMesh node...${NC}"

        sudo systemctl stop blockmesh
        sudo systemctl disable blockmesh
        sudo rm /etc/systemd/system/blockmesh.service
        sudo systemctl daemon-reload
        sleep 1

        rm -rf target

        echo -e "${GREEN}BlockMesh node successfully uninstalled!${NC}"

        sleep 1
        ;;
    *)
        echo -e "${RED}Invalid option. Exiting...${NC}"
        exit 1
        ;;
esac

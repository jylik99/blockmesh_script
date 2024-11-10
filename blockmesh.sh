#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

install_node() {
    local USER_EMAIL="$1"
    local USER_PASSWORD="$2"
    
    LATEST_RELEASE_URL=$(wget -qO- https://api.github.com/repos/block-mesh/block-mesh-monorepo/releases/latest | grep "browser_download_url.*blockmesh-cli-x86_64-unknown-linux-gnu.tar.gz" | cut -d '"' -f 4)
    LATEST_VERSION=$(wget -qO- https://api.github.com/repos/block-mesh/block-mesh-monorepo/releases/latest | grep '"tag_name":' | cut -d '"' -f 4)

    echo -e "${YELLOW}Latest version: $LATEST_VERSION${NC}"

    cd /tmp
    wget $LATEST_RELEASE_URL
    tar -xzvf blockmesh-cli-x86_64-unknown-linux-gnu.tar.gz
    sudo mv target/x86_64-unknown-linux-gnu/release/blockmesh-cli /usr/local/bin/
    sudo chmod +x /usr/local/bin/blockmesh-cli
    rm -rf target blockmesh-cli-x86_64-unknown-linux-gnu.tar.gz

    echo "$LATEST_VERSION" | sudo tee /usr/local/bin/blockmesh-version >/dev/null

    sudo bash -c "cat > /etc/systemd/system/blockmesh.service << EOL
[Unit]
Description=BlockMesh CLI Service
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/blockmesh-cli login --email $USER_EMAIL --password $USER_PASSWORD
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOL"

    cat > $HOME/update-blockmesh.sh << 'EOL'
#!/bin/bash

while true; do
    LATEST_VERSION=$(wget -qO- https://api.github.com/repos/block-mesh/block-mesh-monorepo/releases/latest | grep '"tag_name":' | cut -d '"' -f 4)
    CURRENT_VERSION=$(cat /usr/local/bin/blockmesh-version 2>/dev/null)
    echo "Checking for updates... Current version: $CURRENT_VERSION, Latest version: $LATEST_VERSION"
    
    if [ "$LATEST_VERSION" != "$CURRENT_VERSION" ]; then
        echo "Updating to version $LATEST_VERSION..."
        LATEST_URL=$(wget -qO- https://api.github.com/repos/block-mesh/block-mesh-monorepo/releases/latest | grep "browser_download_url.*blockmesh-cli-x86_64-unknown-linux-gnu.tar.gz" | cut -d '"' -f 4)
        
        sudo systemctl stop blockmesh
        
        cd /tmp
        wget -q $LATEST_URL
        tar -xzf blockmesh-cli-x86_64-unknown-linux-gnu.tar.gz
        sudo mv target/x86_64-unknown-linux-gnu/release/blockmesh-cli /usr/local/bin/
        sudo chmod +x /usr/local/bin/blockmesh-cli
        echo "$LATEST_VERSION" | sudo tee /usr/local/bin/blockmesh-version >/dev/null
        rm -rf target blockmesh-cli-x86_64-unknown-linux-gnu.tar.gz
        
        sudo systemctl start blockmesh
        echo "Update completed!"
    else
        echo "No update needed, running latest version"
    fi
    
    sleep 10800
done
EOL

    chmod +x $HOME/update-blockmesh.sh

    sudo bash -c "cat > /etc/systemd/system/blockmesh-updater.service << EOL
[Unit]
Description=BlockMesh Auto Updater
After=network.target

[Service]
Type=simple
User=root
ExecStart=$HOME/update-blockmesh.sh
WorkingDirectory=/tmp
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOL"

    sudo systemctl daemon-reload
    sudo systemctl enable blockmesh blockmesh-updater
    sudo systemctl start blockmesh blockmesh-updater

    echo -e "${GREEN}Node installed with auto-updates enabled!${NC}"
    echo -e "${YELLOW}Showing node logs:${NC}"
    sudo journalctl -u blockmesh -u blockmesh-updater -f
}

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

        UBUNTU_VERSION=$(lsb_release -rs)
        REQUIRED_VERSION=22.04

        if (( $(echo "$UBUNTU_VERSION < $REQUIRED_VERSION" | bc -l) )); then
            echo -e "${RED}Minimum required Ubuntu version is 22.04${NC}"
            exit 1
        fi

        if ! command -v tar &> /dev/null; then
            sudo apt install tar -y
        fi

        if ! command -v wget &> /dev/null; then
            sudo apt install wget -y
        fi

        echo -e "${YELLOW}Enter your email:${NC}"
        read USER_EMAIL

        echo -e "${YELLOW}Enter your password:${NC}"
        read -s USER_PASSWORD

        install_node "$USER_EMAIL" "$USER_PASSWORD"
        ;;
    2)
        echo -e "${BLUE}Uninstalling BlockMesh node...${NC}"
        
        sudo systemctl stop blockmesh blockmesh-updater
        sudo systemctl disable blockmesh blockmesh-updater
        sudo rm /etc/systemd/system/blockmesh.service
        sudo rm /etc/systemd/system/blockmesh-updater.service
        sudo systemctl daemon-reload
        
        sudo rm -f /usr/local/bin/blockmesh-cli
        sudo rm -f /usr/local/bin/blockmesh-version
        rm -f $HOME/update-blockmesh.sh

        echo -e "${GREEN}BlockMesh node successfully uninstalled!${NC}"
        ;;
    *)
        echo -e "${RED}Invalid option. Exiting...${NC}"
        exit 1
        ;;
esac
#!/bin/bash

print_usage() {
    cat <<EOF
Sets up Docker, blacklists DVB driver, installs udev rules, and configures network connections. 
Make sure to have saved the rtl-sdr rules from

    https://github.com/jopohl/urh/wiki/SDR-udev-rules

in the directory you are running this script from!

Options:
  -h, --help
    Show this help message and exit
  -c, --conn
    You can provide a .nmconnection file.
    Otherwise a DEFAULT network connection is registered.
    The DEFAULT test-network should only be used
    for testing and demonstration purposes!
EOF
}

# Variables to track flags
NMCONN_FILE=""

# Check for no arguments
if [[ $# -eq 0 ]]; then
    print_usage
    exit 0
fi

while [ "$#" -gt 0 ]; do
    case "$1" in
    -h | --help)
        print_usage
        exit 0
        ;;
    -c | --conn)
        NMCONN_FILE="$2"
        shift 2
        ;;
    *)
        echo >&2 "Error: Unknown option: $1"
        print_usage
        exit 1
        ;;  
    esac
done

# Install Docker and add to docker group
curl -sSL https://get.docker.com | sh
sudo usermod -aG docker $USER

# Blacklist DVB drivers
echo "blacklist dvb_usb_rtl28xxu" | sudo tee /etc/modprobe.d/blacklist-rtl.conf

# Add rtl-sdr-rules for udev
echo "Get udev-rules for rtl-sdr at:
https://github.com/jopohl/urh/wiki/SDR-udev-rules
and save them to the folder your running this script from"
if [ -f "10-rtl-sdr.rules" ]; then
    cat 10-rtl-sdr.rules | sudo tee /etc/udev/rules.d/10-rtl-sdr.rules
    sudo udevadm control --reload-rules && sudo udevadm trigger
else
    echo "\nWARNING:\n 10-rtl-sdr.rules file does not exist.
 Please download it and save them in the directory you're running this script from.
 Then rerun this script."
    exit 1
fi

# Network connection setup
if [[ -n "$NMCONN_FILE" ]]; then
    if [[ -f "$NMCONN_FILE" ]]; then
        echo "Using provided connection file: $NMCONN_FILE"
        sudo cp "$NMCONN_FILE" "/etc/NetworkManager/system-connections/$NMCONN_FILE"
        sudo chmod 600 "/etc/NetworkManager/system-connections/$NMCONN_FILE"
    else
        echo "Error: Connection file '$NMCONN_FILE' not found."
        exit 1
    fi
else
    # Prompt user if no connection file is provided
    read -p "No connection file provided. Do you want to proceed with the default network connection? [y/N]: " USER_RESPONSE
    if [[ "$USER_RESPONSE" == "y" || "$USER_RESPONSE" == "Y" ]]; then
        echo "Proceeding with default network connection setup..."
        echo "This is NOT SECURE and should only be used for demonstration purposes"
        echo "Please refer to the documentation how to create a network connection file"
        sudo nmcli connection add \
            save yes \
            type wifi \
            ifname wlan0 \
            ssid test-network \
            connection.id testconn \
            autoconnect yes \
            wifi-sec.auth-alg open \
            wifi-sec.key-mgmt wpa-psk \
            wifi-sec.psk Sup3rs3cr3t133
    else
        echo "Aborting network connection setup."
        echo "You can refer to the documentation on how to setup a network connection file"
        exit 0
    fi
fi

# Restart NetworkManager
sudo systemctl restart NetworkManager
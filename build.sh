#!/bin/bash

# Variables to track flags
BUILD_FLAG=false
SERVICE_ONLY=false

print_usage() {
    cat <<EOF
* Builds docker container
* Installs systemd service for gsm-monitor
* you can opt to only install the systemd service if the docker image is already set up

Options:
  -h, --help
    Show this help message and exit
  -b, --build
    Builds Docker image. Set to "false" by DEFAULT
  -s, --service-only
    Only registers the systemd-service provided
    that the docker image already exists on the
    machine!
EOF
}

# Check for no arguments
if [[ $# -eq 0 ]]; then
    print_usage
    exit 0
fi

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h | --help)
            print_usage
            exit 0
            ;;
        -b | --build)
            BUILD_FLAG=true
            shift
            ;;
        -s | --service-only)
            SERVICE_ONLY=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Ensure --service-only is used alone
if $SERVICE_ONLY && $BUILD_FLAG; then
    echo "Error: --service-only cannot be used with other flags."
    exit 1
fi

# Service registration logic
register_service() {
    echo "Registering service via symlink..."
    sudo ln -sf "$HOME/gsm-monitor/gsm-monitor.service" /etc/systemd/system/gsm-monitor.service

    echo "Reloading daemon, enabling, and starting service..."
    echo "Make sure that your SDR is connected!"
    sudo systemctl daemon-reload
    sudo systemctl enable gsm-monitor.service
    sudo systemctl start gsm-monitor.service
}

# Handle --service-only flag
if $SERVICE_ONLY; then
    echo "WARNING: Ensure the Docker image is set up correctly before proceeding."
    read -p "Do you want to proceed with the service installation? [y/N]: " USER_RESPONSE
    if [[ "$USER_RESPONSE" == "y" || "$USER_RESPONSE" == "Y" ]]; then
        register_service
    else
        echo "Service installation aborted."
        exit 0
    fi
    exit 0
fi

# Build docker image if --build flag is set
if $BUILD_FLAG; then
    echo "Building Docker image."
    echo "If you're running this on your Raspi, this may take a while...\n"
    docker build -t gsm-monitor "$HOME/gsm-monitor"
    register_service
else
    echo "Skipping Docker build."
    echo "Please transfer the image by other means and rerun with -s / --service-only"
fi
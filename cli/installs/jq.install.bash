#!/bin/bash

# Function to check if jq is already installed
check_jq_installed() {
    if which jq >/dev/null; then
        return 0  # return 0 if installed
    else
        return 1  # return 1 if not installed
    fi
}

# Function to install jq on Debian/Ubuntu
install_debian() {
    sudo apt-get update
    sudo apt-get install -y jq
}

# Function to install jq on Fedora
install_fedora() {
    sudo dnf install -y jq
}

# Function to install jq on CentOS/RHEL
install_centos() {
    sudo yum install -y jq
}

# Function to install jq on macOS
install_macos() {
    brew install jq
}

# Determine the OS and run the appropriate installation command if jq is not installed
if check_jq_installed; then
 echo "jq is already installed."
 exit 0
fi

if [ -f /etc/os-release ]; then
    . /etc/os-release
    case $ID in
        ubuntu|debian)
            install_debian
            ;;
        fedora)
            install_fedora
            ;;
        centos|rhel)
            install_centos
            ;;
        *)
            echo "Unsupported Linux distribution: $ID"
            exit 1
            ;;
    esac
elif [[ "$OSTYPE" == "darwin"* ]]; then
    # Assumes Homebrew is installed on macOS
    install_macos
else
    echo "Unsupported operating system"
    exit 1
fi
echo "jq installation process completed."

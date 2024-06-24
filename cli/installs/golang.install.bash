#!/bin/bash

# Function to check if Go is already installed
check_golang_installed() {
    if which go >/dev/null; then
        return 0  # return 0 if installed
    else
        return 1  # return 1 if not installed
    fi
}

# Function to install Go on Debian/Ubuntu
install_debian() {
    sudo apt-get update
    sudo apt-get install -y golang
}

# Function to install Go on Fedora
install_fedora() {
    sudo dnf install -y golang
}

# Function to install Go on CentOS/RHEL
install_centos() {
    sudo yum install -y golang
}

# Function to install Go on macOS
install_macos() {
    brew install go
}

# Determine the OS and run the appropriate installation command if Go is not installed
if  check_golang_installed; then
 echo "Go is already installed."
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
echo "Go installation process completed."

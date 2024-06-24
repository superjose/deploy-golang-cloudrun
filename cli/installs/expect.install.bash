#!/bin/bash

# Function to check if expect is already installed
check_expect_installed() {
    if which expect >/dev/null; then
        return 0  # return 0 if installed
    else
        return 1  # return 1 if not installed
    fi
}

# Function to install expect on Debian/Ubuntu
install_debian() {
    sudo apt-get update
    sudo apt-get install -y expect
}

# Function to install expect on Fedora
install_fedora() {
    sudo dnf install -y expect
}

# Function to install expect on CentOS/RHEL
install_centos() {
    sudo yum install -y expect
}

# Function to install expect on macOS
install_macos() {
    brew install expect
}

# Determine the OS and run the appropriate installation command if expect is not installed
if  check_expect_installed; then
 echo "Expect is already installed."
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
echo "Expect installation process completed."


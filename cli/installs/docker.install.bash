#!/bin/bash

# Function to check if Docker is already installed
check_docker_installed() {
    if which docker >/dev/null; then
        return 0  # return 0 if installed
    else
        return 1  # return 1 if not installed
    fi
}

# Function to install Docker on Debian/Ubuntu
install_debian() {
    sudo apt-get update
    sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    sudo apt-get update
    sudo apt-get install -y docker-ce
}

# Function to install Docker on Fedora
install_fedora() {
    sudo dnf -y install dnf-plugins-core
    sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
    sudo dnf -y install docker-ce docker-ce-cli containerd.io
    sudo systemctl start docker
    sudo systemctl enable docker
}

# Function to install Docker on CentOS/RHEL
install_centos() {
    sudo yum install -y yum-utils
    sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    sudo yum install -y docker-ce docker-ce-cli containerd.io
    sudo systemctl start docker
    sudo systemctl enable docker
}

# Function to install Docker on macOS
install_macos() {
    # Assumes Homebrew is installed on macOS
    brew cask install docker
    open /Applications/Docker.app
}

# Determine the OS and run the appropriate installation command if Docker is not installed
if check_docker_installed; then
    echo "Docker is already installed."
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
echo "Docker installation process completed."

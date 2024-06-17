#!/bin/bash
if [ $# -eq 0 ]; then
    echo "Usage: $0 <username>"
    exit 1
fi

# Function to create a new user
create_user() {
    local username=$1
    if ! id -u $username &>/dev/null; then
        sudo adduser --disabled-password --gecos "" $username
        sudo usermod -aG sudo $username
        sudo mkdir -p /home/$username/.ssh
        sudo cp ~/.ssh/authorized_keys /home/$username/.ssh/
        sudo chown -R $username:$username /home/$username/.ssh
        sudo chmod 700 /home/$username/.ssh
        sudo chmod 600 /home/$username/.ssh/authorized_keys
        echo "$username ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/$username
    else
        echo "User $username already exists."
    fi
}

# Function to check if Docker is installed and start Docker service if it's not running
check_and_start_docker() {
    local username=$1
    if ! command -v docker &> /dev/null; then
        # Docker is not installed, install it
        echo "Docker is not installed. Installing..."
        sudo apt update
        sudo apt install -y apt-transport-https ca-certificates curl software-properties-common python3.11
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
        sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"
        sudo apt-get update
        sudo apt-get install -y docker-ce make
        #sudo groupadd docker
        sudo usermod -aG docker $username
        sudo systemctl restart docker
        echo "Docker has been installed."
    else
        echo "Docker is already installed."
    fi

    # Check if Docker service is running
    if ! sudo systemctl is-active --quiet docker; then
        # Docker service is not running, start it
        echo "Docker service is not running. Starting Docker..."
        sudo systemctl start docker
        echo "Docker service has been started."
    else
        echo "Docker service is already running."
    fi

    # Test Docker installation by running a simple container
    echo "Testing Docker installation with hello-world container..."
    if docker run hello-world &> /dev/null; then
        echo "Docker is working correctly."
    else
        echo "Failed to run Docker container. Check Docker installation and permissions."
        echo "Exit shell log back in and try again"
        exit 1
    fi
}

create_user $1
check_and_start_docker $1
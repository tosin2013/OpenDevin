#!/bin/bash

# Function to check if Docker is installed and start Docker service if it's not running
check_and_start_docker() {
    if ! command -v docker &> /dev/null; then
        # Docker is not installed, install it
        echo "Docker is not installed. Installing..."
        sudo apt update
        sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
        sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"
        sudo apt-get update
        sudo apt-get install -y docker-ce make
        #sudo groupadd docker
        sudo usermod -aG docker $USER
    fi

    # Check if Docker service is running
    if ! sudo systemctl is-active --quiet docker; then
        # Docker service is not running, start it
        echo "Docker service is not running. Starting Docker..."
        sudo systemctl start docker
    fi
}

# Function to check if Node.js is installed and install it if necessary
check_and_install_node() {
    if ! command -v node &> /dev/null; then
        # Install npm and create-react-app
        curl -sL https://deb.nodesource.com/setup_18.x | sudo bash -
        sudo apt -y install nodejs
        node  -v
    fi
}

# Function to check if Poetry is installed and install it if necessary
check_and_install_poetry() {
    if ! command -v poetry &> /dev/null; then
        # Install Poetry
        curl -fsSL https://raw.githubusercontent.com/python-poetry/poetry/master/get-poetry.py | python -
    fi
}

# Function to check if the configuration file exists and create it if necessary
check_and_create_config() {
    if [ ! -f config.toml ]; then
        # Create the configuration file
        cat >config.toml<<EOF
LLM_API_KEY="ollama"
LLM_MODEL="ollama/mistral:7b"
LLM_EMBEDDING_MODEL="local"
LLM_BASE_URL="http://localhost:11434"
WORKSPACE_DIR="./workspace"
EOF
    fi
}

# Function to check if the workspace directory exists and create it if necessary
check_and_create_workspace() {
    if [ ! -d $WORKSPACE_DIR ]; then
        # Create the workspace directory
        mkdir $WORKSPACE_DIR
    fi
}

# Function to check if the OpenDevin server is running and start it if necessary
check_and_start_opendevin() {
        make run
}

# Main function to check for dependencies and install them if necessary
main() {
    check_and_start_docker
    check_and_install_node
    check_and_install_poetry
    check_and_create_config
    check_and_create_workspace
    check_and_start_opendevin
}

# Call the main function to start the installation process
main


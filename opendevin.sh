#!/bin/bash
# Uncomment for debugging
#export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
#set -x
export DEBIAN_FRONTEND=noninteractive

# Function to display help
usage() {
    echo "Usage: $0 [-b] [-r] [-i] [-o] [-h]"
    echo "  -b : Build the project"
    echo "  -r : Run the project"
    echo "  -i : Install dependencies"
    echo "  -o : Include Ollama deployment"
    echo "  -h : Display this help menu"
}

# Initialize variables for flags
BUILD=false
RUN=false
INSTALL=false
SKIP_OLLAMA=true  # Default to skipping Ollama deployment

while getopts "brioh" opt; do
    case $opt in
        b)
            BUILD=true
            ;;
        r)
            RUN=true
            ;;
        i)
            INSTALL=true
            ;;
        o)
            SKIP_OLLAMA=false
            ;;
        h)
            usage
            exit 0
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            usage
            exit 1
            ;;
    esac
done

echo "BUILD: $BUILD, RUN: $RUN, INSTALL: $INSTALL, SKIP_OLLAMA: $SKIP_OLLAMA"

# Check if no options were provided
if [ $# -eq 0 ]; then
    usage
    exit 0
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

# Create the ubuntu user
create_user "ubuntu"

# Function to check for and install Conda if it's not installed
check_and_install_conda() {
    if ! command -v conda &> /dev/null; then
        echo "Conda is not installed. Installing Miniconda..."
        wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda.sh
        bash ~/miniconda.sh -b -p $HOME/miniconda
        export PATH="$HOME/miniconda/bin:$PATH"
        echo "Conda has been installed."
        # Initialize conda for script use
        conda init --system
        source $HOME/miniconda/etc/profile.d/conda.sh
    else
        echo "Conda is already installed."
    fi
}

# Function to check for and activate or create a Conda environment
setup_conda_environment() {
    source $HOME/miniconda/etc/profile.d/conda.sh  # Ensure conda functions are available
    if conda info --envs | grep opendevin; then
        echo "Activating existing Conda environment 'opendevin'..."
        conda activate opendevin
    else
        echo "Creating and activating new Conda environment 'opendevin'..."
        conda create -n opendevin python=3.11 -y
        conda activate opendevin
    fi
}

# Function to check if Docker is installed and start Docker service if it's not running
check_and_start_docker() {
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
        sudo usermod -aG docker $USER
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

# Function to check if Node.js is installed and install it if necessary
check_and_install_node() {
    if ! command -v node &> /dev/null; then
        # Install npm and create-react-app
        echo "Node.js is not installed. Installing..."
        curl -sL https://deb.nodesource.com/setup_18.x | sudo bash -
        sudo apt -y install nodejs
        node -v
        echo "Node.js has been installed."
    else
        echo "Node.js is already installed."
    fi
}

# Function to check if Poetry is installed and install it if necessary
check_and_install_poetry() {
    if ! command -v poetry &> /dev/null; then
        echo "Poetry is not installed. Installing..."
        curl -sSL https://install.python-poetry.org | python3.11 -
        export PATH="$HOME/.local/bin:$PATH"
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
    else
        echo "Poetry is already installed."
    fi
}

# Function to check if the configuration file exists and create it if necessary
check_and_create_config() {
    if [ ! -f config.toml ]; then
        # Create the configuration file
        echo "Configuration file not found. Creating config.toml..."
        cat >config.toml<<EOF
LLM_API_KEY="ollama"
LLM_MODEL="ollama/qwen2:7b"
LLM_EMBEDDING_MODEL="local"
LLM_BASE_URL="http://localhost:11434"
WORKSPACE_DIR="./workspace"
EOF
        echo "Configuration file created."
    else
        echo "Configuration file already exists."
    fi
}

# Function to check if the workspace directory exists and create it if necessary
check_and_create_workspace() {
    if [ ! -d $WORKSPACE_DIR ]; then
        # Create the workspace directory
        echo "Workspace directory not found. Creating $WORKSPACE_DIR..."
        mkdir $WORKSPACE_DIR
        echo "Workspace directory created."
    else
        echo "Workspace directory already exists."
    fi
}

# Function to check if the OpenDevin server is running and start it if necessary
check_and_start_opendevin() {
    # Ensure we are in the correct directory
    if [ "$(pwd)" != "$HOME/OpenDevin" ]; then
        echo "Changing to the OpenDevin directory..."
        cd "$HOME/OpenDevin"
    fi

    echo "Building OpenDevin..."
    source $HOME/miniconda/etc/profile.d/conda.sh
    export PATH="$HOME/.local/bin:$PATH"
    source ~/.bashrc  # or source ~/.zshrc
    make build || (echo "Build failed. Retrying..." && make build) || exit $?
    echo "Starting the OpenDevin server..."
    make run || exit $?
}

# Function to check if the OpenDevin directory exists in the $HOME directory
# and change to that directory if it does, otherwise clone the repository
# and change to the new directory
clone_and_cd_opendevin() {
    if [ -d "$HOME/OpenDevin" ]; then
        echo "OpenDevin directory found in $HOME. Changing to that directory."
        cd "$HOME/OpenDevin"
    else
        echo "OpenDevin directory not found. Cloning the repository and changing to the new directory."
        git clone https://github.com/opendevin/OpenDevin.git "$HOME/OpenDevin"
        cd "$HOME/OpenDevin"
    fi
}

# Function to install and manage Ollama LLM
setup_ollama_llm() {
    if $SKIP_OLLAMA; then
        echo "Skipping Ollama deployment by default."
        return
    fi

    # Check if Ollama is already installed
    if ! command -v ollama &> /dev/null; then
        echo "Ollama is not installed. Installing Ollama..."
        curl -fsSL https://ollama.com/install.sh | sh
    else
        echo "Ollama is already installed."
    fi

    # Start Ollama server
    echo "Starting Ollama server..."
    if systemctl is-active --quiet ollama; then
        echo "Ollama server is already running."
    else
        echo "Starting Ollama server..."
        sudo systemctl start ollama
    fi

    # Check existing models and pull if not present
    existing_models=$(ollama list)
    declare -a models=("qwen2:7b" "codellama:70b" "xingyaow/codeact-agent-mistral" "deepseek-v2:236b" "codestral:22b")
    for model in "${models[@]}"; do
        if [[ ! $existing_models =~ $model ]]; then
            echo "Model $model not found. Pulling model..."
            ollama pull $model
        else
            echo "Model $model already installed."
        fi
    done
}

# Export functions to be used by the new user
export -f check_and_install_conda
export -f setup_conda_environment
export -f check_and_start_docker
export -f check_and_install_node
export -f check_and_install_poetry
export -f check_and_create_config
export -f check_and_create_workspace
export -f check_and_start_opendevin
export -f clone_and_cd_opendevin
export -f setup_ollama_llm


# Main function to check for dependencies and install them if necessary
main() {
    if $INSTALL; then
        sudo su - ubuntu -c "check_and_start_docker"
        sudo su - ubuntu -c "check_and_install_node"
        sudo su - ubuntu -c "check_and_install_conda"
        sudo su - ubuntu -c "setup_conda_environment"
        sudo su - ubuntu -c "check_and_install_poetry"
        sudo su - ubuntu -c "clone_and_cd_opendevin"
        sudo su - ubuntu -c "setup_ollama_llm"
        sudo su - ubuntu -c "check_and_create_config"
        sudo su - ubuntu -c "check_and_create_workspace"
    fi

    if $BUILD; then
        sudo su - ubuntu -c "check_and_start_opendevin"
    fi

    if $RUN; then
        sudo su - ubuntu -c "cd $HOME/OpenDevin && make run"
    fi
}

# Call the main function to start the installation process
main

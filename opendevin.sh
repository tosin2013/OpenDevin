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


curl -OL https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
bash Miniconda3-latest-Linux-x86_64.sh
source /root/.bashrc

conda create -n opendevin python=3.11
conda activate opendevin


# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    # Install npm and create-react-app
    curl -sL https://deb.nodesource.com/setup_18.x | sudo bash -
    sudo apt -y install nodejs
    node  -v
fi


sudo apt update
sudo apt install pipx
pipx ensurepath
sudo pipx ensurepath --global
pipx install poetry #  curl -sSL https://install.python-poetry.org | python3.11 -

git clone https://github.com/tosin2013/OpenDevin.git
cd OpenDevin
git checkout live
make build

curl -fsSL https://ollama.com/install.sh | sh
sleep 30s
ollama pull mistral:7b

make setup-config
###
# cat >config.toml<<EOF
# LLM_API_KEY="ollama"
# LLM_MODEL="ollama/mistral:7b"
# LLM_EMBEDDING_MODEL="local"
# LLM_BASE_URL="http://localhost:11434"
# WORKSPACE_DIR="./workspace"
# EOF

make run


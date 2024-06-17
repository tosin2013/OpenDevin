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

create_user $1
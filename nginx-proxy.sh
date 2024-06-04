#!/bin/bash

# Usage:
# ./setup_nginx.sh --self-signed   # For self-signed certificate
# ./setup_nginx.sh --letsencrypt   # For Let's Encrypt certificate
export USER_NAME=opendevin

setup_self_signed() {
    echo "Setting up Nginx with a self-signed SSL certificate..."
    if [ ! -f /etc/nginx/ssl/code-server.crt ] || [ ! -f /etc/nginx/ssl/code-server.key ]; then
        sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/nginx/ssl/code-server.key -out /etc/nginx/ssl/code-server.crt
    fi
    # Configuration for self-signed
    if [ ! -L /etc/nginx/sites-enabled/code-server ]; then
        cat <<EOF | sudo tee /etc/nginx/sites-available/code-server
server {
    listen 443 ssl;
    server_name _;

    ssl_certificate /etc/nginx/ssl/code-server.crt;
    ssl_certificate_key /etc/nginx/ssl/code-server.key;

    location / {
        proxy_pass http://localhost:8080/;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection upgrade;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_buffering off;
    }
}
EOF
        sudo ln -s /etc/nginx/sites-available/code-server /etc/nginx/sites-enabled/code-server
    fi
    # Create password file for basic auth
    echo "Creating password for basic authentication..."
    sudo htpasswd -c /etc/nginx/.htpasswd ${USER_NAME}

    # Configuration for localhost:3001 on 8443 with password protection
    if [ ! -L /etc/nginx/sites-enabled/localhost_3001 ]; then
        cat <<EOF | sudo tee /etc/nginx/sites-available/localhost_3001
server {
    listen 8443 ssl;
    server_name localhost;

    ssl_certificate /etc/nginx/ssl/code-server.crt;
    ssl_certificate_key /etc/nginx/ssl/code-server.key;

    location / {
        auth_basic "Restricted Content";
        auth_basic_user_file /etc/nginx/.htpasswd;
        proxy_pass http://localhost:3001;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection upgrade;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_buffering off;
    }
}
EOF
        sudo ln -s /etc/nginx/sites-available/localhost_3001 /etc/nginx/sites-enabled/localhost_3001
    fi
    sudo systemctl restart nginx
    echo "Nginx with self-signed SSL is setup."
}

setup_lets_encrypt() {
    echo "Setting up Nginx with Let's Encrypt..."
    if ! dpkg -l | grep -q certbot; then
        sudo apt install -y certbot python3-certbot-nginx
    fi
    if ! sudo certbot certificates | grep -q yourdomain.com; then
        sudo certbot --nginx -d yourdomain.com
    fi
    echo "Nginx with Let's Encrypt is setup."
}

main() {
    # Install Nginx
    echo "Installing Nginx..."
    if ! dpkg -l | grep -q nginx; then
        sudo apt update
        sudo apt install -y nginx apache2-utils
    fi
    sudo mkdir -p /etc/nginx/ssl

    # Install curl and code-server
    echo "Installing code-server..."
    if ! command -v code-server &> /dev/null; then
        curl -fsSL https://code-server.dev/install.sh | sh
        sudo systemctl enable --now code-server@$USER
    fi

    # Check the flag
    case "$1" in
        --self-signed)
            setup_self_signed
            ;;
        --letsencrypt)
            setup_lets_encrypt
            ;;
        *)
            echo "Invalid option. Use --self-signed or --letsencrypt."
            exit 1
            ;;
    esac
}

main "$@"

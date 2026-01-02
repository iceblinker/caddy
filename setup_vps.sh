#!/bin/bash
set -e

echo "🚀 Starting God Mode Deployment..."

# 0. Ensure Networks Exist
echo "🌐 Checking Networks..."
docker network inspect caddy_net >/dev/null 2>&1 || docker network create caddy_net
docker network inspect ai_network >/dev/null 2>&1 || docker network create ai_network

# 1. Setup Env
if [ ! -f .env ]; then
    echo "📝 Configuring Environment..."
    cp .env.example .env
    
    read -p "Enter your Domain (e.g. myflix.com): " DOMAIN
    read -p "Enter your Email (for SSL): " EMAIL
    read -p "Enter a Secure Password for Mediaflow: " API_PASSWORD
    
    # Linux sed syntax
    sed -i "s/DOMAIN=localhost/DOMAIN=$DOMAIN/" .env
    sed -i "s|ACME_EMAIL=your-email@example.com|ACME_EMAIL=$EMAIL|" .env
    sed -i "s/API_PASSWORD=securepassword123/API_PASSWORD=$API_PASSWORD/" .env
    
    echo "✅ Environment configured."
else
    echo "ℹ️ .env already exists, skipping configuration."
fi

# 2. Start Security Engine
echo "🛡️  Starting CrowdSec..."
docker-compose -f docker-compose.caddy.yml up -d crowdsec
echo "⏳ Waiting for CrowdSec to initialize (10s)..."
sleep 10

# 3. Generate Key if not present
if grep -q "CROWDSEC_API_KEY=$" .env || grep -q "CROWDSEC_API_KEY=$" .env; then # Checks if empty
    echo "🔑 Generating Security Key..."
    API_KEY=$(docker exec crowdsec cscli bouncers add caddy-bouncer)
    
    if [ -n "$API_KEY" ]; then
        # Use pipe delimiter to avoid conflicts with slashes in the key
        sed -i "s|CROWDSEC_API_KEY=|CROWDSEC_API_KEY=$API_KEY|" .env
        echo "✅ Key injected into .env"
    else
        echo "❌ Failed to generate key. Please run 'docker exec crowdsec cscli bouncers add caddy-bouncer' manually."
    fi
else
    echo "ℹ️ CrowdSec key already configured."
fi

# 4. Build & Launch
echo "🏗️  Building & Launching..."
docker-compose -f docker-compose.caddy.yml build caddy
docker-compose -f docker-compose.caddy.yml -f docker-compose.mediaflow.yml up -d

echo "🎉 Deployment Complete!"
echo "Check status with: docker ps"

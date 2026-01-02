# 🛡️ Ultimate Caddy & Mediaflow Gateway ("God Mode")

A production-ready, hardened reverse proxy stack designed for self-hosted media servers and AI tools. Features active intrusion prevention, intelligent rate limiting, and automatic HTTPS.

![Docker](https://img.shields.io/badge/Docker-2CA5E0?style=for-the-badge&logo=docker&logoColor=white)
![Caddy](https://img.shields.io/badge/Caddy-00ADD8?style=for-the-badge&logo=caddy&logoColor=white)
![CrowdSec](https://img.shields.io/badge/CrowdSec-4B32C3?style=for-the-badge&logo=crowdsec&logoColor=white)
![Security](https://img.shields.io/badge/Security-Hardened-green?style=for-the-badge)

## 🌟 Key Features

*   **🛡️ Active Defense (CrowdSec)**: Integrated Intrusion Prevention System (IPS) that detects attacks and automatically bans malicious IPs in real-time across your entire stack.
*   **🚀 High Performance**: Custom-compiled Caddy build with `zstd` & `gzip` compression, optimized transport settings, and memory-efficient caching.
*   **👮 Granular Rate Limiting**: Protects your endpoints (like `mediaflow-proxy`) from abuse with configurable request limits (e.g., 20 req/s).
*   **🩺 Active Health Checks**: Constantly monitors backend services (Mediaflow, Jackett) and instantly stops routing traffic if they go down.
*   **🔒 Hardened Security Headers**: Pre-configured with HSTS, Content-Security-Policy, X-Frame-Options, and more for an A+ SSL rating.
*   **🤖 Automated HTTPS**: Zero-touch SSL certificate management via Let's Encrypt with parameterized domain support.

## 🛠️ Architecture

This stack is composed of two main Docker Compose files working in tandem:

1.  **`docker-compose.caddy.yml`**: The Gateway. Runs Caddy (Reverse Proxy) and CrowdSec (Security Engine).
2.  **`docker-compose.mediaflow.yml`**: The Application. Runs Mediaflow Proxy isolated on an internal network.

## 🚀 Getting Started

### Prerequisites
*   Docker & Docker Compose installed.
*   Ports `80` (HTTP) and `443` (HTTPS) open.
*   A domain name pointing to your server.

### Installation

1.  **Clone the Repository**
    ```bash
    git clone https://github.com/yourusername/caddy-mediaflow-gateway.git
    cd caddy-mediaflow-gateway
    ```

2.  **Configure Environment**
    Copy the example file and set your domain/email:
    ```bash
    cp .env.example .env
    nano .env
    # Set DOMAIN=yourdomain.com
    # Set ACME_EMAIL=you@example.com
    ```

3.  **Initialize Security (God Mode Setup)**
    *First-time setup only. This links Caddy to the CrowdSec detection engine.*

    Start the security engine:
    ```bash
    docker-compose -f docker-compose.caddy.yml up -d crowdsec
    ```
    Generate an API key for Caddy:
    ```bash
    docker exec crowdsec cscli bouncers add caddy-bouncer
    ```
    Copy the key output and add it to your `.env` file:
    ```bash
    CROWDSEC_API_KEY=<your_generated_key>
    ```

4.  **Build & Deploy**
    Build the custom secure image and start the full stack:
    ```bash
    docker-compose -f docker-compose.caddy.yml build caddy
    docker-compose -f docker-compose.caddy.yml -f docker-compose.mediaflow.yml up -d
    ```

## 🔍 Verification

*   **Check Status**: `docker ps` should show all containers active.
*   **Verify Protection**:
    ```bash
    docker logs caddy
    ```
    Look for `"msg": "crowdsec initialized"`. This confirms your gateway is actively defended.

## 📂 Configuration

*   **Caddyfile**: Central configuration. Uses `{$DOMAIN}` for easy deployment.
    *   To add new sites, simply copy an existing block in `Caddyfile`.
*   **docker-compose.caddy.yml**: Defines the infrastructure (Caddy + CrowdSec).

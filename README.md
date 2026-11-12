# Raspberry Pi OS in Docker with QEMU

Run Raspberry Pi OS Lite (ARM64) inside a Docker container using QEMU system emulation.

## Requirements

- Linux x86_64 host
- Docker Engine
- Docker Compose

## Installation

Clone the repository:

    git clone https://github.com/YOUR_USERNAME/raspi4-docker.git
    cd raspi4-docker

Create your environment file:

    cp .env.example .env
    nano .env

Set your password:

    RPI_PASSWORD=YourSecurePassword

Build and start:

    docker compose up --build

The official Raspberry Pi OS Lite ARM64 image is downloaded automatically on first startup.

## SSH access

Connect from the host:

    ssh -p 2223 pi@localhost

## Ports

| Port | Purpose |
|------|---------|
| 2223 | SSH access |
| 5900 | VNC port mapping |

## Emulation details

- Operating system: Raspberry Pi OS Lite (64-bit)
- Architecture: ARM64
- QEMU machine: Raspberry Pi 3 Model B (`raspi3b`)
- CPU: Cortex-A53
- Acceleration: QEMU TCG software emulation

**Note:** This project currently emulates a Raspberry Pi 3 Model B, not a Raspberry Pi 4.

## Data and persistence

The `data/` directory stores the downloaded disk image and generated files. It is excluded from Git.

## Security

Never commit your `.env` file. It contains your personal password and is excluded by `.gitignore`.

## License

A license has not yet been selected.

FROM debian:trixie-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    qemu-system-arm \
    qemu-utils \
    ca-certificates \
    wget \
    xz-utils \
    openssl \
    util-linux \
    parted \
    e2fsprogs \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /data

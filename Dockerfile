FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    live-build \
    debootstrap \
    python3-pil \
    python3 \
    fonts-dejavu-core \
    curl \
    ca-certificates \
    systemd-container \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

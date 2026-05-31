FROM archlinux:latest

RUN for i in 1 2 3; do pacman -Sy --noconfirm && break; done && \
    pacman -S --noconfirm \
        archiso \
        grub \
        python \
        python-pillow \
        dosfstools \
        mtools \
        && \
    pacman -Syu --noconfirm

WORKDIR /build
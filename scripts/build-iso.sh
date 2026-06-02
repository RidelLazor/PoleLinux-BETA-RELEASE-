#!/usr/bin/env bash
set -euo pipefail

DISTRO_NAME="PoleLinux"
DISTRO_VERSION="1.0"

BUILD_BASE="/build/build-env"
OUT_DIR="$BUILD_BASE/out"

rm -rf "$BUILD_BASE"
mkdir -p "$OUT_DIR"

echo "==> Testing mirror connectivity..."
if ! curl -4 -s -o /dev/null -w "%{http_code}" --max-time 10 \
  "http://deb.debian.org/debian/dists/bookworm/Release" 2>/dev/null | grep -q 200; then
  echo "==> ERROR: Debian mirror not reachable."
  exit 1
fi
echo "  OK: deb.debian.org"

echo "==> Generating Plymouth assets..."
python3 /build/plymouth-theme/generate-assets.py

echo "==> Configuring live-build..."
LB_CONFIG_OPTS=(
  --distribution bookworm
  --architectures amd64
  --archive-areas "main contrib non-free non-free-firmware"
  --bootappend-live "boot=live components quiet splash noresume loglevel=3 udev.log_level=3"
  --bootappend-install ""
  --debian-installer none
  --iso-volume "PoleLinux"
  --iso-publisher "PoleLinux"
  --iso-application "PoleLinux Live"
  --linux-flavours "amd64"
  --memtest none
  --hdd-label "POLELINUX"
  --binary-images iso-hybrid
  --binary-compression xz
)

lb config "${LB_CONFIG_OPTS[@]}" 2>&1 | grep -v "^$" | sed 's/^/  /'

# --- Package lists ---
mkdir -p config/package-lists

cat > config/package-lists/polelinux-desktop.list.chroot << 'PKGS'
# PoleLinux desktop packages
task-gnome-desktop
gdm3
firefox-esr
celluloid
file-roller
gnome-tweaks
gnome-software
seahorse
baobab
network-manager
network-manager-gnome
pipewire
pipewire-pulse
wireplumber
gstreamer1.0-plugins-good
gstreamer1.0-plugins-bad
gstreamer1.0-plugins-ugly
gstreamer1.0-libav
sudo
nano
htop
git
neofetch
plymouth
plymouth-themes
PKGS

cat > config/package-lists/polelinux-firmware.list.chroot << 'FW'
amd64-microcode
intel-microcode
# Targeted firmware — avoids firmware-linux bloat (hundreds of unnecessary firmware files)
firmware-amd-graphics
firmware-misc-nonfree
firmware-realtek
firmware-iwlwifi
FW

# --- Plymouth theme ---
mkdir -p config/includes.chroot/usr/share/plymouth/themes/polelinux
cp /build/plymouth-theme/assets/*.png config/includes.chroot/usr/share/plymouth/themes/polelinux/
cp /build/plymouth-theme/polelinux.plymouth config/includes.chroot/usr/share/plymouth/themes/polelinux/
cp /build/plymouth-theme/polelinux.script config/includes.chroot/usr/share/plymouth/themes/polelinux/

# --- Wallpaper ---
mkdir -p config/includes.chroot/usr/share/backgrounds/polelinux
cp /build/images/wallpaper.png config/includes.chroot/usr/share/backgrounds/polelinux/

# --- GSettings default wallpaper (applies to all users) ---
mkdir -p config/includes.chroot/usr/share/glib-2.0/schemas/
cat > config/includes.chroot/usr/share/glib-2.0/schemas/99_polelinux.gschema.override << 'GOVERRIDE'
[org.gnome.desktop.background]
picture-uri = 'file:///usr/share/backgrounds/polelinux/wallpaper.png'
picture-uri-dark = 'file:///usr/share/backgrounds/polelinux/wallpaper.png'
picture-options = 'zoom'
[org.gnome.desktop.screensaver]
picture-uri = 'file:///usr/share/backgrounds/polelinux/wallpaper.png'
GOVERRIDE

# --- Neofetch config (PoleLinux logo + full system info) ---
mkdir -p config/includes.chroot/usr/share/polelinux
cp /build/plymouth-theme/logo-ascii.txt config/includes.chroot/usr/share/polelinux/
mkdir -p config/includes.chroot/etc/skel/.config/neofetch
cat > config/includes.chroot/etc/skel/.config/neofetch/config.conf << 'NEOFETCH'
ascii_file="/usr/share/polelinux/logo-ascii.txt"
ascii_colors=(4 6)
NEOFETCH

# --- GRUB theme ---
mkdir -p config/includes.chroot/boot/grub/themes/polelinux
cat > config/includes.chroot/boot/grub/themes/polelinux/theme.txt << 'GRUB_THEME'
# PoleLinux GRUB Theme
title-text: ""
title-color: "#64b5f6"
title-font: "DejaVu Sans Bold 18"
desktop-color: "#0a0a12"
desktop-image: ""
terminal-font: "DejaVu Sans Mono 12"
+ boot_menu {
    left = 25%
    top = 25%
    width = 50%
    height = 50%
    item_color = "#e8eaf0"
    item_height = 36
    item_padding = 8
    item_spacing = 4
    selected_item_color = "#0a0a12"
    selected_item_pixmap_style = "select_*.png"
    scrollbar = false
}
GRUB_THEME

# --- Live user auto-login ---
mkdir -p config/includes.chroot/etc/gdm3
cat > config/includes.chroot/etc/gdm3/daemon.conf << 'GDM'
[daemon]
AutomaticLoginEnable=true
AutomaticLogin=user
WaylandEnable=true

[greeter]
Welcome=PoleLinux
BannerMessageText=Welcome to PoleLinux
GDM

mkdir -p config/includes.chroot/var/lib/AccountsService/users
cat > config/includes.chroot/var/lib/AccountsService/users/user << 'ACCT'
[User]
Session=gnome
Icon=
SystemAccount=false
ACCT

# --- Hostname and OS release ---
mkdir -p config/includes.chroot/etc
echo "PoleLinux" > config/includes.chroot/etc/hostname

mkdir -p config/includes.chroot/usr/lib
cat > config/includes.chroot/usr/lib/os-release << 'OSR'
PRETTY_NAME="PoleLinux 1.0"
NAME="PoleLinux"
VERSION_ID="1.0"
VERSION="1.0 (PoleStar)"
VERSION_CODENAME=polelinux
ID=polelinux
ID_LIKE=debian
HOME_URL=""
SUPPORT_URL=""
BUG_REPORT_URL=""
OSR

cat > config/includes.chroot/etc/lsb-release << 'LSB'
DISTRIB_ID=PoleLinux
DISTRIB_RELEASE=1.0
DISTRIB_CODENAME=polelinux
DISTRIB_DESCRIPTION="PoleLinux 1.0"
LSB

# --- Locale ---
cat > config/includes.chroot/etc/locale.gen << 'LOCALE'
en_US.UTF-8 UTF-8
LOCALE

mkdir -p config/includes.chroot/etc/default
cat > config/includes.chroot/etc/default/locale << 'LOCDEF'
LANG=en_US.UTF-8
LOCDEF

# --- Plymouth default theme ---
mkdir -p config/includes.chroot/etc/plymouth
cat > config/includes.chroot/etc/plymouth/plymouthd.conf << 'PLYCONF'
[Daemon]
Theme=polelinux
ShowDelay=0
DeviceTimeout=5
PLYCONF

mkdir -p config/includes.chroot/usr/share/plymouth/themes/polelinux
cat > config/includes.chroot/usr/share/plymouth/themes/polelinux/polelinux.plymouth << 'PLYMOUTH'
[Plymouth Theme]
Name=polelinux
Description=PoleLinux Boot Splash
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/polelinux
ScriptFile=/usr/share/plymouth/themes/polelinux/polelinux.script
PLYMOUTH

# --- Customization hook (runs in chroot) ---
mkdir -p config/hooks/live
cat > config/hooks/live/polelinux-customize.hook.chroot << 'HOOK'
#!/bin/sh
set -e

# Generate locale
locale-gen

# Create live user
useradd -m -G sudo,audio,video -s /bin/bash user
echo "user:polelinux" | chpasswd
echo "%sudo ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel

# Set Plymouth theme
plymouth-set-default-theme polelinux || true

# Compile GSettings schemas (sets default wallpaper for all users)
glib-compile-schemas /usr/share/glib-2.0/schemas/ || true

# Optimize initramfs — only include needed modules (speeds boot significantly)
cat > /etc/initramfs-tools/initramfs.conf << 'INITRAMFS'
MODULES=dep
BUSYBOX=y
COMPRESS=zstd
INITRAMFS

# Enable services
systemctl enable gdm3 network-manager pipewire pipewire-pulse wireplumber || true

# Set default target to graphical
systemctl set-default graphical.target || true
HOOK
chmod +x config/hooks/live/polelinux-customize.hook.chroot

# --- Build ---
echo "==> Building ISO..."
mkdir -p "$OUT_DIR"
lb build 2>&1 | tee "$OUT_DIR/build.log"

# --- Copy artifact ---
ISO_SRC="live-image-amd64.hybrid.iso"
if [ -f "$ISO_SRC" ]; then
  cp "$ISO_SRC" "$OUT_DIR/polelinux-${DISTRO_VERSION}-amd64.iso"
  echo "==> ISO created: $OUT_DIR/polelinux-${DISTRO_VERSION}-amd64.iso"
  ls -lh "$OUT_DIR/"
else
  echo "==> ERROR: ISO not found!"
  ls -la
  exit 1
fi

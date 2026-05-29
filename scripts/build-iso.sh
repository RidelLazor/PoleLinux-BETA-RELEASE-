#!/usr/bin/env bash
set -euo pipefail

DISTRO_NAME="PoleLinux"
DISTRO_VERSION="1.0"
ARCH="x86_64"

BUILD_BASE="/build/build-env"
BUILD_DIR="$BUILD_BASE/work"
OUT_DIR="$BUILD_BASE/out"
PROFILE_DIR="$BUILD_BASE/profile"

rm -rf "$BUILD_BASE"
mkdir -p "$BUILD_DIR" "$OUT_DIR"

# --- Network pre-flight check ---
echo "==> Testing mirror connectivity..."
MIRRORS=("https://archlinux.mirror.liteserver.nl/core/os/x86_64/core.db" "https://mirror.rackspace.com/archlinux/core/os/x86_64/core.db" "https://mirrors.kernel.org/archlinux/core/os/x86_64/core.db")
OK=0
for m in "${MIRRORS[@]}"; do
  if curl -4 -s -o /dev/null -w "%{http_code}" --max-time 10 "$m" 2>/dev/null | grep -q 200; then
    echo "  OK: $m"
    OK=1
    break
  else
    echo "  FAIL: $m"
  fi
done
if [ "$OK" -eq 0 ]; then
  echo "==> ERROR: No Arch mirrors reachable. Check network."
  exit 1
fi

echo "==> Creating archiso profile..."
# Non-conflicting overlay directories (packages won't install these paths)
mkdir -p "$PROFILE_DIR/airootfs/etc/dconf/db/local.d/locks"
mkdir -p "$PROFILE_DIR/airootfs/etc/gdm"
mkdir -p "$PROFILE_DIR/airootfs/usr/share/plymouth/themes/polelinux"
mkdir -p "$PROFILE_DIR/airootfs/boot/grub/themes/polelinux"
mkdir -p "$PROFILE_DIR/airootfs/root"

# --- profiledef.sh ---
cat > "$PROFILE_DIR/profiledef.sh" << 'PROF'
#!/usr/bin/env bash
set -euo pipefail

iso_name="polelinux"
iso_label="POLELINUX_$(date +%Y%m)"
iso_publisher="PoleLinux"
iso_application="PoleLinux Live"
iso_version="1.0"
install_dir="arch"
buildmodes=('iso')
bootmodes=('bios.syslinux' 'uefi.grub')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M')

file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/etc/gshadow"]="0:0:400"
  ["/root"]="0:0:700"
  ["/root/.automated_script.sh"]="0:0:755"
)
PROF
chmod +x "$PROFILE_DIR/profiledef.sh"

# --- pacman.conf (enable multilib, disable timeouts, more mirrors via local file) ---
cat > "$PROFILE_DIR/pacman.conf" << 'PACMAN'
[options]
HoldPkg     = pacman glibc
Architecture = auto
SigLevel    = Required DatabaseOptional
LocalFileSigLevel = Optional
RemoteFileSigLevel = Optional
ParallelDownloads = 5
DisableDownloadTimeout

[core]
Include = /build/build-env/mirrorlist

[extra]
Include = /build/build-env/mirrorlist

[multilib]
Include = /build/build-env/mirrorlist
PACMAN

# Write a mirrorlist with multiple fast mirrors for the build
cat > "$BUILD_BASE/mirrorlist" << 'BUILD_MIRRORS'
## PoleLinux build mirrorlist
Server = https://archlinux.mirror.liteserver.nl/$repo/os/$arch
Server = https://mirror.rackspace.com/archlinux/$repo/os/$arch
Server = https://mirrors.kernel.org/archlinux/$repo/os/$arch
Server = https://mirror.xtom.com.hk/archlinux/$repo/os/$arch
Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch
BUILD_MIRRORS

mkdir -p "$PROFILE_DIR/airootfs/etc/pacman.d"
cat > "$PROFILE_DIR/airootfs/etc/pacman.d/mirrorlist" << 'MIRRORS'
## PoleLinux mirrorlist - prefer fast mirrors
Server = https://archlinux.mirror.liteserver.nl/$repo/os/$arch
Server = https://mirror.rackspace.com/archlinux/$repo/os/$arch
Server = https://mirrors.kernel.org/archlinux/$repo/os/$arch
Server = https://mirror.xtom.com.hk/archlinux/$repo/os/$arch
Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch
MIRRORS

# --- packages.x86_64 ---
cat > "$PROFILE_DIR/packages.x86_64" << 'PACKAGES'
base
linux
linux-firmware
amd-ucode
intel-ucode
grub
os-prober
ntfs-3g
efibootmgr
dosfstools
mtools
syslinux

# Desktop
gnome
gnome-tweaks
gnome-software
gdm

# Network
networkmanager
network-manager-applet

# Audio
pipewire
pipewire-alsa
pipewire-pulse
wireplumber

# Codecs / multimedia
gst-plugins-good
gst-plugins-bad
gst-plugins-ugly
gst-libav
celluloid

# Apps
firefox
file-roller
baobab
seahorse
loupe

# Plymouth boot splash
plymouth

# GNOME Shell extensions
gnome-shell-extensions
gnome-shell-extension-appindicator
gnome-shell-extension-caffeine
gnome-shell-extension-dash-to-panel

# Utils
sudo
nano
htop
PACKAGES

# --- Desktop wallpaper ---
echo "==> Copying wallpaper..."
mkdir -p "$PROFILE_DIR/airootfs/usr/share/backgrounds/polelinux"
cp /build/plymouth-theme/assets/wallpaper.png "$PROFILE_DIR/airootfs/usr/share/backgrounds/polelinux/"

# --- plymouth theme files (non-conflicting, unique to us) ---
echo "==> Copying Plymouth theme assets..."
cp -r /build/plymouth-theme/assets/*.png "$PROFILE_DIR/airootfs/usr/share/plymouth/themes/polelinux/"
cp /build/plymouth-theme/polelinux.plymouth "$PROFILE_DIR/airootfs/usr/share/plymouth/themes/polelinux/"

# --- GRUB theme (non-conflicting, unique to us) ---
cat > "$PROFILE_DIR/airootfs/boot/grub/themes/polelinux/theme.txt" << 'GRUB_THEME'
title-text: "PoleLinux"
title-color: "#DCDCF0"
desktop-color: "#14141E"
+ boot_menu {
    left = 25%
    top = 60%
    width = 50%
    height = 30%
    item_color = "#9090A0"
    selected_item_color = "#64B4FF"
    item_height = 28
    item_padding = 8
    item_spacing = 4
    icon_width = 24
    icon_height = 24
    item_icon_space = 8
}
+ progress_bar {
    top = 90%
    left = 25%
    width = 50%
    height = 12
    bar_color = "#64B4FF"
    bar_bg_color = "#323246"
}
GRUB_THEME

# --- GNOME dconf defaults (non-conflicting) ---
cat > "$PROFILE_DIR/airootfs/etc/dconf/db/local.d/00-polelinux" << 'DCONF'
[org/gnome/desktop/interface]
show-battery-percentage=true
clock-show-weekday=true
enable-hot-corners=false
font-name='Cantarell 11'
document-font-name='Cantarell 11'
monospace-font-name='Source Code Pro 11'

[org/gnome/desktop/session]
idle-delay=uint32 300

[org/gnome/desktop/peripherals/touchpad]
tap-to-click=true
natural-scroll=true

[org/gnome/desktop/background]
picture-uri='file:///usr/share/backgrounds/polelinux/wallpaper.png'
picture-uri-dark='file:///usr/share/backgrounds/polelinux/wallpaper.png'
picture-options='zoom'
primary-color='#14141E'
secondary-color='#14141E'
color-shading-type='solid'

[org/gnome/desktop/screensaver]
picture-uri='file:///usr/share/backgrounds/polelinux/wallpaper.png'
picture-options='zoom'
primary-color='#14141E'
secondary-color='#14141E'
color-shading-type='solid'

[org/gnome/settings-daemon/plugins/power]
sleep-inactive-ac-timeout=1800
power-button-action='interactive'
DCONF

cat > "$PROFILE_DIR/airootfs/etc/dconf/db/local.d/locks/00-polelinux" << 'LOCK'
/org/gnome/desktop/interface/show-battery-percentage
/org/gnome/desktop/interface/clock-show-weekday
LOCK

# --- GDM auto-login (custom.conf won't conflict with gdm package) ---
cat > "$PROFILE_DIR/airootfs/etc/gdm/custom.conf" << 'GDM'
[daemon]
AutomaticLoginEnable=true
AutomaticLogin=user
WaylandEnable=true

[greeter]
Welcome=PoleLinux
BannerMessageText=Welcome to PoleLinux

[security]

[xdmcp]

[chooser]

[debug]
GDM

# --- ISO bootloader configs (kernel cmdline with quiet splash for plymouth) ---
mkdir -p "$PROFILE_DIR/grub"
cat > "$PROFILE_DIR/grub/grub.cfg" << 'GRUB_CFG'
set default="0"
set timeout="5"

menuentry "PoleLinux" {
    linux /%INSTALL_DIR%/boot/vmlinuz-linux archisobasedir=%INSTALL_DIR% archisolabel=%ARCHISO_LABEL% quiet splash
    initrd /%INSTALL_DIR%/boot/initramfs-linux.img
}
GRUB_CFG

mkdir -p "$PROFILE_DIR/syslinux"
cat > "$PROFILE_DIR/syslinux/syslinux.cfg" << 'SYSLINUX'
DEFAULT archiso
LABEL archiso
    LINUX /%INSTALL_DIR%/boot/vmlinuz-linux
    INITRD /%INSTALL_DIR%/boot/initramfs-linux.img
    APPEND archisobasedir=%INSTALL_DIR% archisolabel=%ARCHISO_LABEL% quiet splash
SYSLINUX

# --- systemd-boot UEFI config ---
mkdir -p "$PROFILE_DIR/efiboot/loader/entries"
cat > "$PROFILE_DIR/efiboot/loader/loader.conf" << 'SYSD_LOADER'
default archiso
timeout 5
console-mode keep
SYSD_LOADER
cat > "$PROFILE_DIR/efiboot/loader/entries/archiso-x86_64.conf" << 'SYSD_ENTRY'
title PoleLinux
linux /%INSTALL_DIR%/boot/vmlinuz-linux
initrd /%INSTALL_DIR%/boot/initramfs-linux.img
options archisobasedir=%INSTALL_DIR% archisolabel=%ARCHISO_LABEL% quiet splash
SYSD_ENTRY

# --- customize_airootfs.sh (runs in chroot after packages installed) ---
cat > "$PROFILE_DIR/airootfs/root/customize_airootfs.sh" << 'CUSTOM'
#!/usr/bin/env bash
set -euo pipefail

echo "=== PoleLinux Customization ==="

# --- System identification (must be done AFTER package install, not in overlay) ---
echo "PoleLinux" > /etc/hostname
cat > /etc/hosts << HOSTS
127.0.0.1	localhost
127.0.1.1	PoleLinux

::1		localhost ip6-localhost ip6-loopback
ff02::1		ip6-allnodes
ff02::2		ip6-allrouters
HOSTS

cat > /usr/lib/os-release << 'OSR'
PRETTY_NAME="PoleLinux 1.0"
NAME="PoleLinux"
VERSION_ID="1.0"
VERSION="1.0 (PoleStar)"
VERSION_CODENAME=polelinux
ID=polelinux
ID_LIKE=arch
HOME_URL=""
SUPPORT_URL=""
BUG_REPORT_URL=""
LOGO=polelinux-logo
OSR
ln -sf /usr/lib/os-release /etc/os-release

cat > /etc/lsb-release << 'LSB'
DISTRIB_ID=PoleLinux
DISTRIB_RELEASE=1.0
DISTRIB_CODENAME=polelinux
DISTRIB_DESCRIPTION="PoleLinux 1.0"
LSB

echo "PoleLinux 1.0 \n \l" > /etc/issue

# --- Locale ---
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "KEYMAP=us" > /etc/vconsole.conf

# --- Plymouth dracut/mkinitcpio setup ---
cat > /etc/mkinitcpio.conf << MKINIT
HOOKS=(base udev plymouth autodetect modconf kms keyboard keymap consolefont block filesystems fsck)
COMPRESSION=(xz)
MKINIT

cat > /etc/plymouth/plymouthd.conf << PLYCONF
[Daemon]
Theme=polelinux
ShowDelay=0
DeviceTimeout=5
PLYCONF

# Register theme
THEME_FILE="/usr/share/plymouth/themes/polelinux/polelinux.plymouth"
if [ -f "$THEME_FILE" ]; then
    plymouth-set-default-theme polelinux 2>/dev/null || true
    echo "Plymouth theme configured"
fi

# --- GRUB defaults ---
cat > /etc/default/grub << GRUB
GRUB_DEFAULT=0
GRUB_TIMEOUT=5
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"
GRUB_CMDLINE_LINUX=""
GRUB_TERMINAL=console
GRUB_GFXMODE=1920x1080
GRUB_GFXPAYLOAD_LINUX=keep
GRUB_DISABLE_RECOVERY=true
GRUB_DISABLE_OS_PROBER=true
GRUB_THEME=/boot/grub/themes/polelinux/theme.txt
GRUB

# --- Create live user ---
useradd -m -G wheel,audio,video,storage,optical -s /bin/bash user
echo "user:polelinux" | chpasswd
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
passwd -d root 2>/dev/null || true

# --- Rebuild initramfs ---
mkinitcpio -P 2>/dev/null || true

# --- Dconf ---
dconf update

# --- Enable GNOME Shell extensions for live user ---
if command -v gnome-extensions &>/dev/null; then
    mkdir -p /run/user/1000
    chown user:user /run/user/1000
    su - user -c "dbus-run-session -- gnome-extensions enable appindicator@ubuntu.com" 2>/dev/null || true
    su - user -c "dbus-run-session -- gnome-extensions enable caffeine@patapon.info" 2>/dev/null || true
    su - user -c "dbus-run-session -- gnome-extensions enable dash-to-panel@jderose9.github.com" 2>/dev/null || true
    echo "GNOME extensions enabled"
fi

# --- Set GDM login screen background ---
if [ -f /usr/share/backgrounds/polelinux/wallpaper.png ]; then
    mkdir -p /run/user/120
    chown gdm:gdm /run/user/120 2>/dev/null || true
    su - gdm -s /bin/bash -c "dbus-run-session -- gsettings set org.gnome.desktop.background picture-uri 'file:///usr/share/backgrounds/polelinux/wallpaper.png'" 2>/dev/null || true
    su - gdm -s /bin/bash -c "dbus-run-session -- gsettings set org.gnome.desktop.background picture-uri-dark 'file:///usr/share/backgrounds/polelinux/wallpaper.png'" 2>/dev/null || true
    echo "GDM background set"
fi

# --- Enable services ---
systemctl enable gdm.service 2>/dev/null || true
systemctl enable NetworkManager.service 2>/dev/null || true
systemctl --global enable pipewire.service pipewire-pulse.service wireplumber.service 2>/dev/null || true

echo "=== PoleLinux Customization Complete ==="
CUSTOM
chmod +x "$PROFILE_DIR/airootfs/root/customize_airootfs.sh"

echo "==> Patching mkarchiso (removing set -e for debugging)..."
sed 's/^set -e -u$/set -u/' /usr/sbin/mkarchiso > /tmp/mkarchiso-patched
chmod +x /tmp/mkarchiso-patched

echo "==> Running mkarchiso (with retry on network errors)..."
for i in 1 2 3; do
    echo "--- Attempt $i ---"
    if /tmp/mkarchiso-patched -v -w "$BUILD_DIR" -o "$OUT_DIR" "$PROFILE_DIR" 2>&1; then
        echo "mkarchiso succeeded on attempt $i"
        break
    fi
    echo "mkarchiso failed on attempt $i, cleaning and retrying..."
    rm -rf "$BUILD_DIR"/*
    if [ $i -eq 3 ]; then
        echo "==> ERROR: mkarchiso failed after 3 attempts"
        exit 1
    fi
done

echo "==> Copying ISO to output..."
mkdir -p /build/images
cp "$OUT_DIR"/*.iso /build/images/ 2>/dev/null || true
ls -lh /build/images/
echo "==> Build complete!"
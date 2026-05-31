#!/bin/bash
# Test script to reproduce the _make_efibootimg failure in isolation
# Run this inside the Docker build container

set -ux

# Simulate the patched mkarchiso environment
efibootimg="/tmp/test_efiboot.img"
efiboot_files=()
quiet="n"

# Add some test files
mkdir -p /tmp/test_efi_files
dd if=/dev/urandom of=/tmp/test_efi_files/test1.bin bs=1M count=10 2>/dev/null
dd if=/dev/urandom of=/tmp/test_efi_files/test2.bin bs=1M count=10 2>/dev/null
efiboot_files=(/tmp/test_efi_files/*)

echo "=== Test 1: Local imgsize_kib with (( )) check ==="
_make_efibootimg() {
    local -i imgsize_kib=0
    local mkfs_fat_opts=(-C -n ARCHISO_EFI)
    
    imgsize_kib="$(du -bcs -- "${efiboot_files[@]}" 2>/dev/null \
        | awk 'function ceil(x){return int(x)+(x>int(x))}
              function byte_to_kib(x){return x/1024}
              function mib_to_kib(x){return x*1024}
              END {print mib_to_kib(ceil((byte_to_kib($1)+8192)/1024))}'
    )"
    
    echo "imgsize_kib = $imgsize_kib"
    echo "Checking >= 36864..."
    if (( imgsize_kib >= 36864 )); then
        echo "Greater or equal!"
        mkfs_fat_opts+=(-F 32)
    fi
    
    echo "rm -f -- \"${efibootimg}\""
    rm -f -- "${efibootimg}"
    echo "About to run mkfs.fat..."
    mkfs.fat "${mkfs_fat_opts[@]}" "${efibootimg}" "${imgsize_kib}" >/dev/null 2>&1 || echo "mkfs.fat failed (expected)"
    echo "Done!"
}

_make_efibootimg

echo "=== Test 2: With 'local mkfs_fat_opts=(-C -n ARCHISO_EFI)' style (two operations) ==="
_make_efibootimg2() {
    local -i imgsize_kib=0
    local mkfs_fat_opts
    mkfs_fat_opts=(-C -n ARCHISO_EFI)
    
    imgsize_kib="$(du -bcs -- "${efiboot_files[@]}" 2>/dev/null \
        | awk 'function ceil(x){return int(x)+(x>int(x))}
              function byte_to_kib(x){return x/1024}
              function mib_to_kib(x){return x*1024}
              END {print mib_to_kib(ceil((byte_to_kib($1)+8192)/1024))}'
    )"
    
    echo "imgsize_kib = $imgsize_kib"
    if (( imgsize_kib >= 36864 )); then
        echo "OK: >= 36864"
        mkfs_fat_opts+=(-F 32)
    fi
    
    rm -f -- "${efibootimg}"
    mkfs.fat "${mkfs_fat_opts[@]}" "${efibootimg}" "${imgsize_kib}" >/dev/null 2>&1 || echo "mkfs.fat failed (expected)"
    echo "Done!"
}

_make_efibootimg2

echo "=== ALL TESTS PASSED ==="

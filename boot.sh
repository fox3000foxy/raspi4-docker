
#!/bin/bash
set -e

cd /data

IMAGE="2023-12-11-raspios-bookworm-arm64-lite.img"
ARCHIVE="${IMAGE}.xz"
URL="https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2023-12-11/${ARCHIVE}"

# Télécharger l'image si elle est absente
if [ ! -f "$IMAGE" ]; then
    echo "Téléchargement de Raspberry Pi OS Lite..."
    wget -c -O "$ARCHIVE" "$URL"
    xz -dkf "$ARCHIVE"
fi

# Agrandir l'image à 4 Gio
echo "Vérification de la taille du disque..."
qemu-img resize -f raw "$IMAGE" 4G

# Vérifier et agrandir la partition racine
echo "Vérification de la partition racine..."

PARTITION_INFO=$(parted -m "$IMAGE" unit s print)

DISK_SECTORS=$(echo "$PARTITION_INFO" | awk -F: 'NR==2 {gsub(/s/, "", $2); print $2}')
ROOT_START=$(echo "$PARTITION_INFO" | awk -F: '$1=="2" {gsub(/s/, "", $2); print $2}')
ROOT_END=$(echo "$PARTITION_INFO" | awk -F: '$1=="2" {gsub(/s/, "", $3); print $3}')

if [ -z "$DISK_SECTORS" ] || [ -z "$ROOT_START" ] || [ -z "$ROOT_END" ]; then
    echo "Erreur : impossible de détecter la partition racine."
    exit 1
fi

DISK_LAST_SECTOR=$((DISK_SECTORS - 1))

if [ "$ROOT_END" -lt "$((DISK_LAST_SECTOR - 10))" ]; then
    echo "Extension de la partition racine..."
    parted -s "$IMAGE" resizepart 2 100%

    PARTITION_INFO=$(parted -m "$IMAGE" unit s print)
    ROOT_END=$(echo "$PARTITION_INFO" | awk -F: '$1=="2" {gsub(/s/, "", $3); print $3}')

    ROOT_SIZE=$(((ROOT_END - ROOT_START + 1) * 512))
    ROOT_OFFSET=$((ROOT_START * 512))

    ROOT_LOOP=$(losetup --find --show \
        --offset "$ROOT_OFFSET" \
        --sizelimit "$ROOT_SIZE" \
        "$IMAGE")

    cleanup_root() {
        if [ -n "${ROOT_LOOP:-}" ]; then
            losetup -d "$ROOT_LOOP" 2>/dev/null || true
        fi
    }
    trap cleanup_root EXIT

    echo "Vérification du système de fichiers..."
    set +e
    e2fsck -f -y "$ROOT_LOOP"
    FSCK_STATUS=$?
    set -e

    if [ "$FSCK_STATUS" -gt 1 ]; then
        echo "Erreur lors de la vérification ext4 (code $FSCK_STATUS)."
        exit 1
    fi

    echo "Extension du système de fichiers ext4..."
    resize2fs "$ROOT_LOOP"

    losetup -d "$ROOT_LOOP"
    ROOT_LOOP=""
    trap - EXIT
else
    echo "La partition racine utilise déjà tout l'espace disponible."
fi

# Préparer la partition Boot
echo "Montage de la partition Boot..."
mkdir -p /mnt/rpi-boot

LOOP=$(losetup --find --show --offset 4194304 "$IMAGE")

cleanup() {
    umount /mnt/rpi-boot 2>/dev/null || true
    losetup -d "$LOOP" 2>/dev/null || true
}

trap cleanup EXIT

mount "$LOOP" /mnt/rpi-boot

# Extraire les fichiers de démarrage
echo "Préparation des fichiers QEMU..."

cp /mnt/rpi-boot/kernel8.img ./kernel8.img
cp /mnt/rpi-boot/bcm2710-rpi-3-b.dtb ./bcm2710-rpi-3-b.dtb
cp /mnt/rpi-boot/initramfs8 ./initramfs8

# Créer le compte pi si nécessaire
if [ ! -f /data/.userconf-injected ]; then
    echo "Configuration du compte pi..."
    HASH=$(openssl passwd -6 "$RPI_PASSWORD")
    echo "pi:$HASH" > /mnt/rpi-boot/userconf.txt
    touch /data/.userconf-injected
fi

# Activer SSH
touch /mnt/rpi-boot/ssh

sync
cleanup
trap - EXIT

echo "Démarrage du Raspberry Pi 3..."

exec qemu-system-aarch64 \
    -accel tcg,thread=multi \
    -M raspi3b \
    -cpu cortex-a53 \
    -kernel kernel8.img \
    -initrd initramfs8 \
    -dtb bcm2710-rpi-3-b.dtb \
    -append "earlycon=pl011,mmio32,0x3f201000 console=ttyAMA1,115200 root=PARTUUID=4e639091-02 rootfstype=ext4 fsck.repair=yes rootwait rw" \
    -drive "file=$IMAGE,if=sd,format=raw" \
    -device usb-net,netdev=net0 \
    -netdev user,id=net0,hostfwd=tcp::2222-:22 \
    -display none \
    -serial stdio \
    -monitor none


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
    #HASH=$(openssl passwd -6 "${RPI_PASSWORD:-raspberry}")
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

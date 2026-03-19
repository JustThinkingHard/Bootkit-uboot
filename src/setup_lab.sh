#!/bin/bash

# Stop the script at the slightest error
set -e
keys="../keys"
output="../output"

clean() {
    echo -e "\n[+] Cleaning up old work environment..."
    rm -rf $output
    rm -rf $keys
}

setup() {

    echo -e "\n[+] 1. Cleaning up old work environment..."
    rm -f $output/Image $output/rootfs.ext4 $output/u-boot.bin $output/sdcard.img $output/template.dtb $output/fitImage $output/sign.its
    rm -rf $keys

    mkdir -p $output
    echo -e "\n[+] 2. Retrieving artifacts from Buildroot and U-Boot..."

    if [ ! -f ../buildroot/output/images/Image ] || [ ! -f ../buildroot/output/images/rootfs.ext4 ]; then
        echo -e "\n\e[33m[!] WARNING: Buildroot artifacts are missing. Running Buildroot build, please wait...\e[0m"
        (cd ../buildroot && make -j$(nproc))
    fi

    if [ ! -f ../u-boot/u-boot.bin ]; then
        echo -e "\n\e[33m[!] WARNING: U-Boot artifact is missing. Running U-Boot build, please wait...\e[0m"
        cp lab_defconfig ../u-boot/configs/
        (cd ../u-boot && export CROSS_COMPILE=aarch64-linux-gnu- && make lab_defconfig && make -j$(nproc))
    fi

    cp ../buildroot/output/images/Image $output
    cp ../buildroot/output/images/rootfs.ext4 $output
    cp ../u-boot/u-boot.bin $output

    echo -e "\n[+] 3. Generating cryptographic keys (RSA 4096)..."
    mkdir -p $keys
    openssl genrsa -F4 -out $keys/dev_key.key 4096 2>/dev/null
    openssl req -batch -new -x509 -key $keys/dev_key.key -out $keys/dev_key.crt 2>/dev/null

    echo -e "\n[+] 4. Creating FIT Image configuration (Kernel-Only)..."
    cat << 'EOF' > $output/sign.its
/dts-v1/;

/ {
    description = "Linux Kernel Signed";
    #address-cells = <1>;

    images {
        kernel-1 {
            description = "Linux Kernel";
            data = /incbin/("Image");
            type = "kernel";
            arch = "arm64";
            os = "linux";
            compression = "none";
            load = <0x40200000>;
            entry = <0x40200000>;
            hash-1 {
                algo = "sha256";
            };
        };
    };

    configurations {
        default = "conf-1";
        conf-1 {
            description = "Boot Linux kernel";
            kernel = "kernel-1";
            signature-1 {
                algo = "sha256,rsa4096";
                key-name-hint = "dev_key";
                sign-images = "kernel";
            };
        };
    };
};
EOF

    echo -e "\n[+] 5. Brutal formatting of virtual SD card (Superfloppy)..."
    dd if=/dev/zero of=$output/sdcard.img bs=1G count=1 status=none
    mkfs.vfat -I $output/sdcard.img

    echo -e "\n[+] 6. Generating Device Tree Blob (DTB) via QEMU..."
    qemu-system-aarch64 -machine virt -cpu cortex-a57 -nographic \
        -m 1024 \
        -bios $output/u-boot.bin \
        -drive file=$output/sdcard.img,format=raw,if=virtio \
        -drive file=$output/rootfs.ext4,format=raw,if=virtio \
        -machine dumpdtb=$output/template.dtb

    echo -e "\n[+] 7. Sealing the FIT Image and injecting public key into DTB..."
    ../u-boot/tools/mkimage -f $output/sign.its -k $keys -K $output/template.dtb -r $output/fitImage > /dev/null

    echo -e "\n[+] 8. Copying signed FIT Image to SD card..."
    mcopy -i $output/sdcard.img $output/fitImage ::fitImage

    echo -e "\e[32m=========================================================="
    echo -e "      LAB READY AND SECURED (SECURE BOOT)!        "
    echo -e "==========================================================\n\e[0m"
}

run-vm() {
    echo -e "\n[+] Starting QEMU with secure SD card..."
    qemu-system-aarch64 -machine virt -cpu cortex-a57 -nographic \
    -m 1024 \
    -bios $output/u-boot.bin \
    -dtb $output/template.dtb \
    -drive file=$output/sdcard.img,format=raw,if=virtio \
    -drive file=$output/rootfs.ext4,format=raw,if=virtio
}

run-attack() {
    echo -e "\n[+] Starting QEMU with GDB server for attack simulation..."
    qemu-system-aarch64 -machine virt -cpu cortex-a57 -nographic \
    -m 1024 \
    -bios $output/u-boot.bin \
    -dtb $output/template.dtb \
    -drive file=$output/sdcard.img,format=raw,if=virtio \
    -drive file=$output/rootfs.ext4,format=raw,if=virtio \
    -s -S
}


if [ "$1" = "setup" ]; then
    setup
elif [ "$1" = "run" ]; then
    run-vm
elif [ "$1" = "attack" ]; then
    run-attack
elif [ "$1" = "clean" ]; then
    clean
fi
